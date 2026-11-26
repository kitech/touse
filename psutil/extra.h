/**
 * extra.h - pypi psutil 7.2.x 补充 API 的跨平台 C shim
 *
 * Linux 分支使用 /proc、sysfs、prlimit、mallinfo2。
 * 其他平台保留同名入口并返回 PSUTIL_UNSUPPORTED，避免伪造数值。
 * 状态码复用 psproc_query.h：0 成功，负数错误。
 */
#ifndef PSUTIL_EXTRA_H
#define PSUTIL_EXTRA_H

#ifdef __cplusplus
extern "C" {
#endif

#define PSUTIL_MAX_ENV_VARS 1024
#define PSUTIL_ENV_KEY_LEN 512
#define PSUTIL_ENV_VALUE_LEN 4096
#define PSUTIL_MAX_SHWTEMP 512
#define PSUTIL_MAX_SFAN 512
#define PSUTIL_MAX_BATTERY 1
#define PSUTIL_MAX_WINSVC 1024

#define PSUTIL_POWER_TIME_UNKNOWN (-1)
#define PSUTIL_POWER_TIME_UNLIMITED (-2)

typedef struct {
    char name[256];
    int ppid;
    unsigned long long uids[3];
    unsigned long long gids[3];
    char status[64];
    double create_time;
    double user;
    double system;
    double children_user;
    double children_system;
    double iowait;
    char terminal[512];
    int num_threads;
    unsigned long long vms;
    unsigned long long rss;
    unsigned long long shared;
    unsigned long long text;
    unsigned long long lib;
    unsigned long long data;
    unsigned long long dirty;
} psutil_OneShot;

typedef struct {
    long long soft;
    long long hard;
} psutil_Rlimit;

typedef struct {
    char key[PSUTIL_ENV_KEY_LEN];
    char value[PSUTIL_ENV_VALUE_LEN];
} psutil_EnvVar;

typedef struct {
    char chip[128];
    char name[128];
    char label[128];
    double current;
    double high;
    double critical;
} psutil_Shwtemp;

typedef struct {
    char chip[128];
    char name[128];
    int speed;
} psutil_Fan;

typedef struct {
    double percent;
    int secsleft;
    int power_plugged;
} psutil_Battery;

typedef struct {
    char service_name[256];
    char display_name[512];
    char binary_path[4096];
    char user_name[512];
    int start_type;
    int service_pid;
    int status;
    char description[4096];
} psutil_WindowsService;

typedef struct {
    unsigned long long heap_used;
    unsigned long long mmap_used;
    int heap_count;
} psutil_HeapInfo;

int psutil_extra_oneshot(int pid, psutil_OneShot* out);
int psutil_extra_rlimit(int pid, int resource, psutil_Rlimit* out);
int psutil_extra_set_rlimit(int pid, int resource, long long soft,
                            long long hard);
int psutil_extra_environ(int pid, psutil_EnvVar* out, int cap);
int psutil_extra_sensors_temperatures(int fahrenheit, psutil_Shwtemp* out,
                                      int cap);
int psutil_extra_sensors_fans(psutil_Fan* out, int cap);
int psutil_extra_sensors_battery(psutil_Battery* out, int cap);
int psutil_extra_win_service_iter(psutil_WindowsService* out, int cap);
int psutil_extra_win_service_get(const char* name, psutil_WindowsService* out);
int psutil_extra_heap_info(psutil_HeapInfo* out);
int psutil_extra_heap_trim(void);

#ifdef __cplusplus
}
#endif
#endif
