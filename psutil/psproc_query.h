/**
 * psproc_query.h - Process 方法的跨平台 C shim
 */
#ifndef PSUTIL_PSPROC_QUERY_H
#define PSUTIL_PSPROC_QUERY_H

#include <limits.h>

#ifdef __cplusplus
extern "C" {
#endif

#define PSUTIL_OK 0
#define PSUTIL_NO_PROC -1
#define PSUTIL_ACCESS_DENIED -2
#define PSUTIL_UNSUPPORTED -3
#define PSUTIL_ZOMBIE -4

#define PSUTIL_NONE_U64 ULLONG_MAX
#define PSUTIL_NONE_I64 (-1)
#define PSUTIL_NONE_INT (-1)
#define PSUTIL_NONE_F64 (-1.0)

typedef struct {
    unsigned long long read_count;
    unsigned long long write_count;
    unsigned long long read_bytes;
    unsigned long long write_bytes;
    long long read_chars;
    long long write_chars;
} psutil_IOInfo;

typedef struct {
    unsigned long long rss;
    unsigned long long vms;
    unsigned long long shared;
    unsigned long long text;
    unsigned long long lib;
    unsigned long long data;
    unsigned long long dirty;
    long long uss;
    long long pss;
    long long swap;
} psutil_MemFullInfo;

typedef struct {
    int fd;
    char path[4096];
    long long position;
    int flags;
    char mode[16];
} psutil_OpenFile;

typedef struct {
    char path[4096];
    char addr[128];
    char perms[16];
    unsigned long long rss;
    unsigned long long size;
    long long pss;
    unsigned long long shared_clean;
    unsigned long long shared_dirty;
    unsigned long long private_clean;
    unsigned long long private_dirty;
    unsigned long long referenced;
    unsigned long long anonymous;
    long long swap;
} psutil_MapInfo;

typedef struct {
    int fd;
    int family;
    int typ;
    char laddr_ip[128];
    int laddr_port;
    char raddr_ip[128];
    int raddr_port;
    char status[32];
} psutil_ConnInfo;

int psutil_proc_exe(int pid, char* out, int cap);
int psutil_proc_cwd(int pid, char* out, int cap);
int psutil_proc_status(int pid, char* out, int cap);
int psutil_proc_username(int pid, char* out, int cap);
int psutil_proc_uids(int pid, unsigned long long out[3]);
int psutil_proc_gids(int pid, unsigned long long out[3]);
int psutil_proc_terminal(int pid, char* out, int cap);
int psutil_proc_create_time(int pid, double* out);
int psutil_proc_cpu_num(int pid, int* out);
int psutil_proc_cpu_times(int pid, double* user, double* system,
                          double* cuser, double* csystem, double* iowait);
int psutil_proc_cpu_percent(int pid, double total, double* out);
int psutil_proc_ctx_switches(int pid, unsigned long long* vol,
                             unsigned long long* invol);
int psutil_proc_num_threads(int pid);
int psutil_proc_num_fds(int pid);
int psutil_proc_num_handles(int pid);
int psutil_proc_nice(int pid, int* out);
int psutil_proc_set_nice(int pid, int nice);
int psutil_proc_ionice(int pid, int* cls, int* val);
int psutil_proc_set_ionice(int pid, int cls, int val);
int psutil_proc_affinity(int pid, unsigned long long* mask, int cap,
                         int* count);
int psutil_proc_set_affinity(int pid, const unsigned long long* mask,
                             int count);
int psutil_proc_io(int pid, psutil_IOInfo* out);
int psutil_proc_mem_full(int pid, psutil_MemFullInfo* out);
int psutil_proc_ram_total(unsigned long long* out);
int psutil_proc_open_files(int pid, psutil_OpenFile* out, int cap);
int psutil_proc_memory_maps(int pid, psutil_MapInfo* out, int cap);
int psutil_proc_connections(int pid, psutil_ConnInfo* out, int cap,
                            int want_unix);
int psutil_proc_signal(int pid, int sig);
int psutil_proc_suspend(int pid);
int psutil_proc_resume(int pid);

int psutil_signal_term(void);
int psutil_signal_kill(void);
int psutil_signal_stop(void);
int psutil_signal_cont(void);

#ifdef __cplusplus
}
#endif
#endif
