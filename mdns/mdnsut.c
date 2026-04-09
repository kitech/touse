
#include <sys/socket.h>
#ifdef _WIN32
#define _CRT_SECURE_NO_WARNINGS 1
#endif

#include <stdio.h>

#include <errno.h>
#include <signal.h>

#ifdef _WIN32
#include <winsock2.h>
#include <iphlpapi.h>
#define sleep(x) Sleep(x * 1000)
#else
#include <netdb.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <sys/time.h>
#include <arpa/inet.h>
#endif

// Alias some things to simulate recieving data to fuzz library
#if defined(MDNS_FUZZING)
#define recvfrom(sock, buffer, capacity, flags, src_addr, addrlen) ((mdns_ssize_t)capacity)
#define printf
#endif

#include "mdns.h"

#define NI_MAXHOST 256
#define NI_MAXSERV 256

// Data for our service including the mDNS records
typedef struct {
	mdns_string_t service;
	mdns_string_t hostname;
	mdns_string_t service_instance;
	mdns_string_t hostname_qualified;
	struct sockaddr_in address_ipv4;
	struct sockaddr_in6 address_ipv6;
	int port;
	mdns_record_t record_ptr;
	mdns_record_t record_srv;
	mdns_record_t record_a;
	mdns_record_t record_aaaa;
	mdns_record_t txt_record[2];
} service_t;

static mdns_string_t
ipv4_address_to_string(char* buffer, size_t capacity, const struct sockaddr_in* addr,
                       size_t addrlen) {
	char host[NI_MAXHOST] = {0};
	char service[NI_MAXSERV] = {0};
	int ret = getnameinfo((const struct sockaddr*)addr, (socklen_t)addrlen, host, NI_MAXHOST,
	                      service, NI_MAXSERV, NI_NUMERICSERV | NI_NUMERICHOST);
	int len = 0;
	if (ret == 0) {
		if (addr->sin_port != 0)
			len = snprintf(buffer, capacity, "%s:%s", host, service);
		else
			len = snprintf(buffer, capacity, "%s", host);
	}
	if (len >= (int)capacity)
		len = (int)capacity - 1;
	mdns_string_t str;
	str.str = buffer;
	str.length = len;
	return str;
}

static mdns_string_t
ipv6_address_to_string(char* buffer, size_t capacity, const struct sockaddr_in6* addr,
                       size_t addrlen) {
	char host[NI_MAXHOST] = {0};
	char service[NI_MAXSERV] = {0};
	int ret = getnameinfo((const struct sockaddr*)addr, (socklen_t)addrlen, host, NI_MAXHOST,
	                      service, NI_MAXSERV, NI_NUMERICSERV | NI_NUMERICHOST);
	int len = 0;
	if (ret == 0) {
		if (addr->sin6_port != 0)
			len = snprintf(buffer, capacity, "[%s]:%s", host, service);
		else
			len = snprintf(buffer, capacity, "%s", host);
	}
	if (len >= (int)capacity)
		len = (int)capacity - 1;
	mdns_string_t str;
	str.str = buffer;
	str.length = len;
	return str;
}

static mdns_string_t
ip_address_to_string(char* buffer, size_t capacity, const struct sockaddr* addr, size_t addrlen) {
	if (addr->sa_family == AF_INET6)
		return ipv6_address_to_string(buffer, capacity, (const struct sockaddr_in6*)addr, addrlen);
	return ipv4_address_to_string(buffer, capacity, (const struct sockaddr_in*)addr, addrlen);
}

char**
getipaddrs(int* count, int max_count) {
#if defined(_WIN32)

	IP_ADAPTER_ADDRESSES* adapter_address = 0;
	ULONG address_size = 8000;
	unsigned int ret;
	unsigned int num_retries = 4;
	do {
		adapter_address = (IP_ADAPTER_ADDRESSES*)malloc(address_size);
		ret = GetAdaptersAddresses(AF_UNSPEC, GAA_FLAG_SKIP_MULTICAST | GAA_FLAG_SKIP_ANYCAST, 0,
		                           adapter_address, &address_size);
		if (ret == ERROR_BUFFER_OVERFLOW) {
			free(adapter_address);
			adapter_address = 0;
			address_size *= 2;
		} else {
			break;
		}
	} while (num_retries-- > 0);

	if (!adapter_address || (ret != NO_ERROR)) {
		free(adapter_address);
		*count = 0;
		return 0;
	}

	int capacity = 32;
	char** ips = (char**)malloc(capacity * sizeof(char*));
	int num = 0;

	for (PIP_ADAPTER_ADDRESSES adapter = adapter_address; adapter; adapter = adapter->Next) {
		if (adapter->TunnelType == TUNNEL_TYPE_TEREDO)
			continue;
		if (adapter->OperStatus != IfOperStatusUp)
			continue;

		for (IP_ADAPTER_UNICAST_ADDRESS* unicast = adapter->FirstUnicastAddress; unicast;
		     unicast = unicast->Next) {
			if (unicast->Address.lpSockaddr->sa_family == AF_INET) {
				struct sockaddr_in* saddr = (struct sockaddr_in*)unicast->Address.lpSockaddr;
				if ((saddr->sin_addr.S_un.S_un_b.s_b1 == 127) &&
				    (saddr->sin_addr.S_un.S_un_b.s_b2 == 0) &&
				    (saddr->sin_addr.S_un.S_un_b.s_b3 == 0) &&
				    (saddr->sin_addr.S_un.S_un_b.s_b4 == 1))
					continue;

				char ipstr[INET_ADDRSTRLEN];
				if (inet_ntop(AF_INET, &saddr->sin_addr, ipstr, INET_ADDRSTRLEN) == 0)
					continue;

				if (num >= capacity) {
					capacity *= 2;
					ips = (char**)realloc(ips, capacity * sizeof(char*));
				}
				ips[num++] = strdup(ipstr);

			} else if (unicast->Address.lpSockaddr->sa_family == AF_INET6) {
				struct sockaddr_in6* saddr = (struct sockaddr_in6*)unicast->Address.lpSockaddr;
				if (saddr->sin6_scope_id)
					continue;

				static const unsigned char localhost[] = {0, 0, 0, 0, 0, 0, 0, 0,
				                                          0, 0, 0, 0, 0, 0, 0, 1};
				static const unsigned char localhost_mapped[] = {0, 0, 0,    0,    0,    0, 0, 0,
				                                                 0, 0, 0xff, 0xff, 0x7f, 0, 0, 1};
				if (memcmp(saddr->sin6_addr.s6_addr, localhost, 16) == 0)
					continue;
				if (memcmp(saddr->sin6_addr.s6_addr, localhost_mapped, 16) == 0)
					continue;
				if (unicast->DadState != NldsPreferred)
					continue;

				char ipstr[INET6_ADDRSTRLEN];
				if (inet_ntop(AF_INET6, &saddr->sin6_addr, ipstr, INET6_ADDRSTRLEN) == 0)
					continue;

				if (num >= capacity) {
					capacity *= 2;
					ips = (char**)realloc(ips, capacity * sizeof(char*));
				}
				ips[num++] = strdup(ipstr);
			}

			if ((max_count > 0) && (num >= max_count))
				break;
		}

		if ((max_count > 0) && (num >= max_count))
			break;
	}

	free(adapter_address);

	*count = num;
	return ips;

#elif defined(__APPLE__) || defined(__linux__)

	struct ifaddrs* ifaddr = 0;
	struct ifaddrs* ifa = 0;

	if (getifaddrs(&ifaddr) < 0) {
		*count = 0;
		return 0;
	}

	int capacity = 32;
	char** ips = (char**)malloc(capacity * sizeof(char*));
	int num = 0;

	for (ifa = ifaddr; ifa; ifa = ifa->ifa_next) {
		if (!ifa->ifa_addr)
			continue;
		if (!(ifa->ifa_flags & IFF_UP) || !(ifa->ifa_flags & IFF_MULTICAST))
			continue;
		if ((ifa->ifa_flags & IFF_LOOPBACK) || (ifa->ifa_flags & IFF_POINTOPOINT))
			continue;

		if (ifa->ifa_addr->sa_family == AF_INET) {
			struct sockaddr_in* saddr = (struct sockaddr_in*)ifa->ifa_addr;
			if (saddr->sin_addr.s_addr == htonl(INADDR_LOOPBACK))
				continue;

			char ipstr[INET_ADDRSTRLEN];
			if (inet_ntop(AF_INET, &saddr->sin_addr, ipstr, INET_ADDRSTRLEN) == 0)
				continue;

			if (num >= capacity) {
				capacity *= 2;
				ips = (char**)realloc(ips, capacity * sizeof(char*));
			}
			ips[num++] = strdup(ipstr);

		} else if (ifa->ifa_addr->sa_family == AF_INET6) {
			struct sockaddr_in6* saddr = (struct sockaddr_in6*)ifa->ifa_addr;
			if (saddr->sin6_scope_id)
				continue;

			static const unsigned char localhost[] = {0, 0, 0, 0, 0, 0, 0, 0,
			                                          0, 0, 0, 0, 0, 0, 0, 1};
			static const unsigned char localhost_mapped[] = {0, 0, 0,    0,    0,    0, 0, 0,
			                                                 0, 0, 0xff, 0xff, 0x7f, 0, 0, 1};
			if (memcmp(saddr->sin6_addr.s6_addr, localhost, 16) == 0)
				continue;
			if (memcmp(saddr->sin6_addr.s6_addr, localhost_mapped, 16) == 0)
				continue;

			char ipstr[INET6_ADDRSTRLEN];
			if (inet_ntop(AF_INET6, &saddr->sin6_addr, ipstr, INET6_ADDRSTRLEN) == 0)
				continue;

			if (num >= capacity) {
				capacity *= 2;
				ips = (char**)realloc(ips, capacity * sizeof(char*));
			}
			ips[num++] = strdup(ipstr);
		}

		if ((max_count > 0) && (num >= max_count))
			break;
	}

	freeifaddrs(ifaddr);

	*count = num;
	return ips;

#else
	*count = 0;
	return 0;
#endif
}

void
freeipaddrs(char** ips, int count) {
	if (!ips)
		return;
	for (int i = 0; i < count; i++) {
		if (ips[i])
			free(ips[i]);
	}
	free(ips);
}

struct sockaddr_in
ipv4_string_to_address(const char* ip4str) {
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    inet_pton(AF_INET, ip4str, &addr.sin_addr);
    return addr;
}
