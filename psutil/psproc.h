/**
 * psproc.h - 跨平台进程枚举 shim
 */
#ifndef PSUTIL_PSPROC_H
#define PSUTIL_PSPROC_H

#ifdef __cplusplus
extern "C" {
#endif

/* 返回写入 out 的 PID 数；-1 表示失败，-2 表示平台不支持。 */
int psutil_os_pids(int* out, int cap);
int psutil_os_pid_ppid(int pid);
int psutil_os_pid_exists(int pid);
int psutil_os_process_name(int pid, char* out, int cap);

#ifdef __cplusplus
}
#endif
#endif
