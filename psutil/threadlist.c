#include <string.h>
#include <stdlib.h>
#include "threadlist.h"
#include "psproc_query.h"

static int psutil_tl_cmp(const void* a, const void* b) {
    const psutil_ThreadInfo* x = (const psutil_ThreadInfo*)a;
    const psutil_ThreadInfo* y = (const psutil_ThreadInfo*)b;
    return (x->id > y->id) - (x->id < y->id);
}

static void psutil_tl_copy(char* dst, size_t cap, const char* src) {
    if (!src) return;
    size_t n = strlen(src);
    if (n >= cap) n = cap - 1;
    memcpy(dst, src, n);
    dst[n] = '\0';
}

#if defined(__linux__)
#include <dirent.h>
#include <stdio.h>
#include <sys/syscall.h>
#include <unistd.h>

static int psutil_tl_list(int pid, psutil_ThreadInfo* out, int cap, int* truncated) {
    if (truncated) *truncated = 0;
    char taskdir[128];
    snprintf(taskdir, sizeof(taskdir), "/proc/%d/task", pid);
    DIR* d = opendir(taskdir);
    if (!d) return PSUTIL_NO_PROC;
    long self = (long)syscall(SYS_gettid);
    if (pid != (int)getpid()) self = -1;
    long hz = sysconf(_SC_CLK_TCK);
    if (hz <= 0) hz = 100;
    char path[256];
    char line[512];
    int n = 0;
    struct dirent* e;
    while ((e = readdir(d)) != NULL) {
        char* end = NULL;
        long tid = strtol(e->d_name, &end, 10);
        if (tid <= 0 || *end != '\0') continue;
        if (n >= cap) {
            if (truncated) *truncated = 1;
            continue;
        }
        psutil_ThreadInfo* item = &out[n];
        memset(item, 0, sizeof(*item));
        item->id = (unsigned long long)tid;
        item->tid = (unsigned long long)tid;
        item->is_current = (tid == self);
        snprintf(path, sizeof(path), "/proc/%d/task/%ld/comm", pid, tid);
        FILE* f = fopen(path, "r");
        if (f) {
            if (fgets(line, sizeof(line), f)) {
                size_t len = strlen(line);
                while (len && (line[len-1] == '\n' || line[len-1] == '\r')) line[--len] = '\0';
                psutil_tl_copy(item->name, sizeof(item->name), line);
            }
            fclose(f);
        }
        snprintf(path, sizeof(path), "/proc/%d/task/%ld/stat", pid, tid);
        f = fopen(path, "r");
        if (f) {
            if (fgets(line, sizeof(line), f)) {
                char* p = strrchr(line, ')');
                if (p) {
                    char* tok = strtok(p + 2, " \t\n");
                    char* fields[13];
                    int count = 0;
                    while (tok && count < 13) {
                        fields[count++] = tok;
                        tok = strtok(NULL, " \t\n");
                    }
                    if (count > 0 && fields[0][0]) item->state[0] = fields[0][0];
                    // /proc/<tid>/stat 中 utime/stime 是字段 14/15（从 1 起），
                    // 即 ') ' 之后的第 12/13 个 token。
                    if (count > 12) {
                        item->user_time = (double)atoll(fields[11]) / (double)hz;
                        item->system_time = (double)atoll(fields[12]) / (double)hz;
                    }
                }
            }
            fclose(f);
        }
        n++;
    }
    closedir(d);
    qsort(out, (size_t)n, sizeof(psutil_ThreadInfo), psutil_tl_cmp);
    return n;
}

int psutil_list_threads(psutil_ThreadInfo* out, int cap, int* truncated) {
    return psutil_tl_list((int)getpid(), out, cap, truncated);
}
int psutil_list_threads_pid(int pid, psutil_ThreadInfo* out, int cap,
                            int* truncated) {
    return psutil_tl_list(pid, out, cap, truncated);
}

#elif defined(__APPLE__)
#include <AvailabilityMacros.h>
#include <mach/mach.h>
#include <pthread.h>
#include <stdint.h>
#include <unistd.h>

static char psutil_tl_state(int run_state) {
    switch (run_state) {
        case TH_STATE_RUNNING: return 'R';
        case TH_STATE_WAITING: return 'S';
        case TH_STATE_STOPPED: return 'T';
        case TH_STATE_UNINTERRUPTIBLE: return 'D';
        case TH_STATE_HALTED: return 'X';
        default: return '?';
    }
}

static int psutil_tl_list(int pid, psutil_ThreadInfo* out, int cap, int* truncated) {
    if (truncated) *truncated = 0;
    thread_act_array_t list = NULL;
    mach_msg_type_number_t cnt = 0;
    mach_port_t task = mach_task_self();
    if (pid != (int)getpid()) {
        if (task_for_pid(mach_task_self(), (pid_t)pid, &task) != KERN_SUCCESS)
            return PSUTIL_ACCESS_DENIED;
    }
    if (task_threads(task, &list, &cnt) != KERN_SUCCESS) {
        return pid == (int)getpid() ? PSUTIL_NO_PROC : PSUTIL_ACCESS_DENIED;
    }
    uint64_t self = 0;
    if (pid == (int)getpid()) pthread_threadid_np(NULL, &self);
    else self = (uint64_t)-1;
    int n = 0;
    for (mach_msg_type_number_t i = 0; i < cnt; i++) {
        if (n >= cap) {
            if (truncated) *truncated = 1;
            mach_port_deallocate(mach_task_self(), list[i]);
            continue;
        }
        uint64_t tid = 0;
        thread_identifier_info_data_t info;
        mach_msg_type_number_t info_cnt = THREAD_IDENTIFIER_INFO_COUNT;
        if (thread_info(list[i], THREAD_IDENTIFIER_INFO, (thread_info_t)&info, &info_cnt) == KERN_SUCCESS) {
            tid = info.thread_id;
        }
        psutil_ThreadInfo* item = &out[n++];
        memset(item, 0, sizeof(*item));
        item->id = (unsigned long long)(i + 1); /* 与 pypi 7.2.0 macOS 一致 */
        item->tid = tid;
        item->is_current = (tid != 0 && tid == self);
        thread_basic_info_data_t basic;
        mach_msg_type_number_t basic_cnt = THREAD_BASIC_INFO_COUNT;
        memset(&basic, 0, sizeof(basic));
        if (thread_info(list[i], THREAD_BASIC_INFO, (thread_info_t)&basic, &basic_cnt) == KERN_SUCCESS) {
            item->user_time = (double)basic.user_time.seconds
                + (double)basic.user_time.microseconds / 1000000.0;
            item->system_time = (double)basic.system_time.seconds
                + (double)basic.system_time.microseconds / 1000000.0;
            item->state[0] = psutil_tl_state(basic.run_state);
        }
#if defined(__MAC_OS_X_VERSION_MIN_REQUIRED) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
        pthread_t pt = pthread_from_mach_thread_np(list[i]);
        if (pt) pthread_getname_np(pt, item->name, sizeof(item->name));
#endif
        mach_port_deallocate(mach_task_self(), list[i]);
    }
    vm_deallocate(mach_task_self(), (vm_address_t)list, (vm_size_t)(cnt * sizeof(thread_t)));
    qsort(out, (size_t)n, sizeof(psutil_ThreadInfo), psutil_tl_cmp);
    return n;
}

int psutil_list_threads(psutil_ThreadInfo* out, int cap, int* truncated) {
    return psutil_tl_list((int)getpid(), out, cap, truncated);
}
int psutil_list_threads_pid(int pid, psutil_ThreadInfo* out, int cap,
                            int* truncated) {
    return psutil_tl_list(pid, out, cap, truncated);
}

#elif defined(_WIN32)
#include <windows.h>
#include <tlhelp32.h>

static double psutil_tl_filetime(FILETIME ft) {
    unsigned long long v = ((unsigned long long)ft.dwHighDateTime << 32)
        | (unsigned long long)ft.dwLowDateTime;
    return (double)v / 10000000.0;
}

static int psutil_tl_list(int pid, psutil_ThreadInfo* out, int cap, int* truncated) {
    if (truncated) *truncated = 0;
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
    if (snap == INVALID_HANDLE_VALUE) return PSUTIL_NO_PROC;
    THREADENTRY32 te;
    te.dwSize = sizeof(te);
    DWORD want = (DWORD)pid;
    DWORD self = GetCurrentThreadId();
    int n = 0;
    BOOL ok = Thread32First(snap, &te);
    while (ok) {
        if (te.th32OwnerProcessID == want) {
            if (n >= cap) {
                if (truncated) *truncated = 1;
                ok = Thread32Next(snap, &te);
                continue;
            }
            psutil_ThreadInfo* item = &out[n++];
            memset(item, 0, sizeof(*item));
            item->id = (unsigned long long)te.th32ThreadID;
            item->tid = (unsigned long long)te.th32ThreadID;
            item->is_current = (want == GetCurrentProcessId() && te.th32ThreadID == self);
            item->state[0] = '?';
            HANDLE th = OpenThread(THREAD_QUERY_INFORMATION, FALSE, te.th32ThreadID);
            if (th) {
                FILETIME create, exit, kernel, user;
                if (GetThreadTimes(th, &create, &exit, &kernel, &user)) {
                    item->user_time = psutil_tl_filetime(user);
                    item->system_time = psutil_tl_filetime(kernel);
                }
                CloseHandle(th);
            }
        }
        ok = Thread32Next(snap, &te);
    }
    CloseHandle(snap);
    qsort(out, (size_t)n, sizeof(psutil_ThreadInfo), psutil_tl_cmp);
    return n;
}

int psutil_list_threads(psutil_ThreadInfo* out, int cap, int* truncated) {
    return psutil_tl_list((int)GetCurrentProcessId(), out, cap, truncated);
}
int psutil_list_threads_pid(int pid, psutil_ThreadInfo* out, int cap,
                            int* truncated) {
    return psutil_tl_list(pid, out, cap, truncated);
}

#else
int psutil_list_threads(psutil_ThreadInfo* out, int cap, int* truncated) {
    (void)out;
    (void)cap;
    if (truncated) *truncated = 0;
    return -1;
}
int psutil_list_threads_pid(int pid, psutil_ThreadInfo* out, int cap,
                            int* truncated) {
    (void)pid;
    (void)out;
    (void)cap;
    if (truncated) *truncated = 0;
    return -1;
}
#endif
