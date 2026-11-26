/**
 * sysinfo.h - 系统级 psutil API 的跨平台 C shim
 *
 * Linux 分支按 pypi psutil 7.2.x 算法读取 /proc 与 sysfs。
 * 其他平台保留同名入口，返回 PSUTIL_UNSUPPORTED，避免伪造数值。
 */
#ifndef PSUTIL_SYSINFO_H
#define PSUTIL_SYSINFO_H

#include <limits.h>

#ifdef __cplusplus
extern "C" {
#endif

#define PSUTIL_MAX_CPUS 1024
#define PSUTIL_MAX_DISKS 1024
#define PSUTIL_MAX_NICS 256
#define PSUTIL_MAX_ADDRS 4096
#define PSUTIL_MAX_CONNS 8192
#define PSUTIL_MAX_USERS 512

#define PSUTIL_DUPLEX_UNKNOWN 0
#define PSUTIL_DUPLEX_HALF 1
#define PSUTIL_DUPLEX_FULL 2

typedef struct {
    double user;
    double nice;
    double system;
    double idle;
    double iowait;
    double irq;
    double softirq;
    double steal;
    double guest;
    double guest_nice;
} psutil_SysCpuTimes;

typedef struct {
    double user;
    double nice;
    double system;
    double idle;
    double iowait;
    double irq;
    double softirq;
    double steal;
    double guest;
    double guest_nice;
} psutil_CpuTimesPercent;

typedef struct {
    unsigned long long ctx_switches;
    unsigned long long interrupts;
    unsigned long long soft_interrupts;
    unsigned long long syscalls;
} psutil_CpuStats;

typedef struct {
    unsigned long long total;
    unsigned long long available;
    double percent;
    unsigned long long used;
    unsigned long long free_mem;
    unsigned long long active;
    unsigned long long inactive;
    unsigned long long buffers;
    unsigned long long cached;
    unsigned long long shared;
    unsigned long long slab;
} psutil_VirtualMemory;

typedef struct {
    unsigned long long total;
    unsigned long long used;
    unsigned long long free_swap;
    double percent;
    unsigned long long sin;
    unsigned long long sout;
} psutil_SwapMemory;

typedef struct {
    char device[512];
    char mountpoint[1024];
    char fstype[128];
    char opts[512];
} psutil_Partition;

typedef struct {
    char path[4096];
    unsigned long long total;
    unsigned long long used;
    unsigned long long free_disk;
    double percent;
} psutil_DiskUsage;

typedef struct {
    char name[128];
    unsigned long long read_count;
    unsigned long long write_count;
    unsigned long long read_bytes;
    unsigned long long write_bytes;
    unsigned long long read_time;
    unsigned long long write_time;
    unsigned long long read_merged_count;
    unsigned long long write_merged_count;
    unsigned long long busy_time;
} psutil_DiskIO;

typedef struct {
    char name[128];
    unsigned long long bytes_sent;
    unsigned long long bytes_recv;
    unsigned long long packets_sent;
    unsigned long long packets_recv;
    unsigned long long errin;
    unsigned long long errout;
    unsigned long long dropin;
    unsigned long long dropout;
} psutil_NetIO;

typedef struct {
    char name[128];
    int family;
    char address[256];
    char netmask[256];
    char broadcast[256];
    char ptp[256];
} psutil_NicAddress;

typedef struct {
    char name[128];
    int isup;
    int duplex;
    unsigned int speed;
    unsigned int mtu;
    char flags[512];
} psutil_NicStats;

typedef struct {
    int fd;
    int family;
    int typ;
    int pid;
    char laddr_ip[128];
    int laddr_port;
    char raddr_ip[128];
    int raddr_port;
    char status[32];
} psutil_SysConnection;

typedef struct {
    char name[128];
    char terminal[128];
    char host[256];
    double started;
    int pid;
} psutil_User;

/* 返回 CPU 行数（percpu=0 时最多 1）；负数表示错误码。 */
int psutil_sys_cpu_times(psutil_SysCpuTimes* out, int cap, int percpu);
int psutil_sys_cpu_percent_seed(const psutil_SysCpuTimes* cur, int count);
int psutil_sys_cpu_percent(const psutil_SysCpuTimes* cur, int count,
                           double* out);
int psutil_sys_cpu_times_percent_seed(const psutil_SysCpuTimes* cur,
                                      int count);
int psutil_sys_cpu_times_percent(const psutil_SysCpuTimes* cur, int count,
                                 psutil_CpuTimesPercent* out);
int psutil_sys_cpu_count(int logical);
int psutil_sys_cpu_stats(psutil_CpuStats* out);

int psutil_sys_virtual_memory(psutil_VirtualMemory* out);
int psutil_sys_swap_memory(psutil_SwapMemory* out);

int psutil_sys_disk_partitions(int all, psutil_Partition* out, int cap);
int psutil_sys_disk_usage(const char* path, psutil_DiskUsage* out);
int psutil_sys_disk_io_counters(int perdisk, psutil_DiskIO* out, int cap);

int psutil_sys_net_io_counters(int pernic, psutil_NetIO* out, int cap);
int psutil_sys_net_if_addrs(psutil_NicAddress* out, int cap);
int psutil_sys_net_if_stats(psutil_NicStats* out, int cap);
int psutil_sys_net_connections(const char* kind, psutil_SysConnection* out,
                               int cap);

double psutil_sys_boot_time(void);
int psutil_sys_users(psutil_User* out, int cap);

#ifdef __cplusplus
}
#endif
#endif
