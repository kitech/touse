/**
 * netut_ip_monitor_event.c - 跨平台基于事件的IP地址变化监控
 * 支持Linux (netlink), macOS (SCDynamicStore), Windows (NotifyIpInterfaceChange)
 * C99标准
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <time.h>

#ifdef _WIN32
    #define WIN32_LEAN_AND_MEAN
    #include <windows.h>
    #include <winsock2.h>
    #include <ws2tcpip.h>
    #include <iphlpapi.h>
    #pragma comment(lib, "ws2_32.lib")
    #pragma comment(lib, "iphlpapi.lib")
#elif defined(__APPLE__)
    #include <SystemConfiguration/SystemConfiguration.h>
    #include <CoreFoundation/CoreFoundation.h>
    #include <arpa/inet.h>
#elif defined(__linux__)
    #include <unistd.h>
    #include <sys/types.h>
    #include <sys/socket.h>
    #include <sys/ioctl.h>
    #include <sys/select.h>
    #include <fcntl.h>
    #include <netinet/in.h>
    #include <arpa/inet.h>
    #include <linux/netlink.h>
    #include <linux/rtnetlink.h>
    #include <errno.h>
    #include <signal.h>
    #include <net/if.h>
#endif

// 回调函数类型定义
typedef void (*netut_ip_change_callback)(const char *interface_name,
                                         const char *ip_address,
                                         int family,
                                         int event_type,
                                         void *user_data);

// IP变化事件类型
typedef enum {
    NETUT_IP_ADDED = 1,
    NETUT_IP_REMOVED = 2,
    NETUT_IP_CHANGED = 3
} netut_ip_event_t;

// 监控器结构体
typedef struct {
    int running;                    // 是否正在运行
    netut_ip_change_callback callback;  // 变化回调函数
    void *user_data;                // 用户数据
    int error_code;                 // 错误代码
    char error_msg[256];            // 错误信息
    
#ifdef _WIN32
    HANDLE notification_handle;     // Windows通知句柄
    HANDLE wait_event;              // 等待事件
#elif defined(__APPLE__)
    SCDynamicStoreRef store_ref;    // macOS系统配置存储
    CFRunLoopSourceRef runloop_source; // 运行循环源
#elif defined(__linux__)
    int netlink_fd;                 // Netlink套接字
#endif
} netut_ip_monitor_t;

// 全局初始化标记
#ifdef _WIN32
static int netut_winsock_initialized = 0;
#endif

/**
 * @brief 初始化网络库（Windows需要）
 * @return 成功返回0，失败返回-1
 */
static int netut__network_init(void) {
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
 * @brief 清理网络库
 */
static void netut__network_cleanup(void) {
#ifdef _WIN32
    if (netut_winsock_initialized) {
        WSACleanup();
        netut_winsock_initialized = 0;
    }
#endif
}

#ifdef _WIN32
/**
 * @brief Windows IP接口变化回调
 */
VOID CALLBACK netut__win_notify_callback(PVOID caller_context,
                                         PMIB_IPINTERFACE_ROW row OPTIONAL,
                                         MIB_NOTIFICATION_TYPE notification_type) {
    netut_ip_monitor_t *monitor = (netut_ip_monitor_t*)caller_context;
    if (!monitor || !monitor->callback || !row) return;
    
    // 获取适配器信息以获取接口名称
    PIP_ADAPTER_ADDRESSES addresses = NULL;
    ULONG size = 0;
    ULONG result = GetAdaptersAddresses(AF_UNSPEC, 0, NULL, addresses, &size);
    
    if (result == ERROR_BUFFER_OVERFLOW) {
        addresses = (IP_ADAPTER_ADDRESSES*)malloc(size);
        if (addresses) {
            result = GetAdaptersAddresses(AF_UNSPEC, 0, NULL, addresses, &size);
            if (result == NO_ERROR) {
                PIP_ADAPTER_ADDRESSES addr = addresses;
                while (addr) {
                    if (addr->IfIndex == row->InterfaceIndex) {
                        PIP_ADAPTER_UNICAST_ADDRESS unicast = addr->FirstUnicastAddress;
                        while (unicast) {
                            char ipStr[INET6_ADDRSTRLEN];
                            int family = unicast->Address.lpSockaddr->sa_family;
                            
                            if (family == AF_INET || family == AF_INET6) {
                                // 转换IP地址
                                if (family == AF_INET) {
                                    struct sockaddr_in *sa_in = (struct sockaddr_in*)unicast->Address.lpSockaddr;
                                    inet_ntop(AF_INET, &(sa_in->sin_addr), ipStr, sizeof(ipStr));
                                } else {
                                    struct sockaddr_in6 *sa_in6 = (struct sockaddr_in6*)unicast->Address.lpSockaddr;
                                    inet_ntop(AF_INET6, &(sa_in6->sin6_addr), ipStr, sizeof(ipStr));
                                }
                                
                                // 根据通知类型确定事件类型
                                netut_ip_event_t event_type = NETUT_IP_CHANGED;
                                if (notification_type == MibAddInstance) {
                                    event_type = NETUT_IP_ADDED;
                                } else if (notification_type == MibDeleteInstance) {
                                    event_type = NETUT_IP_REMOVED;
                                }
                                
                                monitor->callback(addr->AdapterName, ipStr, family, event_type, monitor->user_data);
                            }
                            unicast = unicast->Next;
                        }
                        break;
                    }
                    addr = addr->Next;
                }
            }
            free(addresses);
        }
    }
}
#endif

#ifdef __APPLE__
/**
 * @brief macOS网络配置变化回调
 */
static void netut__mac_callback(SCDynamicStoreRef store, CFArrayRef changed_keys, void *info) {
    netut_ip_monitor_t *monitor = (netut_ip_monitor_t*)info;
    if (!monitor || !monitor->callback || !changed_keys) return;
    
    CFIndex count = CFArrayGetCount(changed_keys);
    
    for (CFIndex i = 0; i < count; i++) {
        CFStringRef key = (CFStringRef)CFArrayGetValueAtIndex(changed_keys, i);
        
        // 检查是否是State:/Network/Interface/ 开头的键
        if (CFStringHasPrefix(key, CFSTR("State:/Network/Interface/"))) {
            // 获取接口名称（从键名中提取）
            CFRange range = CFRangeMake(25, CFStringGetLength(key) - 25);
            char iface_name[64];
            CFStringGetCString(key, iface_name, sizeof(iface_name), kCFStringEncodingUTF8);
            
            // 获取接口的IP地址信息
            CFStringRef ipv4_key = CFStringCreateWithFormat(NULL, NULL, 
                CFSTR("State:/Network/Interface/%.64s/IPv4"), iface_name);
            CFStringRef ipv6_key = CFStringCreateWithFormat(NULL, NULL,
                CFSTR("State:/Network/Interface/%.64s/IPv6"), iface_name);
            
            // 检查IPv4地址
            CFDictionaryRef ipv4_info = SCDynamicStoreCopyValue(store, ipv4_key);
            // if (!ipv4_info) { ipv4_info = SCDynamicStoreCopyValue(store, ipv4_key_2); }
            if (ipv4_info) {
                CFArrayRef addresses = CFDictionaryGetValue(ipv4_info, CFSTR("Addresses"));
                if (addresses) {
                    CFIndex addr_count = CFArrayGetCount(addresses);
                    for (CFIndex j = 0; j < addr_count; j++) {
                        CFStringRef addr_str = CFArrayGetValueAtIndex(addresses, j);
                        char ip_str[INET_ADDRSTRLEN];
                        CFStringGetCString(addr_str, ip_str, sizeof(ip_str), kCFStringEncodingUTF8);
                        
                        // 通知IPv4地址变化
                        monitor->callback(iface_name, ip_str, AF_INET, NETUT_IP_CHANGED, monitor->user_data);
                    }
                }
                CFRelease(ipv4_info);
            }
            
            // 检查IPv6地址
            CFDictionaryRef ipv6_info = SCDynamicStoreCopyValue(store, ipv6_key);
            // if (!ipv6_info) { ipv6_info = SCDynamicStoreCopyValue(store, ipv6_key_2); }
            if (ipv6_info) {
                CFArrayRef addresses = CFDictionaryGetValue(ipv6_info, CFSTR("Addresses"));
                if (addresses) {
                    CFIndex addr_count = CFArrayGetCount(addresses);
                    for (CFIndex j = 0; j < addr_count; j++) {
                        CFStringRef addr_str = CFArrayGetValueAtIndex(addresses, j);
                        char ip_str[INET6_ADDRSTRLEN];
                        CFStringGetCString(addr_str, ip_str, sizeof(ip_str), kCFStringEncodingUTF8);
                        
                        // 通知IPv6地址变化
                        monitor->callback(iface_name, ip_str, AF_INET6, NETUT_IP_CHANGED, monitor->user_data);
                    }
                }
                CFRelease(ipv6_info);
            }
            
            CFRelease(ipv4_key);
            CFRelease(ipv6_key);
        } else if (CFStringHasPrefix(key, CFSTR("State:/Network/Global"))) {
            // CFStringRef ipv4_key_2 = CFStringCreateWithFormat(NULL, NULL, 
            //     CFSTR("State:/Network/Global/IPv4"));
            // CFStringRef ipv6_key_2 = CFStringCreateWithFormat(NULL, NULL,
            //     CFSTR("State:/Network/Global/IPv6")); 
            // 通知IPv4地址变化
            monitor->callback("iface_TODO", "IP_TODO", AF_INET, NETUT_IP_CHANGED, monitor->user_data);
        }
    }
}
#endif

#ifdef __linux__
/**
 * @brief 解析Linux netlink消息
 */
static int netut__parse_netlink_message(int sock_fd, netut_ip_monitor_t *monitor) {
    char buffer[4096];
    struct iovec iov = { buffer, sizeof(buffer) };
    struct sockaddr_nl sa;
    struct msghdr msg;
    
    memset(&sa, 0, sizeof(sa));
    sa.nl_family = AF_NETLINK;
    
    memset(&msg, 0, sizeof(msg));
    msg.msg_name = &sa;
    msg.msg_namelen = sizeof(sa);
    msg.msg_iov = &iov;
    msg.msg_iovlen = 1;
    
    ssize_t len = recvmsg(sock_fd, &msg, 0);
    if (len < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            return 1; // 没有数据
        }
        return -1;
    }
    
    struct nlmsghdr *nlh = (struct nlmsghdr*)buffer;
    
    for (; NLMSG_OK(nlh, len); nlh = NLMSG_NEXT(nlh, len)) {
        if (nlh->nlmsg_type == RTM_NEWADDR) {
            // 新地址添加
            struct ifaddrmsg *ifa = (struct ifaddrmsg*)NLMSG_DATA(nlh);
            struct rtattr *rth = IFA_RTA(ifa);
            int rtl = IFA_PAYLOAD(nlh);
            
            char iface_name[IF_NAMESIZE];
            if (if_indextoname(ifa->ifa_index, iface_name) == NULL) {
                continue;
            }
            
            while (rtl && RTA_OK(rth, rtl)) {
                if (rth->rta_type == IFA_LOCAL || rth->rta_type == IFA_ADDRESS) {
                    char ip_str[INET6_ADDRSTRLEN];
                    void *addr_data = RTA_DATA(rth);
                    
                    if (ifa->ifa_family == AF_INET) {
                        inet_ntop(AF_INET, addr_data, ip_str, sizeof(ip_str));
                        monitor->callback(iface_name, ip_str, AF_INET, NETUT_IP_ADDED, monitor->user_data);
                    } else if (ifa->ifa_family == AF_INET6) {
                        inet_ntop(AF_INET6, addr_data, ip_str, sizeof(ip_str));
                        monitor->callback(iface_name, ip_str, AF_INET6, NETUT_IP_ADDED, monitor->user_data);
                    }
                }
                rth = RTA_NEXT(rth, rtl);
            }
        } else if (nlh->nlmsg_type == RTM_DELADDR) {
            // 地址删除
            struct ifaddrmsg *ifa = (struct ifaddrmsg*)NLMSG_DATA(nlh);
            struct rtattr *rth = IFA_RTA(ifa);
            int rtl = IFA_PAYLOAD(nlh);
            
            char iface_name[IF_NAMESIZE];
            if (if_indextoname(ifa->ifa_index, iface_name) == NULL) {
                continue;
            }
            
            while (rtl && RTA_OK(rth, rtl)) {
                if (rth->rta_type == IFA_LOCAL || rth->rta_type == IFA_ADDRESS) {
                    char ip_str[INET6_ADDRSTRLEN];
                    void *addr_data = RTA_DATA(rth);
                    
                    if (ifa->ifa_family == AF_INET) {
                        inet_ntop(AF_INET, addr_data, ip_str, sizeof(ip_str));
                        monitor->callback(iface_name, ip_str, AF_INET, NETUT_IP_REMOVED, monitor->user_data);
                    } else if (ifa->ifa_family == AF_INET6) {
                        inet_ntop(AF_INET6, addr_data, ip_str, sizeof(ip_str));
                        monitor->callback(iface_name, ip_str, AF_INET6, NETUT_IP_REMOVED, monitor->user_data);
                    }
                }
                rth = RTA_NEXT(rth, rtl);
            }
        } else if (nlh->nlmsg_type == NLMSG_ERROR) {
            // Netlink错误
            return -1;
        }
    }
    
    return 0;
}
#endif

/**
 * @brief 创建IP地址监控器（基于事件）
 * @param callback IP变化回调函数
 * @param user_data 用户数据
 * @return 监控器指针，失败返回NULL
 */
netut_ip_monitor_t* netut_create_ip_monitor_event(netut_ip_change_callback callback,
                                                  void *user_data) {
    if (callback == NULL) {
        return NULL;
    }
    
    netut_ip_monitor_t *monitor = (netut_ip_monitor_t*)calloc(1, sizeof(netut_ip_monitor_t));
    if (monitor == NULL) {
        return NULL;
    }
    
    monitor->running = 0;
    monitor->callback = callback;
    monitor->user_data = user_data;
    monitor->error_code = 0;
    monitor->error_msg[0] = '\0';
    
#ifdef _WIN32
    monitor->notification_handle = NULL;
    monitor->wait_event = NULL;
#elif defined(__APPLE__)
    monitor->store_ref = NULL;
    monitor->runloop_source = NULL;
#elif defined(__linux__)
    monitor->netlink_fd = -1;
#endif
    
    return monitor;
}

/**
 * @brief 启动IP地址监控（事件驱动）
 * @param monitor 监控器指针
 * @return 成功返回0，失败返回-1
 */
int netut_start_ip_monitor_event(netut_ip_monitor_t *monitor) {
    if (monitor == NULL || monitor->running) {
        return -1;
    }
    
    // 初始化网络库
    if (netut__network_init() != 0) {
        monitor->error_code = 1;
        strcpy(monitor->error_msg, "网络初始化失败");
        return -1;
    }
    
#ifdef _WIN32
    // Windows事件驱动实现
    monitor->wait_event = CreateEvent(NULL, FALSE, FALSE, NULL);
    if (!monitor->wait_event) {
        monitor->error_code = GetLastError();
        strcpy(monitor->error_msg, "创建事件失败");
        return -1;
    }
    
    // 注册IP接口变化通知
    DWORD result = NotifyIpInterfaceChange(AF_UNSPEC,
                                          (PIPINTERFACE_CHANGE_CALLBACK)netut__win_notify_callback,
                                          monitor,
                                          FALSE,  // 初始通知
                                          &monitor->notification_handle);
    
    if (result != NO_ERROR) {
        CloseHandle(monitor->wait_event);
        monitor->wait_event = NULL;
        monitor->error_code = result;
        sprintf(monitor->error_msg, "注册通知失败: %lu", result);
        return -1;
    }
    
    monitor->running = 1;
    
#elif defined(__APPLE__)
    // macOS事件驱动实现
    SCDynamicStoreContext context = {0, monitor, NULL, NULL, NULL};
    
    monitor->store_ref = SCDynamicStoreCreate(NULL,
                                             CFSTR("netut_ip_monitor"),
                                             netut__mac_callback,
                                             &context);
    if (!monitor->store_ref) {
        monitor->error_code = 2;
        strcpy(monitor->error_msg, "创建动态存储失败");
        return -1;
    }
    
    // 设置监控的键
    CFStringRef keys[] = {
        CFSTR("State:/Network/Interface/.*/IPv4"),
        CFSTR("State:/Network/Interface/.*/IPv6"),
        CFSTR("State:/Network/Global/IPv4"),
        CFSTR("State:/Network/Global/IPv6")
    };
    CFArrayRef watch_keys = CFArrayCreate(NULL, (const void**)keys, 4, &kCFTypeArrayCallBacks);
    
    if (!SCDynamicStoreSetNotificationKeys(monitor->store_ref, watch_keys, NULL)) {
        CFRelease(monitor->store_ref);
        monitor->store_ref = NULL;
        CFRelease(watch_keys);
        monitor->error_code = 3;
        strcpy(monitor->error_msg, "设置通知键失败");
        return -1;
    }
    
    // 创建运行循环源
    monitor->runloop_source = SCDynamicStoreCreateRunLoopSource(NULL, monitor->store_ref, 0);
    if (!monitor->runloop_source) {
        CFRelease(monitor->store_ref);
        monitor->store_ref = NULL;
        CFRelease(watch_keys);
        monitor->error_code = 4;
        strcpy(monitor->error_msg, "创建运行循环源失败");
        return -1;
    }
    
    // 添加到当前运行循环
    CFRunLoopAddSource(CFRunLoopGetCurrent(), monitor->runloop_source, kCFRunLoopDefaultMode);
    CFRelease(watch_keys);
    
    monitor->running = 1;
    
#elif defined(__linux__)
    // Linux netlink实现
    monitor->netlink_fd = socket(AF_NETLINK, SOCK_RAW, NETLINK_ROUTE);
    if (monitor->netlink_fd < 0) {
        monitor->error_code = errno;
        sprintf(monitor->error_msg, "创建netlink套接字失败: %s", strerror(errno));
        return -1;
    }
    
    struct sockaddr_nl addr;
    memset(&addr, 0, sizeof(addr));
    addr.nl_family = AF_NETLINK;
    addr.nl_groups = RTMGRP_IPV4_IFADDR | RTMGRP_IPV6_IFADDR;
    addr.nl_pid = getpid();
    
    if (bind(monitor->netlink_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(monitor->netlink_fd);
        monitor->netlink_fd = -1;
        monitor->error_code = errno;
        sprintf(monitor->error_msg, "绑定netlink套接字失败: %s", strerror(errno));
        return -1;
    }
    
    // 设置非阻塞
    int flags = fcntl(monitor->netlink_fd, F_GETFL, 0);
    fcntl(monitor->netlink_fd, F_SETFL, flags | O_NONBLOCK);
    
    monitor->running = 1;
    
#else
    // 不支持的平台
    monitor->error_code = 99;
    strcpy(monitor->error_msg, "平台不支持事件驱动IP监控");
    return -1;
#endif
    
    return 0;
}

/**
 * @brief 停止IP地址监控
 * @param monitor 监控器指针
 * @return 成功返回0，失败返回-1
 */
int netut_stop_ip_monitor_event(netut_ip_monitor_t *monitor) {
    if (monitor == NULL || !monitor->running) {
        return -1;
    }
    
    monitor->running = 0;
    
#ifdef _WIN32
    if (monitor->notification_handle) {
        CancelMibChangeNotify2(monitor->notification_handle);
        monitor->notification_handle = NULL;
    }
    if (monitor->wait_event) {
        CloseHandle(monitor->wait_event);
        monitor->wait_event = NULL;
    }
    
#elif defined(__APPLE__)
    if (monitor->runloop_source) {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), monitor->runloop_source, kCFRunLoopDefaultMode);
        CFRelease(monitor->runloop_source);
        monitor->runloop_source = NULL;
    }
    if (monitor->store_ref) {
        CFRelease(monitor->store_ref);
        monitor->store_ref = NULL;
    }
    
#elif defined(__linux__)
    if (monitor->netlink_fd >= 0) {
        close(monitor->netlink_fd);
        monitor->netlink_fd = -1;
    }
#endif
    
    netut__network_cleanup();
    return 0;
}

/**
 * @brief 处理事件（需要定期调用）
 * @param monitor 监控器指针
 * @param timeout_ms 超时时间（毫秒），0表示不阻塞，-1表示无限等待
 * @return 成功返回0，失败返回-1，超时返回1
 */
int netut_process_ip_events(netut_ip_monitor_t *monitor, int timeout_ms) {
    if (monitor == NULL || !monitor->running) {
        return -1;
    }
    
#ifdef _WIN32
    // Windows: 使用WaitForSingleObject等待事件
    DWORD wait_time = (timeout_ms < 0) ? INFINITE : timeout_ms;
    DWORD result = WaitForSingleObject(monitor->wait_event, wait_time);
    
    if (result == WAIT_OBJECT_0) {
        // 事件已触发，重置事件以便下次等待
        ResetEvent(monitor->wait_event);
        return 0;
    } else if (result == WAIT_TIMEOUT) {
        return 1; // 超时
    } else {
        monitor->error_code = GetLastError();
        sprintf(monitor->error_msg, "等待事件失败: %lu", GetLastError());
        return -1;
    }
    
#elif defined(__APPLE__)
    // macOS: 使用CFRunLoopRunInMode处理事件
    double timeout_seconds = (timeout_ms < 0) ? -1.0 : (timeout_ms / 1000.0);
    SInt32 run_result;
    
    if (timeout_ms == 0) {
        // 非阻塞模式
        run_result = CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, true);
    } else {
        run_result = CFRunLoopRunInMode(kCFRunLoopDefaultMode, timeout_seconds, false);
    }
    
    if (run_result == kCFRunLoopRunTimedOut) {
        return 1; // 超时
    } else if (run_result == kCFRunLoopRunStopped || run_result == kCFRunLoopRunFinished) {
        return -1; // 运行循环停止
    }
    return 0;
    
#elif defined(__linux__)
    // Linux: 使用select检查netlink套接字
    fd_set read_fds;
    FD_ZERO(&read_fds);
    FD_SET(monitor->netlink_fd, &read_fds);
    
    struct timeval tv, *tv_ptr = NULL;
    if (timeout_ms >= 0) {
        tv.tv_sec = timeout_ms / 1000;
        tv.tv_usec = (timeout_ms % 1000) * 1000;
        tv_ptr = &tv;
    }
    
    int result = select(monitor->netlink_fd + 1, &read_fds, NULL, NULL, tv_ptr);
    
    if (result > 0 && FD_ISSET(monitor->netlink_fd, &read_fds)) {
        // 有数据可读，解析netlink消息
        int parse_result = netut__parse_netlink_message(monitor->netlink_fd, monitor);
        if (parse_result == 0) {
            return 0; // 成功处理消息
        } else if (parse_result == 1) {
            return 1; // 没有数据（非阻塞模式）
        } else {
            return -1; // 解析错误
        }
    } else if (result == 0) {
        return 1; // 超时
    } else if (result < 0) {
        if (errno == EINTR) {   // in case infinite loop, sleep little
            // printf("select EINTR %d %d %s:%d\n", errno, monitor->netlink_fd, __FILE__, __LINE__);
            // sleep(1);
            usleep(686000);
            return 2; // 被信号中断，视为超时
        }
        monitor->error_code = errno;
        sprintf(monitor->error_msg, "select失败: %s", strerror(errno));
        return -1;
    }
    return 0;
    
#else
    monitor->error_code = 100;
    strcpy(monitor->error_msg, "平台不支持");
    return -1;
#endif
}

/**
 * @brief 阻塞处理IP事件直到停止
 * @param monitor 监控器指针
 * @return 成功返回0，失败返回-1
 */
int netut_process_ip_events_blocking(netut_ip_monitor_t *monitor) {
    if (monitor == NULL || !monitor->running) {
        return -1;
    }
    
#ifdef _WIN32
    // Windows: 无限等待
    while (monitor->running) {
        DWORD result = WaitForSingleObject(monitor->wait_event, INFINITE);
        if (result == WAIT_OBJECT_0) {
            ResetEvent(monitor->wait_event);
        } else if (!monitor->running) {
            break;
        }
    }
    return 0;
    
#elif defined(__APPLE__)
    // macOS: 运行运行循环
    CFRunLoopRun();
    return 0;
    
#elif defined(__linux__)
    // Linux: 循环处理事件
    while (monitor->running) {
        int result = netut_process_ip_events(monitor, 1000); // 1秒超时
        if (result < 0) {
            if (errno != EINTR) {
                break;
            }
        }
    }
    return 0;
    
#else
    return -1;
#endif
}

/**
 * @brief 释放IP地址监控器
 * @param monitor 监控器指针
 */
void netut_free_ip_monitor_event(netut_ip_monitor_t *monitor) {
    if (monitor == NULL) {
        return;
    }
    
    // 如果正在运行，先停止
    if (monitor->running) {
        netut_stop_ip_monitor_event(monitor);
    }
    
    free(monitor);
}

/**
 * @brief 获取监控器错误信息
 * @param monitor 监控器指针
 * @return 错误信息字符串
 */
const char* netut_get_monitor_event_error(const netut_ip_monitor_t *monitor) {
    if (monitor == NULL) {
        return "监控器为空";
    }
    return monitor->error_msg;
}

/**
 * @brief 获取监控器错误代码
 * @param monitor 监控器指针
 * @return 错误代码
 */
int netut_get_monitor_event_error_code(const netut_ip_monitor_t *monitor) {
    if (monitor == NULL) {
        return -1;
    }
    return monitor->error_code;
}

/**
 * @brief 检查监控器是否正在运行
 * @param monitor 监控器指针
 * @return 正在运行返回1，否则返回0
 */
int netut_is_monitor_event_running(const netut_ip_monitor_t *monitor) {
    if (monitor == NULL) {
        return 0;
    }
    return monitor->running;
}

// 示例回调函数
static void netut__example_callback(const char *interface_name,
                                   const char *ip_address,
                                   int family,
                                   int event_type,
                                   void *user_data) {
    const char *event_str = NULL;
    const char *family_str = (family == AF_INET) ? "IPv4" : "IPv6";
    
    switch (event_type) {
        case NETUT_IP_ADDED:
            event_str = "添加";
            break;
        case NETUT_IP_REMOVED:
            event_str = "移除";
            break;
        case NETUT_IP_CHANGED:
            event_str = "改变";
            break;
        default:
            event_str = "未知";
    }
    
    time_t now = time(NULL);
    char time_str[32];
    strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", localtime(&now));
    
    printf("[%s] 事件: %s | 接口: %-10s | %-4s地址: %s\n",
           time_str, event_str, interface_name, family_str, ip_address);
}

// 测试示例
#ifdef NETUT_TEST

#ifdef _WIN32
#include <conio.h>
#else
#include <signal.h>

static volatile int g_running = 1;

void signal_handler(int sig) {
    g_running = 0;
}
#endif

int main() {
    printf("=== IP地址变化监控测试（事件驱动） ===\n");
    printf("平台: ");
    
#ifdef _WIN32
    printf("Windows\n");
#elif defined(__APPLE__)
    printf("macOS\n");
#elif defined(__linux__)
    printf("Linux\n");
#else
    printf("未知\n");
#endif
    
    printf("按 Ctrl+C 停止监控...\n\n");
    
    // 创建监控器
    netut_ip_monitor_t *monitor = netut_create_ip_monitor_event(
        netut__example_callback,
        NULL  // 用户数据
    );
    
    if (monitor == NULL) {
        printf("创建监控器失败\n");
        return 1;
    }
    
    // 启动监控
    if (netut_start_ip_monitor_event(monitor) != 0) {
        printf("启动监控失败: %s\n", netut_get_monitor_event_error(monitor));
        netut_free_ip_monitor_event(monitor);
        return 1;
    }
    
    printf("监控已启动，等待IP地址变化...\n\n");
    
#ifndef _WIN32
    // 设置信号处理
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
#endif
    
    // 主事件循环
#ifdef __APPLE__
    // macOS需要运行循环
    printf("开始运行循环（按Ctrl+C退出）...\n");
    netut_process_ip_events_blocking(monitor);
#else
    // Windows和Linux使用轮询处理
    while (g_running) {
        int result = netut_process_ip_events(monitor, 1000); // 1秒超时
        if (result < 0) {
            printf("处理事件失败: %s\n", netut_get_monitor_event_error(monitor));
            break;
        }
        // 这里可以添加其他处理逻辑
    }
#endif
    
    // 停止监控
    printf("\n正在停止监控...\n");
    netut_stop_ip_monitor_event(monitor);
    
    // 释放资源
    netut_free_ip_monitor_event(monitor);
    
    printf("监控已停止\n");
    return 0;
}
#endif
