/**
 * netut_ip_addresses.c - 跨平台获取系统IP地址列表
 * 支持Linux, macOS, Windows
 * C99标准
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#ifdef _WIN32
    #define WIN32_LEAN_AND_MEAN
    #include <windows.h>
    #include <winsock2.h>
    #include <ws2tcpip.h>
    #include <iphlpapi.h>
    #pragma comment(lib, "ws2_32.lib")
    #pragma comment(lib, "iphlpapi.lib")
#else
    #include <unistd.h>
    #include <sys/types.h>
    #include <sys/socket.h>
    #include <sys/ioctl.h>
    #include <netinet/in.h>
    #include <arpa/inet.h>
    #include <netdb.h>
    #include <ifaddrs.h>
    #include <net/if.h>
#endif

// IP地址信息结构体
typedef struct netut_ip_address {
    char interface_name[64];      // 网络接口名称
    char ip_address[INET6_ADDRSTRLEN];  // IP地址字符串
    int family;                   // 地址族: AF_INET 或 AF_INET6
    int prefix_length;            // 子网前缀长度
    int is_up;                    // 接口是否启用
    int is_loopback;              // 是否是回环地址
    struct netut_ip_address *next; // 下一个节点
} netut_ip_address_t;

// IP地址列表结构体
typedef struct {
    netut_ip_address_t *head;     // 链表头
    netut_ip_address_t *tail;     // 链表尾
    int count;                    // IP地址数量
    int error_code;               // 错误代码
    char error_msg[256];          // 错误信息
} netut_ip_list_t;

// 全局初始化标记
#ifdef _WIN32
static int netut_winsock_initialized = 0;
#endif

/**
 * @brief 初始化网络库（Windows需要）
 * @return 成功返回0，失败返回-1
 */
static int netut_network_init(void) {
#ifdef _WIN32
    if (!netut_winsock_initialized) {
        WSADATA wsaData;
        if (WSAStartup(MAKEWORD(2, 2), &wsaData) != 0) {
            return -1;
        }
        netut_winsock_initialized = 1;
    }
#endif
    return 0;
}

/**
 * @brief 清理网络库（Windows需要）
 */
static void netut_network_cleanup(void) {
#ifdef _WIN32
    if (netut_winsock_initialized) {
        WSACleanup();
        netut_winsock_initialized = 0;
    }
#endif
}

/**
 * @brief 创建新的IP地址列表
 * @return 新的IP地址列表指针
 */
netut_ip_list_t* netut_create_ip_list(void) {
    netut_ip_list_t *list = (netut_ip_list_t*)calloc(1, sizeof(netut_ip_list_t));
    if (list == NULL) {
        return NULL;
    }
    list->head = NULL;
    list->tail = NULL;
    list->count = 0;
    list->error_code = 0;
    list->error_msg[0] = '\0';
    return list;
}

/**
 * @brief 添加IP地址到列表
 * @param list IP地址列表
 * @param iface_name 接口名称
 * @param ip_addr IP地址字符串
 * @param family 地址族
 * @param prefix_len 子网前缀长度
 * @param is_up 接口是否启用
 * @param is_loopback 是否是回环地址
 * @return 成功返回0，失败返回-1
 */
static int netut_add_ip_address(netut_ip_list_t *list,
                               const char *iface_name,
                               const char *ip_addr,
                               int family,
                               int prefix_len,
                               int is_up,
                               int is_loopback) {
    if (list == NULL || ip_addr == NULL) {
        return -1;
    }
    
    // 创建新的IP地址节点
    netut_ip_address_t *new_addr = (netut_ip_address_t*)calloc(1, sizeof(netut_ip_address_t));
    if (new_addr == NULL) {
        return -1;
    }
    
    // 复制接口名称
    if (iface_name != NULL) {
        strncpy(new_addr->interface_name, iface_name, sizeof(new_addr->interface_name) - 1);
        new_addr->interface_name[sizeof(new_addr->interface_name) - 1] = '\0';
    } else {
        new_addr->interface_name[0] = '\0';
    }
    
    // 复制IP地址
    strncpy(new_addr->ip_address, ip_addr, sizeof(new_addr->ip_address) - 1);
    new_addr->ip_address[sizeof(new_addr->ip_address) - 1] = '\0';
    
    new_addr->family = family;
    new_addr->prefix_length = prefix_len;
    new_addr->is_up = is_up;
    new_addr->is_loopback = is_loopback;
    new_addr->next = NULL;
    
    // 添加到链表
    if (list->head == NULL) {
        list->head = new_addr;
        list->tail = new_addr;
    } else {
        list->tail->next = new_addr;
        list->tail = new_addr;
    }
    
    list->count++;
    return 0;
}

/**
 * @brief 释放IP地址列表内存
 * @param list IP地址列表指针
 */
void netut_free_ip_list(netut_ip_list_t *list) {
    if (list == NULL) {
        return;
    }
    
    netut_ip_address_t *current = list->head;
    netut_ip_address_t *next;
    
    while (current != NULL) {
        next = current->next;
        free(current);
        current = next;
    }
    
    free(list);
    
    // 清理网络库
    netut_network_cleanup();
}

/**
 * @brief 获取系统所有IP地址
 * @param include_ipv6 是否包含IPv6地址
 * @param include_loopback 是否包含回环地址
 * @param include_down 是否包含未启用的接口
 * @return IP地址列表指针，失败返回NULL
 */
netut_ip_list_t* netut_get_ip_addresses(int include_ipv6, int include_loopback, int include_down) {
    netut_ip_list_t *list = netut_create_ip_list();
    if (list == NULL) {
        return NULL;
    }
    
    // 初始化网络库
    if (netut_network_init() != 0) {
        list->error_code = 1;
        strcpy(list->error_msg, "网络库初始化失败");
        return list;
    }
    
#ifdef _WIN32
    // Windows 实现
    PIP_ADAPTER_ADDRESSES pAddresses = NULL;
    PIP_ADAPTER_ADDRESSES pCurrAddresses = NULL;
    PIP_ADAPTER_UNICAST_ADDRESS pUnicast = NULL;
    ULONG outBufLen = 0;
    DWORD dwRetVal = 0;
    char ipAddrStr[INET6_ADDRSTRLEN];
    
    // 获取所需的缓冲区大小
    dwRetVal = GetAdaptersAddresses(AF_UNSPEC, 
                                   GAA_FLAG_INCLUDE_PREFIX, 
                                   NULL, 
                                   pAddresses, 
                                   &outBufLen);
    
    if (dwRetVal == ERROR_BUFFER_OVERFLOW) {
        pAddresses = (IP_ADAPTER_ADDRESSES*)malloc(outBufLen);
        if (pAddresses == NULL) {
            list->error_code = 2;
            strcpy(list->error_msg, "内存分配失败");
            return list;
        }
        
        // 获取适配器地址
        dwRetVal = GetAdaptersAddresses(AF_UNSPEC, 
                                       GAA_FLAG_INCLUDE_PREFIX, 
                                       NULL, 
                                       pAddresses, 
                                       &outBufLen);
    }
    
    if (dwRetVal != NO_ERROR) {
        list->error_code = 3;
        sprintf(list->error_msg, "GetAdaptersAddresses失败: %lu", dwRetVal);
        free(pAddresses);
        return list;
    }
    
    // 遍历适配器
    for (pCurrAddresses = pAddresses; pCurrAddresses != NULL; 
         pCurrAddresses = pCurrAddresses->Next) {
        
        // 检查接口状态
        int is_up = (pCurrAddresses->OperStatus == IfOperStatusUp);
        
        // 检查是否是回环接口
        int is_loopback = (pCurrAddresses->IfType == IF_TYPE_SOFTWARE_LOOPBACK);
        
        // 跳过未启用的接口
        if (!include_down && !is_up) {
            continue;
        }
        
        // 跳过回环接口
        if (!include_loopback && is_loopback) {
            continue;
        }
        
        // 遍历单播地址
        for (pUnicast = pCurrAddresses->FirstUnicastAddress; pUnicast != NULL;
             pUnicast = pUnicast->Next) {
            
            // 获取地址族
            int family = pUnicast->Address.lpSockaddr->sa_family;
            
            // 检查是否包含IPv6
            if (!include_ipv6 && family == AF_INET6) {
                continue;
            }
            
            // 转换IP地址为字符串
            DWORD ipAddrStrLen = sizeof(ipAddrStr);
            if (family == AF_INET) {
                struct sockaddr_in *sa_in = (struct sockaddr_in*)pUnicast->Address.lpSockaddr;
                InetNtopA(AF_INET, &(sa_in->sin_addr), ipAddrStr, ipAddrStrLen);
            } else if (family == AF_INET6) {
                struct sockaddr_in6 *sa_in6 = (struct sockaddr_in6*)pUnicast->Address.lpSockaddr;
                InetNtopA(AF_INET6, &(sa_in6->sin6_addr), ipAddrStr, ipAddrStrLen);
            } else {
                continue; // 跳过非IP地址
            }
            
            // 获取前缀长度
            int prefix_len = 0;
            if (pUnicast->OnLinkPrefixLength != 0) {
                prefix_len = pUnicast->OnLinkPrefixLength;
            }
            
            // 添加到列表
            netut_add_ip_address(list, 
                               pCurrAddresses->AdapterName,
                               ipAddrStr,
                               family,
                               prefix_len,
                               is_up,
                               is_loopback);
        }
    }
    
    free(pAddresses);
    
#else
    // Linux/macOS 实现
    struct ifaddrs *ifaddr, *ifa;
    char host[NI_MAXHOST];
    
    if (getifaddrs(&ifaddr) == -1) {
        list->error_code = 4;
        strcpy(list->error_msg, "getifaddrs失败");
        return list;
    }
    
    // 遍历接口列表
    for (ifa = ifaddr; ifa != NULL; ifa = ifa->ifa_next) {
        if (ifa->ifa_addr == NULL) {
            continue;
        }
        
        int family = ifa->ifa_addr->sa_family;
        
        // 只处理IPv4和IPv6地址
        if (family != AF_INET && family != AF_INET6) {
            continue;
        }
        
        // 检查是否包含IPv6
        if (!include_ipv6 && family == AF_INET6) {
            continue;
        }
        
        // 检查接口状态
        int is_up = (ifa->ifa_flags & IFF_UP) != 0;
        int is_loopback = (ifa->ifa_flags & IFF_LOOPBACK) != 0;
        
        // 跳过未启用的接口
        if (!include_down && !is_up) {
            continue;
        }
        
        // 跳过回环接口
        if (!include_loopback && is_loopback) {
            continue;
        }
        
        // 获取IP地址字符串
        int s = getnameinfo(ifa->ifa_addr,
                           (family == AF_INET) ? sizeof(struct sockaddr_in) :
                                                sizeof(struct sockaddr_in6),
                           host, NI_MAXHOST, NULL, 0, NI_NUMERICHOST);
        
        if (s != 0) {
            continue; // 转换失败，跳过
        }
        
        // 获取前缀长度
        int prefix_len = 0;
        if (ifa->ifa_netmask != NULL) {
            // 计算前缀长度
            if (family == AF_INET) {
                struct sockaddr_in *mask = (struct sockaddr_in*)ifa->ifa_netmask;
                unsigned long m = ntohl(mask->sin_addr.s_addr);
                while (m > 0) {
                    if (m & 0x80000000) prefix_len++;
                    m <<= 1;
                }
            } else if (family == AF_INET6) {
                struct sockaddr_in6 *mask = (struct sockaddr_in6*)ifa->ifa_netmask;
                for (int i = 0; i < 16; i++) {
                    unsigned char b = mask->sin6_addr.s6_addr[i];
                    for (int j = 7; j >= 0; j--) {
                        if (b & (1 << j)) {
                            prefix_len++;
                        }
                    }
                }
            }
        }
        
        // 添加到列表
        netut_add_ip_address(list,
                           ifa->ifa_name,
                           host,
                           family,
                           prefix_len,
                           is_up,
                           is_loopback);
    }
    
    freeifaddrs(ifaddr);
#endif
    
    return list;
}

/**
 * @brief 获取系统所有IPv4地址
 * @return IP地址列表指针
 */
netut_ip_list_t* netut_get_ipv4_addresses(void) {
    return netut_get_ip_addresses(0, 0, 0);
}

/**
 * @brief 获取系统所有IPv6地址
 * @return IP地址列表指针
 */
netut_ip_list_t* netut_get_ipv6_addresses(void) {
    return netut_get_ip_addresses(1, 0, 0);
}

/**
 * @brief 获取系统所有启用的IP地址（包含IPv4和IPv6）
 * @return IP地址列表指针
 */
netut_ip_list_t* netut_get_all_ip_addresses(void) {
    return netut_get_ip_addresses(1, 0, 0);
}

/**
 * @brief 打印IP地址列表
 * @param list IP地址列表
 */
void netut_print_ip_list(const netut_ip_list_t *list) {
    if (list == NULL) {
        printf("IP地址列表为空\n");
        return;
    }
    
    if (list->error_code != 0) {
        printf("错误 [%d]: %s\n", list->error_code, list->error_msg);
        return;
    }
    
    printf("系统IP地址列表 (%d 个):\n", list->count);
    printf("========================================\n");
    
    netut_ip_address_t *current = list->head;
    int index = 1;
    
    while (current != NULL) {
        printf("%d. 接口: %s\n", index, current->interface_name);
        printf("   IP地址: %s\n", current->ip_address);
        printf("   地址族: %s\n", (current->family == AF_INET) ? "IPv4" : "IPv6");
        printf("   子网掩码: /%d\n", current->prefix_length);
        printf("   状态: %s\n", current->is_up ? "启用" : "禁用");
        printf("   类型: %s\n", current->is_loopback ? "回环" : "普通");
        printf("----------------------------------------\n");
        
        current = current->next;
        index++;
    }
}

/**
 * @brief 格式化IP地址列表为JSON字符串
 * @param list IP地址列表
 * @param buffer 输出缓冲区
 * @param buffer_size 缓冲区大小
 * @return 成功返回0，失败返回-1
 */
int netut_format_ip_list_json(const netut_ip_list_t *list, 
                             char *buffer, size_t buffer_size) {
    if (list == NULL || buffer == NULL) {
        return -1;
    }
    
    if (list->error_code != 0) {
        snprintf(buffer, buffer_size,
                "{\"error\":true,\"code\":%d,\"message\":\"%s\"}",
                list->error_code, list->error_msg);
        return -1;
    }
    
    char *ptr = buffer;
    int remaining = buffer_size;
    int written = 0;
    
    // 开始JSON数组
    written = snprintf(ptr, remaining, "{\"count\":%d,\"addresses\":[", list->count);
    if (written < 0 || written >= remaining) {
        return -1;
    }
    ptr += written;
    remaining -= written;
    
    // 遍历IP地址列表
    netut_ip_address_t *current = list->head;
    int first = 1;
    
    while (current != NULL && remaining > 0) {
        if (!first) {
            written = snprintf(ptr, remaining, ",");
            if (written < 0 || written >= remaining) {
                return -1;
            }
            ptr += written;
            remaining -= written;
        }
        first = 0;
        
        written = snprintf(ptr, remaining,
                          "{\"interface\":\"%s\","
                          "\"address\":\"%s\","
                          "\"family\":\"%s\","
                          "\"prefix_length\":%d,"
                          "\"status\":\"%s\","
                          "\"type\":\"%s\"}",
                          current->interface_name,
                          current->ip_address,
                          (current->family == AF_INET) ? "IPv4" : "IPv6",
                          current->prefix_length,
                          current->is_up ? "up" : "down",
                          current->is_loopback ? "loopback" : "regular");
        
        if (written < 0 || written >= remaining) {
            return -1;
        }
        ptr += written;
        remaining -= written;
        
        current = current->next;
    }
    
    // 结束JSON数组
    if (remaining > 2) {
        written = snprintf(ptr, remaining, "],\"error\":false}");
        if (written < 0 || written >= remaining) {
            return -1;
        }
    }
    
    return 0;
}

/**
 * @brief 查找指定接口的IP地址
 * @param list IP地址列表
 * @param interface_name 接口名称
 * @return 找到的IP地址节点，未找到返回NULL
 */
netut_ip_address_t* netut_find_ip_by_interface(const netut_ip_list_t *list,
                                              const char *interface_name) {
    if (list == NULL || interface_name == NULL) {
        return NULL;
    }
    
    netut_ip_address_t *current = list->head;
    while (current != NULL) {
        if (strcmp(current->interface_name, interface_name) == 0) {
            return current;
        }
        current = current->next;
    }
    
    return NULL;
}

// 测试示例
#ifdef NETUT_TEST
int main() {
    printf("=== 测试 netut__ IP地址获取函数 ===\n\n");
    
    // 获取所有IP地址
    printf("1. 获取所有IP地址:\n");
    netut_ip_list_t *all_ips = netut_get_all_ip_addresses();
    netut_print_ip_list(all_ips);
    
    // 格式化为JSON
    char json_buffer[4096];
    if (netut_format_ip_list_json(all_ips, json_buffer, sizeof(json_buffer)) == 0) {
        printf("\nJSON格式输出:\n%s\n", json_buffer);
    }
    
    // 获取IPv4地址
    printf("\n2. 获取IPv4地址:\n");
    netut_ip_list_t *ipv4_ips = netut_get_ipv4_addresses();
    netut_print_ip_list(ipv4_ips);
    
    // 查找特定接口
    printf("\n3. 查找 eth0 接口的IP地址:\n");
    netut_ip_address_t *eth0_ip = netut_find_ip_by_interface(all_ips, "eth0");
    if (eth0_ip != NULL) {
        printf("找到 eth0: %s\n", eth0_ip->ip_address);
    } else {
        printf("未找到 eth0 接口\n");
    }
    
    // 查找 lo 接口
    printf("\n4. 查找 lo 接口的IP地址:\n");
    netut_ip_address_t *lo_ip = netut_find_ip_by_interface(all_ips, "lo");
    if (lo_ip != NULL) {
        printf("找到 lo: %s\n", lo_ip->ip_address);
    } else {
        printf("未找到 lo 接口\n");
    }
    
    // 清理内存
    netut_free_ip_list(all_ips);
    netut_free_ip_list(ipv4_ips);
    
    printf("\n=== 测试完成 ===\n");
    return 0;
}
#endif
