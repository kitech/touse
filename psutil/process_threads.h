/**
 * psutil_threads.h - 跨平台获取进程线程数的头文件
 * 所有函数添加 psutil_ 前缀
 */

#ifndef PSUTIL_THREADS_H
#define PSUTIL_THREADS_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>

/**
 * 进程信息结构体
 */
typedef struct {
    int pid;
    char name[256];
    int threads;
} psutil_ProcessInfo;

/**
 * 获取指定进程ID的线程数
 * @param pid 进程ID
 * @return 线程数，-1表示失败
 */
int psutil_get_process_thread_count(int pid);

/**
 * 根据进程名获取线程数
 * @param process_name 进程名（不含路径）
 * @return 线程数，-1表示失败
 */
int psutil_get_thread_count_by_name(const char *process_name);

/**
 * 获取所有进程的线程数统计
 * @param callback 回调函数，参数：(pid, 进程名, 线程数)
 */
void psutil_enumerate_process_threads(void (*callback)(int pid, const char *name, int threads));

/**
 * 获取所有进程信息到数组
 * @param processes 输出参数，接收进程数组指针
 * @param max_count 最大获取数量，0表示获取所有
 * @return 实际获取的进程数量
 */
int psutil_get_all_processes(psutil_ProcessInfo **processes, int max_count);

/**
 * 释放进程信息数组
 * @param processes 要释放的进程数组
 */
void psutil_free_processes(psutil_ProcessInfo *processes);

/**
 * 查找线程最多的进程
 */
void psutil_find_max_threads_process(void);

/**
 * 显示线程最多的N个进程
 * @param top_n 显示的数量
 */
void psutil_show_top_processes_by_threads(int top_n);

/**
 * 监控特定进程的线程变化
 * @param pid 要监控的进程ID
 * @param interval_seconds 监控间隔（秒）
 */
void psutil_monitor_threads(int pid, int interval_seconds);

/**
 * 打印进程信息
 * @param pid 进程ID
 * @param name 进程名
 * @param threads 线程数
 */
void psutil_print_process_info(int pid, const char *name, int threads);

#ifdef __cplusplus
}
#endif

#endif // PSUTIL_THREADS_H
