/**
 * threadlist.h - 跨平台列出进程内所有线程（psutil 根包 API）
 */
#ifndef PSUTIL_THREADLIST_H
#define PSUTIL_THREADLIST_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    unsigned long long id;        /* pypi 兼容 id：macOS 为索引+1，其它为系统 tid */
    unsigned long long tid;
    char name[64];
    char state[8];
    int is_current;
    double user_time;
    double system_time;
    unsigned long long stack_size; /* 0 = 未知 */
    unsigned long long stack_used; /* 0 = 未知 */
    unsigned long long pc;         /* 0 = 未知 */
    char wchan[32];                /* Linux 内核等待函数；其它平台空 */
    char syscall[32];              /* Linux 当前系统调用名；其它平台空 */
    char func[96];                 /* PC 最近符号；无符号时模块+偏移 */
} psutil_ThreadInfo;

// 写入 out（容量 cap），返回实际线程数；-1 表示失败。
// truncated 非 NULL 时，超过 cap 会被标记为 1。
int psutil_list_threads(psutil_ThreadInfo* out, int cap, int* truncated);
int psutil_list_threads_pid(int pid, psutil_ThreadInfo* out, int cap,
                            int* truncated);

#ifdef __cplusplus
}
#endif
#endif
