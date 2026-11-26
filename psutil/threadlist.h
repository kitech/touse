/**
 * threadlist.h - 跨平台列出进程内所有线程（psutil 根包 API）
 */
#ifndef PSUTIL_THREADLIST_H
#define PSUTIL_THREADLIST_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    unsigned long long tid;
    char name[32];
    char state[8];
    int is_current;   // 调用方所在线程为 1
} psutil_ThreadInfo;

// 写入 out（容量 cap），返回实际线程数；-1 表示平台不支持/失败。
int psutil_list_threads(psutil_ThreadInfo* out, int cap);

#ifdef __cplusplus
}
#endif
#endif
