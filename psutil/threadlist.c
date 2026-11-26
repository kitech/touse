#include <string.h>
#include "threadlist.h"

#if defined(__linux__)
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/syscall.h>
#include <unistd.h>

static void psutil_tl_copy(char* dst, size_t cap, const char* src) {
    if (!src) return;
    size_t n = strlen(src);
    if (n >= cap) n = cap - 1;
    memcpy(dst, src, n);
    dst[n] = '\0';
}

int psutil_list_threads(psutil_ThreadInfo* out, int cap) {
    DIR* d = opendir("/proc/self/task");
    if (!d) return -1;
    long self = (long)syscall(SYS_gettid);
    char path[256];
    char line[512];
    int n = 0;
    struct dirent* e;
    while (n < cap && (e = readdir(d)) != NULL) {
        char* end = NULL;
        long tid = strtol(e->d_name, &end, 10);
        if (tid <= 0 || *end != '\0') continue;
        psutil_ThreadInfo* item = &out[n];
        memset(item, 0, sizeof(*item));
        item->tid = (unsigned long long)tid;
        item->is_current = (tid == self);
        snprintf(path, sizeof(path), "/proc/self/task/%ld/comm", tid);
        FILE* f = fopen(path, "r");
        if (f) {
            if (fgets(line, sizeof(line), f)) {
                size_t len = strlen(line);
                while (len && (line[len-1] == '\n' || line[len-1] == '\r')) line[--len] = '\0';
                psutil_tl_copy(item->name, sizeof(item->name), line);
            }
            fclose(f);
        }
        snprintf(path, sizeof(path), "/proc/self/task/%ld/stat", tid);
        f = fopen(path, "r");
        if (f) {
            if (fgets(line, sizeof(line), f)) {
                char* p = strrchr(line, ')');
                if (p && p[1] == ' ' && p[2]) item->state[0] = p[2];
            }
            fclose(f);
        }
        n++;
    }
    closedir(d);
    return n;
}

#elif defined(__APPLE__)
#include <mach/mach.h>
#include <pthread.h>
#include <stdint.h>

int psutil_list_threads(psutil_ThreadInfo* out, int cap) {
    thread_act_array_t list = NULL;
    mach_msg_type_number_t cnt = 0;
    if (task_threads(mach_task_self(), &list, &cnt) != KERN_SUCCESS) return -1;
    uint64_t self = 0;
    pthread_threadid_np(NULL, &self);
    int n = 0;
    for (mach_msg_type_number_t i = 0; i < cnt; i++) {
        uint64_t tid = 0;
        thread_identifier_info_data_t info;
        mach_msg_type_number_t info_cnt = THREAD_IDENTIFIER_INFO_COUNT;
        if (thread_info(list[i], THREAD_IDENTIFIER_INFO, (thread_info_t)&info, &info_cnt) == KERN_SUCCESS) {
            tid = info.thread_id;
        }
        if (tid && n < cap) {
            psutil_ThreadInfo* item = &out[n++];
            memset(item, 0, sizeof(*item));
            item->tid = tid;
            item->is_current = (tid == self);
            pthread_t pt = pthread_from_mach_thread_np(list[i]);
            if (pt) pthread_getname_np(pt, item->name, sizeof(item->name));
            item->state[0] = '?';
        }
        mach_port_deallocate(mach_task_self(), list[i]);
    }
    vm_deallocate(mach_task_self(), (vm_address_t)list, (vm_size_t)(cnt * sizeof(thread_t)));
    return n;
}

#elif defined(_WIN32)
#include <windows.h>
#include <tlhelp32.h>

int psutil_list_threads(psutil_ThreadInfo* out, int cap) {
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
    if (snap == INVALID_HANDLE_VALUE) return -1;
    THREADENTRY32 te;
    te.dwSize = sizeof(te);
    DWORD pid = GetCurrentProcessId();
    DWORD self = GetCurrentThreadId();
    int n = 0;
    BOOL ok = Thread32First(snap, &te);
    while (ok && n < cap) {
        if (te.th32OwnerProcessID == pid) {
            psutil_ThreadInfo* item = &out[n++];
            memset(item, 0, sizeof(*item));
            item->tid = te.th32ThreadID;
            item->is_current = (te.th32ThreadID == self);
            item->state[0] = '?';
        }
        ok = Thread32Next(snap, &te);
    }
    CloseHandle(snap);
    return n;
}

#else
int psutil_list_threads(psutil_ThreadInfo* out, int cap) {
    (void)out;
    (void)cap;
    return -1;
}
#endif
