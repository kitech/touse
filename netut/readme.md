# Linux 编译
gcc -std=c99 -DNETUT_TEST -o netut_monitor_event netut_ip_monitor_event.c

# macOS 编译
clang -std=c99 -DNETUT_TEST -o netut_monitor_event netut_ip_monitor_event.c \
    -framework CoreFoundation -framework SystemConfiguration

# Windows (MinGW) 编译
gcc -std=c99 -DNETUT_TEST -o netut_monitor_event.exe netut_ip_monitor_event.c \
    -lws2_32 -liphlpapi
