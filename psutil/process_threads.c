/**
 * psutil_threads.c - 跨平台获取指定进程线程数的函数
 * 所有函数添加 psutil_ 前缀
 * 支持: Windows, Linux, macOS
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <assert.h>

// 平台特定的头文件
#ifdef _WIN32
    #include <windows.h>
    #include <tlhelp32.h>
    #include <psapi.h>
    #pragma comment(lib, "psapi.lib")
#else
    #include <unistd.h>
    #include <dirent.h>
    #include <sys/types.h>
    #include <sys/stat.h>
    #include <fcntl.h>
    #include <ctype.h>
    #ifdef __linux__
        #include <sys/sysinfo.h>
    #elif __APPLE__
        #include <libproc.h>
        #include <sys/sysctl.h>
    #endif
#endif

// ==================== 工具函数 ====================

/**
 * 获取当前时间字符串
 */
static void psutil_get_current_time_string(char *buffer, size_t buffer_size) {
    time_t now = time(NULL);
    struct tm *tm_info = localtime(&now);
    
    if (tm_info) {
        strftime(buffer, buffer_size, "%Y-%m-%d %H:%M:%S", tm_info);
    } else {
        snprintf(buffer, buffer_size, "未知时间");
    }
}

/**
 * 安全字符串复制
 */
static void psutil_safe_strncpy(char *dest, const char *src, size_t dest_size) {
    if (dest_size > 0) {
        strncpy(dest, src, dest_size - 1);
        dest[dest_size - 1] = '\0';
    }
}

// ==================== 结构体定义 ====================

/**
 * 进程信息结构体
 */
typedef struct {
    int pid;
    char name[256];
    int threads;
} psutil_ProcessInfo;

/**
 * 线程监控上下文
 */
typedef struct {
    int target_pid;
    int last_thread_count;
    int interval_seconds;
} psutil_ThreadMonitor;

// ==================== 公共接口 ====================

/**
 * 获取指定进程ID的线程数
 */
int psutil_get_process_thread_count(int pid);

/**
 * 根据进程名获取线程数
 */
int psutil_get_thread_count_by_name(const char *process_name);

/**
 * 获取所有进程的线程数统计
 */
void psutil_enumerate_process_threads(void (*callback)(int pid, const char *name, int threads));

/**
 * 获取所有进程信息到数组
 */
int psutil_get_all_processes(psutil_ProcessInfo **processes, int max_count);

/**
 * 释放进程信息数组
 */
void psutil_free_processes(psutil_ProcessInfo *processes);

/**
 * 查找线程最多的进程
 */
void psutil_find_max_threads_process(void);

/**
 * 显示线程最多的N个进程
 */
void psutil_show_top_processes_by_threads(int top_n);

/**
 * 监控特定进程的线程变化
 */
void psutil_monitor_threads(int pid, int interval_seconds);

/**
 * 打印进程信息
 */
void psutil_print_process_info(int pid, const char *name, int threads);

// ==================== Windows 实现 ====================
#ifdef _WIN32

int psutil_get_process_thread_count(int pid) {
    if (pid <= 0) {
        return -1;
    }
    
    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) {
        return -1;
    }
    
    THREADENTRY32 te32;
    te32.dwSize = sizeof(THREADENTRY32);
    
    int thread_count = 0;
    
    if (Thread32First(hSnapshot, &te32)) {
        do {
            if (te32.th32OwnerProcessID == (DWORD)pid) {
                thread_count++;
            }
        } while (Thread32Next(hSnapshot, &te32));
    }
    
    CloseHandle(hSnapshot);
    return thread_count;
}

int psutil_get_thread_count_by_name(const char *process_name) {
    if (!process_name || strlen(process_name) == 0) {
        return -1;
    }
    
    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) {
        return -1;
    }
    
    PROCESSENTRY32 pe32;
    pe32.dwSize = sizeof(PROCESSENTRY32);
    
    int total_threads = 0;
    
    if (Process32First(hSnapshot, &pe32)) {
        do {
            // 比较进程名（不区分大小写）
            if (_stricmp(pe32.szExeFile, process_name) == 0) {
                total_threads += pe32.cntThreads;
            }
        } while (Process32Next(hSnapshot, &pe32));
    }
    
    CloseHandle(hSnapshot);
    return total_threads;
}

void psutil_enumerate_process_threads(void (*callback)(int pid, const char *name, int threads)) {
    if (!callback) return;
    
    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) {
        return;
    }
    
    PROCESSENTRY32 pe32;
    pe32.dwSize = sizeof(PROCESSENTRY32);
    
    if (Process32First(hSnapshot, &pe32)) {
        do {
            callback((int)pe32.th32ProcessID, pe32.szExeFile, (int)pe32.cntThreads);
        } while (Process32Next(hSnapshot, &pe32));
    }
    
    CloseHandle(hSnapshot);
}

int psutil_get_all_processes(psutil_ProcessInfo **processes, int max_count) {
    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) {
        return 0;
    }
    
    PROCESSENTRY32 pe32;
    pe32.dwSize = sizeof(PROCESSENTRY32);
    
    int count = 0;
    psutil_ProcessInfo *proc_array = NULL;
    
    // 先计算进程数量
    if (Process32First(hSnapshot, &pe32)) {
        do {
            count++;
        } while (Process32Next(hSnapshot, &pe32) && (max_count <= 0 || count < max_count));
    }
    
    if (count == 0) {
        CloseHandle(hSnapshot);
        return 0;
    }
    
    // 分配内存
    proc_array = (psutil_ProcessInfo *)malloc(count * sizeof(psutil_ProcessInfo));
    if (!proc_array) {
        CloseHandle(hSnapshot);
        return 0;
    }
    
    // 重新遍历并填充数据
    Process32First(hSnapshot, &pe32);
    int index = 0;
    
    do {
        proc_array[index].pid = (int)pe32.th32ProcessID;
        psutil_safe_strncpy(proc_array[index].name, pe32.szExeFile, sizeof(proc_array[index].name));
        proc_array[index].threads = (int)pe32.cntThreads;
        index++;
    } while (Process32Next(hSnapshot, &pe32) && index < count);
    
    CloseHandle(hSnapshot);
    *processes = proc_array;
    return count;
}

void psutil_free_processes(psutil_ProcessInfo *processes) {
    if (processes) {
        free(processes);
    }
}

// ==================== Linux 实现 ====================
#elif __linux__

int psutil_get_process_thread_count(int pid) {
    if (pid <= 0) {
        return -1;
    }
    
    char path[256];
    char buffer[1024];
    
    // 通过 /proc/[pid]/status 文件
    snprintf(path, sizeof(path), "/proc/%d/status", pid);
    
    FILE *fp = fopen(path, "r");
    if (!fp) {
        return -1;
    }
    
    int thread_count = -1;
    
    while (fgets(buffer, sizeof(buffer), fp)) {
        if (strncmp(buffer, "Threads:", 8) == 0) {
            sscanf(buffer + 8, "%d", &thread_count);
            break;
        }
    }
    
    fclose(fp);
    
    if (thread_count >= 0) {
        return thread_count;
    }
    
    // 如果status文件没有，尝试通过task目录
    snprintf(path, sizeof(path), "/proc/%d/task", pid);
    
    DIR *dir = opendir(path);
    if (!dir) {
        return -1;
    }
    
    thread_count = 0;
    struct dirent *entry;
    
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_name[0] != '.') {
            int is_number = 1;
            for (int i = 0; entry->d_name[i]; i++) {
                if (!isdigit(entry->d_name[i])) {
                    is_number = 0;
                    break;
                }
            }
            if (is_number) {
                thread_count++;
            }
        }
    }
    
    closedir(dir);
    return thread_count;
}

int psutil_get_thread_count_by_name(const char *process_name) {
    if (!process_name || strlen(process_name) == 0) {
        return -1;
    }
    
    DIR *proc_dir = opendir("/proc");
    if (!proc_dir) {
        return -1;
    }
    
    struct dirent *entry;
    int total_threads = 0;
    
    while ((entry = readdir(proc_dir)) != NULL) {
        if (!isdigit(entry->d_name[0])) {
            continue;
        }
        
        int pid = atoi(entry->d_name);
        
        char cmdline_path[256];
        char cmdline[512];
        
        snprintf(cmdline_path, sizeof(cmdline_path), "/proc/%d/cmdline", pid);
        
        FILE *fp = fopen(cmdline_path, "r");
        if (!fp) {
            continue;
        }
        
        if (fgets(cmdline, sizeof(cmdline), fp)) {
            char *name = strrchr(cmdline, '/');
            if (name) {
                name++;
            } else {
                name = cmdline;
            }
            
            if (strcmp(name, process_name) == 0) {
                int threads = psutil_get_process_thread_count(pid);
                if (threads > 0) {
                    total_threads += threads;
                }
            }
        }
        
        fclose(fp);
    }
    
    closedir(proc_dir);
    return total_threads;
}

void psutil_enumerate_process_threads(void (*callback)(int pid, const char *name, int threads)) {
    if (!callback) return;
    
    DIR *proc_dir = opendir("/proc");
    if (!proc_dir) {
        return;
    }
    
    struct dirent *entry;
    
    while ((entry = readdir(proc_dir)) != NULL) {
        if (!isdigit(entry->d_name[0])) {
            continue;
        }
        
        int pid = atoi(entry->d_name);
        
        char cmdline_path[256];
        char cmdline[512];
        char process_name[256] = "unknown";
        
        snprintf(cmdline_path, sizeof(cmdline_path), "/proc/%d/cmdline", pid);
        
        FILE *fp = fopen(cmdline_path, "r");
        if (fp) {
            if (fgets(cmdline, sizeof(cmdline), fp)) {
                char *name = strrchr(cmdline, '/');
                if (name) {
                    psutil_safe_strncpy(process_name, name + 1, sizeof(process_name));
                } else {
                    psutil_safe_strncpy(process_name, cmdline, sizeof(process_name));
                }
                
                // 如果包含参数，只取第一个单词
                char *space = strchr(process_name, ' ');
                if (space) *space = '\0';
            }
            fclose(fp);
        }
        
        int threads = psutil_get_process_thread_count(pid);
        
        if (threads > 0) {
            callback(pid, process_name, threads);
        }
    }
    
    closedir(proc_dir);
}

int psutil_get_all_processes(psutil_ProcessInfo **processes, int max_count) {
    DIR *proc_dir = opendir("/proc");
    if (!proc_dir) {
        return 0;
    }
    
    struct dirent *entry;
    int count = 0;
    psutil_ProcessInfo *proc_array = NULL;
    int capacity = 100;
    
    proc_array = (psutil_ProcessInfo *)malloc(capacity * sizeof(psutil_ProcessInfo));
    if (!proc_array) {
        closedir(proc_dir);
        return 0;
    }
    
    while ((entry = readdir(proc_dir)) != NULL) {
        if (!isdigit(entry->d_name[0])) {
            continue;
        }
        
        int pid = atoi(entry->d_name);
        
        char cmdline_path[256];
        char cmdline[512];
        char process_name[256] = "unknown";
        
        snprintf(cmdline_path, sizeof(cmdline_path), "/proc/%d/cmdline", pid);
        
        FILE *fp = fopen(cmdline_path, "r");
        if (fp) {
            if (fgets(cmdline, sizeof(cmdline), fp)) {
                char *name = strrchr(cmdline, '/');
                if (name) {
                    psutil_safe_strncpy(process_name, name + 1, sizeof(process_name));
                } else {
                    psutil_safe_strncpy(process_name, cmdline, sizeof(process_name));
                }
                
                char *space = strchr(process_name, ' ');
                if (space) *space = '\0';
            }
            fclose(fp);
        }
        
        int threads = psutil_get_process_thread_count(pid);
        
        if (threads > 0) {
            // 如果数组已满，扩容
            if (count >= capacity) {
                capacity *= 2;
                psutil_ProcessInfo *new_array = (psutil_ProcessInfo *)realloc(proc_array, capacity * sizeof(psutil_ProcessInfo));
                if (!new_array) {
                    free(proc_array);
                    closedir(proc_dir);
                    return 0;
                }
                proc_array = new_array;
            }
            
            proc_array[count].pid = pid;
            psutil_safe_strncpy(proc_array[count].name, process_name, sizeof(proc_array[count].name));
            proc_array[count].threads = threads;
            count++;
            
            if (max_count > 0 && count >= max_count) {
                break;
            }
        }
    }
    
    closedir(proc_dir);
    
    // 调整到实际大小
    if (count > 0) {
        psutil_ProcessInfo *final_array = (psutil_ProcessInfo *)realloc(proc_array, count * sizeof(psutil_ProcessInfo));
        if (final_array) {
            proc_array = final_array;
        }
    } else {
        free(proc_array);
        proc_array = NULL;
    }
    
    *processes = proc_array;
    return count;
}

void psutil_free_processes(psutil_ProcessInfo *processes) {
    if (processes) {
        free(processes);
    }
}

// ==================== macOS 实现 ====================
#elif __APPLE__

int psutil_get_process_thread_count(int pid) {
    if (pid <= 0) {
        return -1;
    }
    
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, pid};
    struct kinfo_proc info;
    size_t size = sizeof(info);
    
    memset(&info, 0, sizeof(info));
    
    if (sysctl(mib, 4, &info, &size, NULL, 0) < 0) {
        return -1;
    }
    
    if (size == 0) {
        return -1;
    }
    
    assert(0); // TODO
    return -2;
    // return info.kp_proc.p_nthreads;
}

int psutil_get_thread_count_by_name(const char *process_name) {
    if (!process_name || strlen(process_name) == 0) {
        return -1;
    }
    
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t size = 0;
    int total_threads = 0;
    
    if (sysctl(mib, 4, NULL, &size, NULL, 0) < 0) {
        return -1;
    }
    
    struct kinfo_proc *procs = (struct kinfo_proc *)malloc(size);
    if (!procs) {
        return -1;
    }
    
    if (sysctl(mib, 4, procs, &size, NULL, 0) < 0) {
        free(procs);
        return -1;
    }
    
    int count = (int)(size / sizeof(struct kinfo_proc));
    
    for (int i = 0; i < count; i++) {
        if (strcmp(procs[i].kp_proc.p_comm, process_name) == 0) {
            assert(0); // TODO
            //total_threads += procs[i].kp_proc.p_nthreads;
        }
    }
    
    free(procs);
    return total_threads;
}

void psutil_enumerate_process_threads(void (*callback)(int pid, const char *name, int threads)) {
    if (!callback) return;
    
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t size = 0;
    
    if (sysctl(mib, 4, NULL, &size, NULL, 0) < 0) {
        return;
    }
    
    struct kinfo_proc *procs = (struct kinfo_proc *)malloc(size);
    if (!procs) {
        return;
    }
    
    if (sysctl(mib, 4, procs, &size, NULL, 0) < 0) {
        free(procs);
        return;
    }
    
    int count = (int)(size / sizeof(struct kinfo_proc));
    
    for (int i = 0; i < count; i++) {
        assert(0); // TODO
        // callback((int)procs[i].kp_proc.p_pid, 
        //         procs[i].kp_proc.p_comm, 
        //         procs[i].kp_proc.p_nthreads);
    }
    
    free(procs);
}

int psutil_get_all_processes(psutil_ProcessInfo **processes, int max_count) {
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t size = 0;
    
    if (sysctl(mib, 4, NULL, &size, NULL, 0) < 0) {
        return 0;
    }
    
    struct kinfo_proc *procs = (struct kinfo_proc *)malloc(size);
    if (!procs) {
        return 0;
    }
    
    if (sysctl(mib, 4, procs, &size, NULL, 0) < 0) {
        free(procs);
        return 0;
    }
    
    int proc_count = (int)(size / sizeof(struct kinfo_proc));
    int count = (max_count > 0 && proc_count > max_count) ? max_count : proc_count;
    
    psutil_ProcessInfo *proc_array = (psutil_ProcessInfo *)malloc(count * sizeof(psutil_ProcessInfo));
    if (!proc_array) {
        free(procs);
        return 0;
    }
    
    for (int i = 0; i < count; i++) {
        proc_array[i].pid = (int)procs[i].kp_proc.p_pid;
        psutil_safe_strncpy(proc_array[i].name, procs[i].kp_proc.p_comm, sizeof(proc_array[i].name));
        assert(0); // TODO
        // proc_array[i].threads = procs[i].kp_proc.p_nthreads;
    }
    
    free(procs);
    *processes = proc_array;
    return count;
}

void psutil_free_processes(psutil_ProcessInfo *processes) {
    if (processes) {
        free(processes);
    }
}

#else
    #error "Unsupported platform"
#endif

// ==================== 辅助函数 ====================

/**
 * 打印进程信息
 */
void psutil_print_process_info(int pid, const char *name, int threads) {
    printf("PID: %6d, Threads: %4d, Name: %s\n", pid, threads, name);
}

/**
 * 监控进程线程变化的上下文
 */
static struct {
    int target_pid;
    int last_thread_count;
    int interval_seconds;
} psutil_g_monitor_context = {0, -1, 1};

/**
 * 监控回调函数（用于psutil_find_max_threads_process）
 */
static struct {
    int max_threads;
    int max_pid;
    char max_name[256];
} psutil_g_finder_context = {0, 0, ""};

/**
 * 查找器回调函数
 */
static void psutil_finder_callback(int pid, const char *name, int threads) {
    if (threads > psutil_g_finder_context.max_threads) {
        psutil_g_finder_context.max_threads = threads;
        psutil_g_finder_context.max_pid = pid;
        psutil_safe_strncpy(psutil_g_finder_context.max_name, name, sizeof(psutil_g_finder_context.max_name));
    }
}

/**
 * 查找线程最多的进程
 */
void psutil_find_max_threads_process(void) {
    // 重置上下文
    psutil_g_finder_context.max_threads = 0;
    psutil_g_finder_context.max_pid = 0;
    psutil_g_finder_context.max_name[0] = '\0';
    
    // 枚举所有进程
    psutil_enumerate_process_threads(psutil_finder_callback);
    
    if (psutil_g_finder_context.max_threads > 0) {
        printf("线程最多的进程: PID=%d, 名称=%s, 线程数=%d\n",
              psutil_g_finder_context.max_pid, 
              psutil_g_finder_context.max_name, 
              psutil_g_finder_context.max_threads);
    } else {
        printf("未找到任何进程\n");
    }
}

/**
 * 监控特定进程的线程变化
 */
void psutil_monitor_threads(int pid, int interval_seconds) {
    if (pid <= 0 || interval_seconds <= 0) {
        printf("无效参数\n");
        return;
    }
    
    printf("开始监控进程 %d 的线程变化（间隔 %d 秒）\n", pid, interval_seconds);
    printf("按 Ctrl+C 停止监控\n\n");
    
    int last_count = -1;
    
    while (1) {
        int current = psutil_get_process_thread_count(pid);
        char timestamp[32];
        psutil_get_current_time_string(timestamp, sizeof(timestamp));
        
        if (current >= 0) {
            if (last_count != current) {
                printf("[%s] PID %d: 线程数变化 %d -> %d\n", 
                      timestamp, pid, last_count, current);
                last_count = current;
            }
        } else {
            printf("[%s] PID %d: 进程不存在或无权限访问\n", timestamp, pid);
            break;
        }
        
        // 等待
#ifdef _WIN32
        Sleep(interval_seconds * 1000);
#else
        sleep(interval_seconds);
#endif
    }
}

/**
 * 排序比较函数（按线程数降序）
 */
static int psutil_compare_by_threads_desc(const void *a, const void *b) {
    const psutil_ProcessInfo *pa = (const psutil_ProcessInfo *)a;
    const psutil_ProcessInfo *pb = (const psutil_ProcessInfo *)b;
    return pb->threads - pa->threads; // 降序
}

/**
 * 显示线程最多的N个进程
 */
void psutil_show_top_processes_by_threads(int top_n) {
    if (top_n <= 0) {
        printf("参数错误: top_n 必须大于0\n");
        return;
    }
    
    psutil_ProcessInfo *processes = NULL;
    int count = psutil_get_all_processes(&processes, 0); // 获取所有进程
    
    if (count <= 0) {
        printf("无法获取进程信息\n");
        return;
    }
    
    // 按线程数降序排序
    qsort(processes, count, sizeof(psutil_ProcessInfo), psutil_compare_by_threads_desc);
    
    printf("\n线程最多的 %d 个进程:\n", top_n > count ? count : top_n);
    printf("==========================================\n");
    
    int display_count = top_n < count ? top_n : count;
    for (int i = 0; i < display_count; i++) {
        printf("%2d. PID: %6d, Threads: %4d, Name: %s\n",
              i + 1, processes[i].pid, processes[i].threads, processes[i].name);
    }
    
    psutil_free_processes(processes);
}

// ==================== 示例和测试代码 ====================

/**
 * 限制回调函数（只显示前几个进程）
 */
static int psutil_g_display_count = 0;
static int psutil_g_max_display = 10;

static void psutil_limited_callback(int pid, const char *name, int threads) {
    if (psutil_g_display_count < psutil_g_max_display) {
        psutil_print_process_info(pid, name, threads);
        psutil_g_display_count++;
    }
}

/**
 * 主测试函数
 */
int main_demo_process_threads_count(int argc, char *argv[]) {
    printf("=== psutil 进程线程数获取工具 ===\n\n");
    
    // 测试1: 获取当前进程的线程数
    printf("1. 当前进程信息:\n");
#ifdef _WIN32
    int current_pid = (int)GetCurrentProcessId();
#else
    int current_pid = (int)getpid();
#endif
    int current_threads = psutil_get_process_thread_count(current_pid);
    if (current_threads >= 0) {
        printf("   当前进程PID: %d, 线程数: %d\n\n", current_pid, current_threads);
    } else {
        printf("   无法获取当前进程信息\n\n");
    }
    
    // 测试2: 枚举前10个进程
    printf("2. 前10个进程的线程数:\n");
    psutil_g_display_count = 0;
    psutil_g_max_display = 10;
    psutil_enumerate_process_threads(psutil_limited_callback);
    
    // 测试3: 显示线程最多的5个进程
    printf("\n3. 线程最多的5个进程:\n");
    psutil_show_top_processes_by_threads(5);
    
    // 测试4: 按进程名获取线程数（如果提供了参数）
    if (argc > 1) {
        printf("\n4. 进程 '%s' 的线程数统计:\n", argv[1]);
        int threads = psutil_get_thread_count_by_name(argv[1]);
        if (threads >= 0) {
            printf("   总线程数: %d\n", threads);
        } else {
            printf("   未找到进程 '%s'\n", argv[1]);
        }
    }
    
    // 测试5: 获取指定PID的线程数
    if (argc > 2) {
        int pid = atoi(argv[2]);
        printf("\n5. PID %d 的线程数:\n", pid);
        int threads = psutil_get_process_thread_count(pid);
        if (threads >= 0) {
            printf("   线程数: %d\n", threads);
        } else {
            printf("   进程不存在或无权限访问\n");
        }
    }
    
    // 测试6: 查找线程最多的单个进程
    printf("\n6. 查找线程最多的单个进程:\n");
    psutil_find_max_threads_process();
    
    // 使用说明
    if (argc == 1) {
        printf("\n使用方法:\n");
        printf("  %s                     # 显示基本信息\n", argv[0]);
        printf("  %s <进程名>           # 显示指定进程名的总线程数\n", argv[0]);
        printf("  %s <进程名> <PID>     # 显示指定PID的线程数\n", argv[0]);
        printf("  %s --top 10           # 显示线程最多的10个进程\n", argv[0]);
        printf("\n示例:\n");
        printf("  %s chrome             # 查看所有chrome进程的总线程数\n", argv[0]);
        printf("  %s firefox 1234       # 查看PID 1234的线程数\n", argv[0]);
        printf("  %s --top 10           # 显示线程最多的10个进程\n", argv[0]);
        printf("  %s --monitor 1234 5   # 监控PID 1234，每5秒检查\n", argv[0]);
    }
    
    // 测试监控功能（可选）
    if (argc > 3 && strcmp(argv[3], "--monitor") == 0) {
        int pid_to_monitor = atoi(argv[2]);
        int interval = argc > 4 ? atoi(argv[4]) : 2;
        psutil_monitor_threads(pid_to_monitor, interval);
    }
    
    // 显示线程最多的N个进程（可选）
    if (argc > 2 && strcmp(argv[1], "--top") == 0) {
        int top_n = atoi(argv[2]);
        psutil_show_top_processes_by_threads(top_n);
    }
    
    // 显示版本信息
    printf("\n");
    char compile_time[32];
    psutil_get_current_time_string(compile_time, sizeof(compile_time));
    printf("psutil 工具 - 编译时间: %s\n", compile_time);
#ifdef _WIN32
    printf("平台: Windows\n");
#elif __linux__
    printf("平台: Linux\n");
#elif __APPLE__
    printf("平台: macOS\n");
#endif
    printf("API 前缀: psutil_*\n");
    
    return 0;
}
