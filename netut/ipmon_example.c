#include <stdio.h>
#include <signal.h>
#include <unistd.h>

volatile int running = 1;

void handle_signal(int sig) {
    running = 0;
}

void ip_change_handler(const char *interface_name,
                      const char *ip_address,
                      int family,
                      int event_type,
                      void *user_data) {
    printf("IP变化: 接口=%s, IP=%s, 类型=%s, 事件=%s\n",
           interface_name,
           ip_address,
           (family == AF_INET) ? "IPv4" : "IPv6",
           (event_type == NETUT_IP_ADDED) ? "添加" : 
           (event_type == NETUT_IP_REMOVED) ? "移除" : "改变");
}

int main() {
    // 设置信号处理
    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);
    
    // 创建事件驱动监控器
    netut_ip_monitor_t *monitor = netut_create_ip_monitor_event(
        ip_change_handler,
        NULL
    );
    
    if (!monitor) {
        printf("创建监控器失败\n");
        return 1;
    }
    
    // 启动监控
    if (netut_start_ip_monitor_event(monitor) != 0) {
        printf("启动失败: %s\n", netut_get_monitor_event_error(monitor));
        netut_free_ip_monitor_event(monitor);
        return 1;
    }
    
    printf("IP地址监控已启动\n");
    
    // 事件处理循环
    while (running) {
        // 处理事件，100毫秒超时（非阻塞）
        int result = netut_process_ip_events(monitor, 100);
        
        if (result < 0) {
            printf("事件处理错误: %s\n", netut_get_monitor_event_error(monitor));
            break;
        }
        
        // 这里可以执行其他任务
        if (result == 1) {
            // 超时，没有事件发生
            // printf("等待事件...\n");
        }
    }
    
    // 清理
    netut_stop_ip_monitor_event(monitor);
    netut_free_ip_monitor_event(monitor);
    
    printf("监控已停止\n");
    return 0;
}
