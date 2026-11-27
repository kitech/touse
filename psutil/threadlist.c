#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
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
#include <dlfcn.h>
#include <stdio.h>
#include <stdint.h>
#include <sys/syscall.h>
#include <unistd.h>

static unsigned long long psutil_tl_vma_size(const char* path, unsigned long long addr) {
    if (!addr) return 0;
    FILE* f = fopen(path, "r");
    if (!f) return 0;
    char line[512];
    unsigned long long size = 0;
    while (fgets(line, sizeof(line), f)) {
        unsigned long long a = 0, b = 0;
        if (sscanf(line, "%llx-%llx", &a, &b) == 2 && addr >= a && addr < b) {
            size = b - a;
            break;
        }
    }
    fclose(f);
    return size;
}

static void psutil_tl_read_str(const char* path, char* out, size_t cap) {
    out[0] = '\0';
    FILE* f = fopen(path, "r");
    if (!f) return;
    if (fgets(out, (int)cap, f)) {
        size_t len = strlen(out);
        while (len && (out[len-1] == '\n' || out[len-1] == '\r')) out[--len] = '\0';
    }
    fclose(f);
}

static const char* psutil_tl_syscall_name(long nr) {
#ifdef SYS_futex
    if (nr == SYS_futex) return "futex";
#endif
#ifdef SYS_epoll_wait
    if (nr == SYS_epoll_wait) return "epoll_wait";
#endif
#ifdef SYS_epoll_pwait
    if (nr == SYS_epoll_pwait) return "epoll_pwait";
#endif
#ifdef SYS_epoll_pwait2
    if (nr == SYS_epoll_pwait2) return "epoll_pwait2";
#endif
#ifdef SYS_poll
    if (nr == SYS_poll) return "poll";
#endif
#ifdef SYS_ppoll
    if (nr == SYS_ppoll) return "ppoll";
#endif
#ifdef SYS_select
    if (nr == SYS_select) return "select";
#endif
#ifdef SYS_pselect6
    if (nr == SYS_pselect6) return "pselect6";
#endif
#ifdef SYS_nanosleep
    if (nr == SYS_nanosleep) return "nanosleep";
#endif
#ifdef SYS_clock_nanosleep
    if (nr == SYS_clock_nanosleep) return "clock_nanosleep";
#endif
#ifdef SYS_read
    if (nr == SYS_read) return "read";
#endif
#ifdef SYS_write
    if (nr == SYS_write) return "write";
#endif
#ifdef SYS_recvfrom
    if (nr == SYS_recvfrom) return "recvfrom";
#endif
#ifdef SYS_recvmsg
    if (nr == SYS_recvmsg) return "recvmsg";
#endif
#ifdef SYS_accept
    if (nr == SYS_accept) return "accept";
#endif
#ifdef SYS_accept4
    if (nr == SYS_accept4) return "accept4";
#endif
#ifdef SYS_connect
    if (nr == SYS_connect) return "connect";
#endif
#ifdef SYS_wait4
    if (nr == SYS_wait4) return "wait4";
#endif
#ifdef SYS_waitid
    if (nr == SYS_waitid) return "waitid";
#endif
#ifdef SYS_openat
    if (nr == SYS_openat) return "openat";
#endif
#ifdef SYS_io_uring_enter
    if (nr == SYS_io_uring_enter) return "io_uring_enter";
#endif
#ifdef SYS_pause
    if (nr == SYS_pause) return "pause";
#endif
    return NULL;
}

static void psutil_tl_read_syscall(const char* path, unsigned long long* pc, char* name, size_t cap) {
    *pc = 0;
    name[0] = '\0';
    FILE* f = fopen(path, "r");
    if (!f) return;
    char line[256];
    if (fgets(line, sizeof(line), f) && strncmp(line, "running", 7) != 0) {
        char* tok = strtok(line, " \t\n");
        char* last = NULL;
        long nr = -1;
        int first = 1;
        while (tok) {
            if (first) {
                nr = strtol(tok, NULL, 10);
                first = 0;
            }
            last = tok;
            tok = strtok(NULL, " \t\n");
        }
        if (last) *pc = strtoull(last, NULL, 16);
        if (nr >= 0) {
            const char* n = psutil_tl_syscall_name(nr);
            if (n) psutil_tl_copy(name, cap, n);
        }
    }
    fclose(f);
}

static void psutil_tl_sym(unsigned long long pc, char* out, size_t cap) {
    out[0] = '\0';
    if (!pc) return;
    Dl_info info;
    if (dladdr((void*)(uintptr_t)pc, &info)) {
        if (info.dli_sname && info.dli_sname[0]) {
            psutil_tl_copy(out, cap, info.dli_sname);
            return;
        }
        if (info.dli_fname && info.dli_fname[0]) {
            const char* base = strrchr(info.dli_fname, '/');
            base = base ? base + 1 : info.dli_fname;
            snprintf(out, cap, "%s+0x%llx", base,
                pc - (unsigned long long)(uintptr_t)info.dli_fbase);
            return;
        }
    }
    snprintf(out, cap, "0x%llx", pc);
}

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
    int self_proc = (pid == (int)getpid());
    char maps_path[96];
    snprintf(maps_path, sizeof(maps_path), "/proc/%d/maps", pid);
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
                    char* fields[26];
                    int count = 0;
                    while (tok && count < 26) {
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
                    // startstack 是字段 28（从 1 起），即 ') ' 之后的第 26 个 token。
                    if (count > 25) {
                        item->stack_size = psutil_tl_vma_size(maps_path, strtoull(fields[25], NULL, 10));
                    }
                    // stack_used: Linux kstkesp 恒为 0，无法获取
                }
            }
            fclose(f);
        }
        snprintf(path, sizeof(path), "/proc/%d/task/%ld/wchan", pid, tid);
        psutil_tl_read_str(path, item->wchan, sizeof(item->wchan));
        if (strcmp(item->wchan, "0") == 0) item->wchan[0] = '\0';
        snprintf(path, sizeof(path), "/proc/%d/task/%ld/syscall", pid, tid);
        psutil_tl_read_syscall(path, &item->pc, item->syscall, sizeof(item->syscall));
        if (self_proc && item->pc) {
            psutil_tl_sym(item->pc, item->func, sizeof(item->func));
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
#include <dlfcn.h>
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

static void psutil_tl_sym(unsigned long long pc, char* out, size_t cap) {
    out[0] = '\0';
    if (!pc) return;
    Dl_info info;
    if (dladdr((void*)(uintptr_t)pc, &info)) {
        if (info.dli_sname && info.dli_sname[0]) {
            psutil_tl_copy(out, cap, info.dli_sname);
            return;
        }
        if (info.dli_fname && info.dli_fname[0]) {
            const char* base = strrchr(info.dli_fname, '/');
            base = base ? base + 1 : info.dli_fname;
            snprintf(out, cap, "%s+0x%llx", base,
                pc - (unsigned long long)(uintptr_t)info.dli_fbase);
            return;
        }
    }
    snprintf(out, cap, "0x%llx", pc);
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
        if (pt) {
            pthread_getname_np(pt, item->name, sizeof(item->name));
            void* sbase = pthread_get_stackaddr_np(pt);
            item->stack_size = (unsigned long long)pthread_get_stacksize_np(pt);
            uintptr_t sp = 0, pc = 0;
#if defined(__x86_64__)
            x86_thread_state64_t st;
            mach_msg_type_number_t stcnt = x86_THREAD_STATE64_COUNT;
            if (thread_get_state(list[i], x86_THREAD_STATE64, (thread_state_t)&st, &stcnt) == KERN_SUCCESS) {
                sp = (uintptr_t)st.__rsp;
                pc = (uintptr_t)st.__rip;
            }
#elif defined(__arm64__) || defined(__aarch64__)
            arm_thread_state64_t st;
            mach_msg_type_number_t stcnt = ARM_THREAD_STATE64_COUNT;
            if (thread_get_state(list[i], ARM_THREAD_STATE64, (thread_state_t)&st, &stcnt) == KERN_SUCCESS) {
                sp = (uintptr_t)st.__sp;
                pc = (uintptr_t)st.__pc;
            }
#endif
            item->pc = (unsigned long long)pc;
            if (sbase && sp && sp <= (uintptr_t)sbase) {
                item->stack_used = (unsigned long long)((uintptr_t)sbase - sp);
            }
            if (pid == (int)getpid() && pc) {
                psutil_tl_sym((unsigned long long)pc, item->func, sizeof(item->func));
            }
        }
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

typedef struct { unsigned long long base; unsigned long long end; char name[64]; } psutil_tl_mod;

static int psutil_tl_modules(DWORD pid, psutil_tl_mod* mods, int cap) {
    int n = 0;
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, pid);
    if (snap == INVALID_HANDLE_VALUE) return 0;
    MODULEENTRY32 me;
    me.dwSize = sizeof(me);
    BOOL ok = Module32First(snap, &me);
    while (ok && n < cap) {
        mods[n].base = (unsigned long long)(uintptr_t)me.modBaseAddr;
        mods[n].end = mods[n].base + (unsigned long long)me.modBaseSize;
        psutil_tl_copy(mods[n].name, sizeof(mods[n].name), me.szModule);
        n++;
        ok = Module32Next(snap, &me);
    }
    CloseHandle(snap);
    return n;
}

static void psutil_tl_win_func(unsigned long long pc, const psutil_tl_mod* mods, int nmods, char* out, size_t cap) {
    out[0] = '\0';
    if (!pc) return;
    for (int i = 0; i < nmods; i++) {
        if (pc >= mods[i].base && pc < mods[i].end) {
            snprintf(out, cap, "%s+0x%llx", mods[i].name, pc - mods[i].base);
            return;
        }
    }
    snprintf(out, cap, "0x%llx", pc);
}

typedef LONG (NTAPI *psutil_ntqit_t)(HANDLE, ULONG, PVOID, ULONG, PULONG);
typedef struct {
    LONG ExitStatus;
    PVOID PebBaseAddress;
    PVOID TebBaseAddress;
    ULONG_PTR UniqueProcessId;
    ULONG_PTR UniqueThreadId;
    ULONG_PTR AffinityMask;
    LONG Priority;
    LONG BasePriority;
} psutil_tbi_t;

static double psutil_tl_filetime(FILETIME ft) {
    unsigned long long v = ((unsigned long long)ft.dwHighDateTime << 32)
        | (unsigned long long)ft.dwLowDateTime;
    return (double)v / 10000000.0;
}

static int psutil_tl_list(int pid, psutil_ThreadInfo* out, int cap, int* truncated) {
    if (truncated) *truncated = 0;
    int self_proc = (pid == (int)GetCurrentProcessId());
    psutil_tl_mod mods[256];
    int nmods = 0;
    psutil_ntqit_t ntqit = NULL;
    if (self_proc) {
        nmods = psutil_tl_modules((DWORD)pid, mods, 256);
        HMODULE ntdll = GetModuleHandleA("ntdll.dll");
        if (ntdll) ntqit = (psutil_ntqit_t)(void*)GetProcAddress(ntdll, "NtQueryInformationThread");
    }
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
            HANDLE th = OpenThread(THREAD_QUERY_INFORMATION | THREAD_GET_CONTEXT | THREAD_SUSPEND_RESUME, FALSE, te.th32ThreadID);
            if (th) {
                FILETIME create, exit, kernel, user;
                if (GetThreadTimes(th, &create, &exit, &kernel, &user)) {
                    item->user_time = psutil_tl_filetime(user);
                    item->system_time = psutil_tl_filetime(kernel);
                }
                if (self_proc && ntqit) {
                    psutil_tbi_t tbi;
                    memset(&tbi, 0, sizeof(tbi));
                    if (ntqit(th, 0, &tbi, sizeof(tbi), NULL) == 0 && tbi.TebBaseAddress) {
                        NT_TIB tib;
                        memset(&tib, 0, sizeof(tib));
                        if (ReadProcessMemory(GetCurrentProcess(), tbi.TebBaseAddress, &tib, sizeof(tib), NULL)) {
                            unsigned long long base = (unsigned long long)(uintptr_t)tib.StackBase;
                            unsigned long long limit = (unsigned long long)(uintptr_t)tib.StackLimit;
                            if (base > limit) item->stack_size = base - limit;
                            CONTEXT ctx;
                            memset(&ctx, 0, sizeof(ctx));
                            ctx.ContextFlags = CONTEXT_CONTROL;
                            int okctx = 0;
                            if (item->is_current) {
                                RtlCaptureContext(&ctx);
                                okctx = 1;
                            } else if (SuspendThread(th) != (DWORD)-1) {
                                okctx = GetThreadContext(th, &ctx) ? 1 : 0;
                                ResumeThread(th);
                            }
                            if (okctx) {
                                unsigned long long sp = 0, pc = 0;
#if defined(_M_X64) || defined(__x86_64__)
                                sp = (unsigned long long)ctx.Rsp;
                                pc = (unsigned long long)ctx.Rip;
#else
                                sp = (unsigned long long)ctx.Esp;
                                pc = (unsigned long long)ctx.Eip;
#endif
                                if (item->is_current) pc = 0; // 当前线程 PC 无意义
                                item->pc = pc;
                                if (base > sp) item->stack_used = base - sp;
                                psutil_tl_win_func(pc, mods, nmods, item->func, sizeof(item->func));
                            }
                        }
                    }
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
