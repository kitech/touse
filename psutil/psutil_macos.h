#ifndef PSUTIL_MACOS_H
#define PSUTIL_MACOS_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Process information structure */
typedef struct {
    int pid;
    char name[256];
    char path[PROC_PIDPATHINFO_MAXSIZE];
    int ppid;
    char user[64];
    char **arguments;  /* Process arguments array */
    int arg_count;     /* Number of arguments */
} ProcessInfo;

/* Function prototypes */
int psutil_get_process_arguments(int pid, char ***args, int *arg_count);
void psutil_free_arguments(char **args, int count);

int psutil_get_all_processes(ProcessInfo** processes, int* count);
int psutil_get_process_path(int pid, char* buffer, size_t buffer_size);
int psutil_get_process_name(int pid, char* buffer, size_t buffer_size);
void psutil_free_processes(ProcessInfo* processes);
void psutil_free_process_info(ProcessInfo* info);

int psutil_get_current_pid(void);
int psutil_process_exists(int pid);
int psutil_get_full_process_info(int pid, ProcessInfo* info);

#ifdef __cplusplus
}
#endif

#endif
// Total lines: 39
