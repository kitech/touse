/**
 * psutil_process_memory.c - 跨平台获取进程内存使用量
 * 支持Linux, macOS 和 Windows
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>  // 添加errno头文件

#ifdef _WIN32
    #include <windows.h>
    #include <psapi.h>
    #pragma comment(lib, "psapi.lib")
#else
    #include <unistd.h>
    #include <sys/types.h>
    #include <sys/stat.h>
    #include <fcntl.h>
    #include <dirent.h>
#endif

// 内存使用信息结构体
typedef struct {
    unsigned long long virtual_memory;   // 虚拟内存大小 (字节)
    unsigned long long resident_memory;  // 常驻内存大小 (字节)
    unsigned long long shared_memory;    // 共享内存大小 (字节) (Linux only)
    int pid;                             // 进程ID
    int error_code;                      // 错误代码
    char error_msg[256];                 // 错误信息
} psutil_memory_info_t;

/**
 * @brief 获取指定进程的内存使用信息
 * @param pid 进程ID
 * @return psutil_memory_info_t 内存信息结构体
 */
psutil_memory_info_t psutil_get_process_memory(int pid) {
    psutil_memory_info_t mem_info = {0};
    mem_info.pid = pid;
    
#ifdef _WIN32
    // Windows 实现
    HANDLE hProcess = NULL;
    PROCESS_MEMORY_COUNTERS pmc;
    
    // 打开进程
    hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, pid);
    if (hProcess == NULL) {
        mem_info.error_code = GetLastError();
        sprintf(mem_info.error_msg, "无法打开进程 PID: %d", pid);
        return mem_info;
    }
    
    // 获取内存信息
    if (GetProcessMemoryInfo(hProcess, &pmc, sizeof(pmc))) {
        mem_info.virtual_memory = pmc.PagefileUsage;      // 提交大小
        mem_info.resident_memory = pmc.WorkingSetSize;    // 工作集大小
        
        // Windows没有明确的共享内存概念，可以设置为0或使用其他指标
        mem_info.shared_memory = 0;
        mem_info.error_code = 0;
        mem_info.error_msg[0] = '\0';
    } else {
        mem_info.error_code = GetLastError();
        sprintf(mem_info.error_msg, "获取内存信息失败");
    }
    
    CloseHandle(hProcess);
    
#elif defined(__APPLE__)
    // macOS 实现
    char path[256];
    FILE *fp;
    char line[256];
    unsigned long long vmsize = 0, rss = 0;
    int found_vmsize = 0, found_rss = 0;
    
    // 尝试使用sysctl获取信息（macOS通常没有/proc）
    // 或者使用task_info API（更准确）
    
    // 方法1：使用task_info API（需要链接libproc）
    // 这里先提供一个简单的实现
    
    // 尝试使用ps命令获取（备用方法）
    char command[256];
    sprintf(command, "ps -o rss=,vsize= -p %d 2>/dev/null", pid);
    fp = popen(command, "r");
    
    if (fp == NULL) {
        mem_info.error_code = errno;
        sprintf(mem_info.error_msg, "无法执行ps命令 PID: %d", pid);
        return mem_info;
    }
    
    if (fgets(line, sizeof(line), fp)) {
        // ps输出格式：RSS VSIZE
        if (sscanf(line, "%llu %llu", &rss, &vmsize) == 2) {
            mem_info.virtual_memory = vmsize;
            mem_info.resident_memory = rss * 1024; // ps输出RSS是KB，转换为字节
            mem_info.shared_memory = 0;
            mem_info.error_code = 0;
            mem_info.error_msg[0] = '\0';
        } else {
            mem_info.error_code = 1;
            sprintf(mem_info.error_msg, "解析ps输出失败");
        }
    } else {
        mem_info.error_code = 1;
        sprintf(mem_info.error_msg, "进程不存在或无权限访问 PID: %d", pid);
    }
    
    pclose(fp);
    
#else
    // Linux 实现
    char path[256];
    FILE *fp;
    char line[256];
    unsigned long long vmsize = 0, rss = 0, shared = 0;
    
    // 读取/proc/[pid]/statm文件
    snprintf(path, sizeof(path), "/proc/%d/statm", pid);
    fp = fopen(path, "r");
    
    if (fp == NULL) {
        mem_info.error_code = errno;
        snprintf(mem_info.error_msg, sizeof(mem_info.error_msg), 
                "无法打开进程文件 PID: %d (错误: %s)", pid, strerror(errno));
        return mem_info;
    }
    
    if (fgets(line, sizeof(line), fp)) {
        // statm文件格式: size resident shared text lib data dt
        if (sscanf(line, "%llu %llu %llu", &vmsize, &rss, &shared) >= 2) {
            long page_size = sysconf(_SC_PAGESIZE);
            if (page_size <= 0) {
                page_size = 4096; // 默认页大小
            }
            
            mem_info.virtual_memory = vmsize * page_size;
            mem_info.resident_memory = rss * page_size;
            if (sscanf(line, "%llu %llu %llu", &vmsize, &rss, &shared) == 3) {
                mem_info.shared_memory = shared * page_size;
            } else {
                mem_info.shared_memory = 0;
            }
            mem_info.error_code = 0;
            mem_info.error_msg[0] = '\0';
        } else {
            mem_info.error_code = 1;
            sprintf(mem_info.error_msg, "解析/proc/statm文件失败");
        }
    } else {
        mem_info.error_code = errno;
        snprintf(mem_info.error_msg, sizeof(mem_info.error_msg), 
                "读取内存信息失败 (错误: %s)", strerror(errno));
    }
    
    fclose(fp);
#endif
    
    return mem_info;
}

/**
 * @brief 获取当前进程的内存使用信息
 * @return psutil_memory_info_t 内存信息结构体
 */
psutil_memory_info_t psutil_get_current_process_memory(void) {
#ifdef _WIN32
    return psutil_get_process_memory(GetCurrentProcessId());
#else
    return psutil_get_process_memory(getpid());
#endif
}

void psutil_get_process_memory_2(int pid, psutil_memory_info_t* memi) {
    psutil_memory_info_t m = psutil_get_process_memory(pid);
    memcpy(memi, &m, sizeof(m));
}

/**
 * @brief 打印内存信息到标准输出
 * @param mem_info 内存信息结构体
 */
void psutil_print_memory_info(const psutil_memory_info_t *mem_info) {
    if (mem_info->error_code != 0) {
        printf("错误 [%d]: %s\n", mem_info->error_code, mem_info->error_msg);
        return;
    }
    
    printf("进程 %d 内存使用:\n", mem_info->pid);
    printf("  虚拟内存: %.2f MB\n", mem_info->virtual_memory / (1024.0 * 1024.0));
    printf("  常驻内存: %.2f MB\n", mem_info->resident_memory / (1024.0 * 1024.0));
    if (mem_info->shared_memory > 0) {
        printf("  共享内存: %.2f MB\n", mem_info->shared_memory / (1024.0 * 1024.0));
    }
}

/**
 * @brief 将内存信息格式化为JSON字符串
 * @param mem_info 内存信息结构体
 * @param buffer 输出缓冲区
 * @param buffer_size 缓冲区大小
 * @return 成功返回0，失败返回-1
 */
int psutil_format_memory_info_json(const psutil_memory_info_t *mem_info, 
                                   char *buffer, size_t buffer_size) {
    if (mem_info->error_code != 0) {
        snprintf(buffer, buffer_size,
                "{\"error\":true,\"code\":%d,\"message\":\"%s\"}",
                mem_info->error_code, mem_info->error_msg);
        return -1;
    }
    
    snprintf(buffer, buffer_size,
            "{\"pid\":%d,"
            "\"virtual_memory\":%llu,"
            "\"resident_memory\":%llu,"
            "\"shared_memory\":%llu,"
            "\"error\":false}",
            mem_info->pid,
            mem_info->virtual_memory,
            mem_info->resident_memory,
            mem_info->shared_memory);
    
    return 0;
}

// 辅助函数：安全地获取进程信息
int psutil_process_exists(int pid) {
#ifdef _WIN32
    HANDLE hProcess = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (hProcess != NULL) {
        CloseHandle(hProcess);
        return 1;
    }
    return 0;
#else
    char path[256];
    snprintf(path, sizeof(path), "/proc/%d", pid);
    struct stat st;
    return (stat(path, &st) == 0);
#endif
}

// 测试示例
#ifdef PSUTIL_TEST
int main(int argc, char *argv[]) {
    int pid;
    
    if (argc > 1) {
        pid = atoi(argv[1]);
        printf("获取进程 %d 的内存信息...\n", pid);
        
        // 检查进程是否存在
        if (!psutil_process_exists(pid)) {
            printf("错误: 进程 %d 不存在或无权限访问\n", pid);
            return 1;
        }
    } else {
        printf("获取当前进程的内存信息...\n");
        pid = -1;
    }
    
    psutil_memory_info_t mem_info;
    
    if (pid > 0) {
        mem_info = psutil_get_process_memory(pid);
    } else {
        mem_info = psutil_get_current_process_memory();
    }
    
    // 打印内存信息
    psutil_print_memory_info(&mem_info);
    
    // 格式化为JSON
    char json_buffer[512];
    if (psutil_format_memory_info_json(&mem_info, json_buffer, sizeof(json_buffer)) == 0) {
        printf("\nJSON格式:\n%s\n", json_buffer);
    }
    
    // 显示人类可读格式
    printf("\n人类可读格式:\n");
    printf("进程 %d:\n", mem_info.pid);
    if (mem_info.error_code == 0) {
        printf("  RAM使用: %.2f MB\n", mem_info.resident_memory / (1024.0 * 1024.0));
        printf("  虚拟内存: %.2f MB\n", mem_info.virtual_memory / (1024.0 * 1024.0));
        if (mem_info.shared_memory > 0) {
            printf("  共享内存: %.2f MB\n", mem_info.shared_memory / (1024.0 * 1024.0));
        }
    }
    
    return mem_info.error_code;
}
#endif
