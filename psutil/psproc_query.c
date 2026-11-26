#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <limits.h>
#include <time.h>

#ifndef _WIN32
#include <signal.h>
#endif

#include "psproc.h"
#include "psproc_query.h"

static void psq_copy(char* dst, int cap, const char* src) {
    if (!src || cap <= 0) return;
    int n = (int)strlen(src);
    if (n >= cap) n = cap - 1;
    memcpy(dst, src, (size_t)n);
    dst[n] = '\0';
}

static void psq_strip_nl(char* s) {
    size_t n = strlen(s);
    while (n && (s[n - 1] == '\n' || s[n - 1] == '\r')) s[--n] = '\0';
}

static int psq_errno(int e) {
    (void)e;
#if !defined(_WIN32)
    if (e == ENOENT || e == ESRCH) return PSUTIL_NO_PROC;
    if (e == EACCES || e == EPERM) return PSUTIL_ACCESS_DENIED;
#endif
    return PSUTIL_NO_PROC;
}

#define PSQ_CPU_CACHE 4096

int psutil_proc_cpu_percent(int pid, double total, double* out) {
    static int pids[PSQ_CPU_CACHE];
    static double totals[PSQ_CPU_CACHE];
    static time_t stamps[PSQ_CPU_CACHE];
    time_t now = time(NULL);
    int slot = -1;
    for (int i = 0; i < PSQ_CPU_CACHE; i++) {
        if (pids[i] == pid) {
            slot = i;
            break;
        }
    }
    if (slot < 0) {
        for (int i = 0; i < PSQ_CPU_CACHE; i++) {
            if (pids[i] == 0) {
                slot = i;
                break;
            }
        }
        if (slot < 0) return PSUTIL_UNSUPPORTED;
        pids[slot] = pid;
        totals[slot] = total;
        stamps[slot] = now;
        *out = 0.0;
        return PSUTIL_OK;
    }
    if (stamps[slot] == 0 || now <= stamps[slot] || total < totals[slot]) {
        totals[slot] = total;
        stamps[slot] = now;
        *out = 0.0;
        return PSUTIL_OK;
    }
    double elapsed = difftime(now, stamps[slot]);
    *out = elapsed > 0.0 ? 100.0 * (total - totals[slot]) / elapsed : 0.0;
    totals[slot] = total;
    stamps[slot] = now;
    return PSUTIL_OK;
}

#if defined(__linux__)

#include <dirent.h>
#include <fcntl.h>
#include <pwd.h>
#include <sched.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/sysmacros.h>
#include <unistd.h>

#ifndef SYS_ioprio_get
#define SYS_ioprio_get 252
#endif
#ifndef SYS_ioprio_set
#define SYS_ioprio_set 251
#endif

static int psq_read_line(const char* path, char* buf, int cap) {
    FILE* f = fopen(path, "r");
    if (!f) return -1;
    if (!fgets(buf, cap, f)) {
        fclose(f);
        return -1;
    }
    fclose(f);
    return 0;
}

static int psq_status_raw(int pid, char* out, int cap) {
    (void)cap;
    char path[256];
    char line[512];
    snprintf(path, sizeof(path), "/proc/%d/status", pid);
    FILE* f = fopen(path, "r");
    if (!f) return psq_errno(errno);
    int found = 0;
    while (fgets(line, sizeof(line), f)) {
        if (strncmp(line, "State:", 6) == 0) {
            char* p = line + 6;
            while (*p == ' ' || *p == '\t') p++;
            const char* name = "?";
            switch (p[0]) {
                case 'R': name = "running"; break;
                case 'S': name = "sleeping"; break;
                case 'D': name = "disk-sleep"; break;
                case 'Z': name = "zombie"; break;
                case 'T': name = "stopped"; break;
                case 't': name = "tracing-stop"; break;
                case 'X': case 'x': name = "dead"; break;
                case 'K': name = "wake-kill"; break;
                case 'W': name = "waking"; break;
                case 'P': name = "parked"; break;
                case 'I': name = "idle"; break;
                default: break;
            }
            psq_copy(out, cap, name);
            found = 1;
            break;
        }
    }
    fclose(f);
    return found ? PSUTIL_OK : PSUTIL_NO_PROC;
}

static int psq_guard(int pid) {
    if (!psutil_os_pid_exists(pid)) return PSUTIL_NO_PROC;
    char st[8];
    int rc = psq_status_raw(pid, st, (int)sizeof(st));
    if (rc != PSUTIL_OK) return rc;
    if (strncmp(st, "zombie", 6) == 0) return PSUTIL_ZOMBIE;
    return PSUTIL_OK;
}

static int psq_stat_tokens(int pid, char* toks[], int cap) {
    char path[256];
    char line[2048];
    snprintf(path, sizeof(path), "/proc/%d/stat", pid);
    if (psq_read_line(path, line, sizeof(line)) != 0) return -1;
    char* p = strrchr(line, ')');
    if (!p) return -1;
    int n = 0;
    char* tok = strtok(p + 2, " \t\n");
    while (tok && n < cap) {
        toks[n++] = tok;
        tok = strtok(NULL, " \t\n");
    }
    return n;
}

static int psq_key_u64(int pid, const char* file, const char* key,
                       unsigned long long* out) {
    char path[256];
    char line[512];
    snprintf(path, sizeof(path), "/proc/%d/%s", pid, file);
    FILE* f = fopen(path, "r");
    if (!f) return psq_errno(errno);
    int found = 0;
    while (fgets(line, sizeof(line), f)) {
        if (strncmp(line, key, strlen(key)) == 0) {
            char* p = strchr(line, ':');
            if (p) {
                *out = strtoull(p + 1, NULL, 10);
                found = 1;
                break;
            }
        }
    }
    fclose(f);
    return found ? PSUTIL_OK : PSUTIL_NO_PROC;
}

static double psq_btime(void) {
    char line[512];
    FILE* f = fopen("/proc/stat", "r");
    if (!f) return 0.0;
    while (fgets(line, sizeof(line), f)) {
        if (strncmp(line, "btime ", 6) == 0) {
            fclose(f);
            return atof(line + 6);
        }
    }
    fclose(f);
    return 0.0;
}

static long psq_hz(void) {
    long hz = sysconf(_SC_CLK_TCK);
    return hz > 0 ? hz : 100;
}

int psutil_proc_exe(int pid, char* out, int cap) {
    int rc = psq_guard(pid);
    if (rc != PSUTIL_OK) return rc;
    char path[256];
    char buf[4096];
    snprintf(path, sizeof(path), "/proc/%d/exe", pid);
    ssize_t n = readlink(path, buf, sizeof(buf) - 1);
    if (n < 0) return psq_errno(errno);
    buf[n] = '\0';
    psq_copy(out, cap, buf);
    return PSUTIL_OK;
}

int psutil_proc_cwd(int pid, char* out, int cap) {
    int rc = psq_guard(pid);
    if (rc != PSUTIL_OK) return rc;
    char path[256];
    char buf[4096];
    snprintf(path, sizeof(path), "/proc/%d/cwd", pid);
    ssize_t n = readlink(path, buf, sizeof(buf) - 1);
    if (n < 0) return psq_errno(errno);
    buf[n] = '\0';
    psq_copy(out, cap, buf);
    return PSUTIL_OK;
}

int psutil_proc_status(int pid, char* out, int cap) {
    return psq_status_raw(pid, out, cap);
}

int psutil_proc_username(int pid, char* out, int cap) {
    int rc = psq_guard(pid);
    if (rc != PSUTIL_OK) return rc;
    unsigned long long uids[3];
    rc = psutil_proc_uids(pid, uids);
    if (rc != PSUTIL_OK) return rc;
    struct passwd* pw = getpwuid((uid_t)uids[1]);
    if (!pw) {
        snprintf(out, (size_t)cap, "%llu", uids[1]);
        return PSUTIL_OK;
    }
    psq_copy(out, cap, pw->pw_name);
    return PSUTIL_OK;
}

static int psq_ids(int pid, const char* key, unsigned long long out[3]) {
    char path[256];
    char line[512];
    snprintf(path, sizeof(path), "/proc/%d/status", pid);
    FILE* f = fopen(path, "r");
    if (!f) return psq_errno(errno);
    int found = 0;
    while (fgets(line, sizeof(line), f)) {
        if (strncmp(line, key, strlen(key)) == 0) {
            unsigned long long a = 0, b = 0, c = 0;
            if (sscanf(line + strlen(key), "%llu %llu %llu", &a, &b, &c) >= 3) {
                out[0] = a;
                out[1] = b;
                out[2] = c;
                found = 1;
            }
            break;
        }
    }
    fclose(f);
    return found ? PSUTIL_OK : PSUTIL_NO_PROC;
}

int psutil_proc_uids(int pid, unsigned long long out[3]) {
    int rc = psq_guard(pid);
    if (rc != PSUTIL_OK) return rc;
    return psq_ids(pid, "Uid:", out);
}

int psutil_proc_gids(int pid, unsigned long long out[3]) {
    int rc = psq_guard(pid);
    if (rc != PSUTIL_OK) return rc;
    return psq_ids(pid, "Gid:", out);
}

int psutil_proc_terminal(int pid, char* out, int cap) {
    int rc = psq_guard(pid);
    if (rc != PSUTIL_OK) return rc;
    char* toks[40];
    int n = psq_stat_tokens(pid, toks, 40);
    if (n <= 4) return PSUTIL_NO_PROC;
    unsigned long long nr = strtoull(toks[4], NULL, 10);
    if (nr == 0) {
        out[0] = '\0';
        return PSUTIL_OK;
    }
    unsigned int maj = major((dev_t)nr);
    unsigned int min = minor((dev_t)nr);
    const char* dirs[2] = { "/dev/pts", "/dev" };
    for (int d = 0; d < 2; d++) {
        DIR* dp = opendir(dirs[d]);
        if (!dp) continue;
        struct dirent* e;
        while ((e = readdir(dp)) != NULL) {
            char full[512];
            snprintf(full, sizeof(full), "%s/%s", dirs[d], e->d_name);
            struct stat st;
            if (stat(full, &st) != 0) continue;
            if (!S_ISCHR(st.st_mode)) continue;
            if (major(st.st_rdev) == maj && minor(st.st_rdev) == min) {
                psq_copy(out, cap, full);
                closedir(dp);
                return PSUTIL_OK;
            }
        }
        closedir(dp);
    }
    out[0] = '\0';
    return PSUTIL_OK;
}

int psutil_proc_create_time(int pid, double* out) {
    if (!psutil_os_pid_exists(pid)) return PSUTIL_NO_PROC;
    char* toks[40];
    int n = psq_stat_tokens(pid, toks, 40);
    if (n <= 19) return PSUTIL_NO_PROC;
    *out = psq_btime() + (double)strtoull(toks[19], NULL, 10) / (double)psq_hz();
    return PSUTIL_OK;
}

int psutil_proc_cpu_times(int pid, double* user, double* system,
                          double* cuser, double* csystem, double* iowait) {
    int rc = psq_guard(pid);
    if (rc != PSUTIL_OK) return rc;
    char* toks[40];
    int n = psq_stat_tokens(pid, toks, 40);
    if (n <= 14) return PSUTIL_NO_PROC;
    double hz = (double)psq_hz();
    *user = (double)strtoull(toks[11], NULL, 10) / hz;
    *system = (double)strtoull(toks[12], NULL, 10) / hz;
    *cuser = (double)strtoull(toks[13], NULL, 10) / hz;
    *csystem = (double)strtoull(toks[14], NULL, 10) / hz;
    *iowait = (n > 39) ? (double)strtoull(toks[39], NULL, 10) / hz
                       : PSUTIL_NONE_F64;
    return PSUTIL_OK;
}

int psutil_proc_ctx_switches(int pid, unsigned long long* vol,
                             unsigned long long* invol) {
    int rc = psq_guard(pid);
    if (rc != PSUTIL_OK) return rc;
    rc = psq_key_u64(pid, "status", "voluntary_ctxt_switches", vol);
    if (rc != PSUTIL_OK) return rc;
    return psq_key_u64(pid, "status", "nonvoluntary_ctxt_switches", invol);
}

int psutil_proc_num_threads(int pid) {
    int rc = psq_guard(pid);
    if (rc != PSUTIL_OK) return rc;
    char* toks[40];
    int n = psq_stat_tokens(pid, toks, 40);
    if (n <= 17) return PSUTIL_NO_PROC;
    return (int)strtol(toks[17], NULL, 10);
}

static int psq_fd_count(int pid) {
    char path[256];
    snprintf(path, sizeof(path), "/proc/%d/fd", pid);
    DIR* d = opendir(path);
    if (!d) return -1;
    int n = 0;
    struct dirent* e;
    while ((e = readdir(d)) != NULL) {
        if (e->d_name[0] == '.') continue;
        n++;
    }
    closedir(d);
    return n;
}

int psutil_proc_num_fds(int pid) {
    int rc = psq_guard(pid);
    if (rc != PSUTIL_OK) return rc;
    int n = psq_fd_count(pid);
    return n < 0 ? psq_errno(errno) : n;
}

int psutil_proc_num_handles(int pid) {
    (void)pid;
    return PSUTIL_UNSUPPORTED;
}

int psutil_proc_nice(int pid, int* out) {
    int rc = psq_guard(pid);
    if (rc != PSUTIL_OK) return rc;
    char* toks[40];
    int n = psq_stat_tokens(pid, toks, 40);
    if (n <= 16) return PSUTIL_NO_PROC;
    *out = (int)strtol(toks[16], NULL, 10);
    return PSUTIL_OK;
}

int psutil_proc_set_nice(int pid, int nice) {
    int rc = psq_guard(pid);
    if (rc != PSUTIL_OK) return rc;
    if (setpriority(PRIO_PROCESS, (id_t)pid, nice) != 0) return psq_errno(errno);
    return PSUTIL_OK;
}

int psutil_proc_ionice(int pid, int* cls, int* val) {
    int rc = psq_guard(pid);
    if (rc != PSUTIL_OK) return rc;
    long prio = syscall(SYS_ioprio_get, 1, pid);
    if (prio < 0) return psq_errno(errno);
    int c = (int)((prio >> 13) & 0x7);
    int v = (int)(prio & 0x7fff);
    *cls = c;
    *val = v;
    return PSUTIL_OK;
}

int psutil_proc_set_ionice(int pid, int cls, int val) {
    int rc = psq_guard(pid);
    if (rc != PSUTIL_OK) return rc;
    int prio = (cls << 13) | (val & 0x7fff);
    if (syscall(SYS_ioprio_set, 1, pid, prio) != 0) return psq_errno(errno);
    return PSUTIL_OK;
}

int psutil_proc_affinity(int pid, unsigned long long* mask, int cap,
                         int* count) {
    int rc = psq_guard(pid);
    if (rc != PSUTIL_OK) return rc;
    cpu_set_t set;
    CPU_ZERO(&set);
    if (sched_getaffinity(pid, sizeof(set), &set) != 0) return psq_errno(errno);
    unsigned long long m = 0;
    int n = 0;
    for (int i = 0; i < 64; i++) {
        if (CPU_ISSET(i, &set)) {
            m |= 1ULL << i;
            n++;
        }
    }
    if (cap > 0) mask[0] = m;
    *count = n;
    return PSUTIL_OK;
}

int psutil_proc_set_affinity(int pid, const unsigned long long* mask,
                             int count) {
    int rc = psq_guard(pid);
    if (rc != PSUTIL_OK) return rc;
    cpu_set_t set;
    CPU_ZERO(&set);
    for (int w = 0; w < count; w++) {
        for (int b = 0; b < 64; b++) {
            if ((mask[w] >> b) & 1ULL) {
                int cpu = w * 64 + b;
                if (cpu < CPU_SETSIZE) CPU_SET(cpu, &set);
            }
        }
    }
    if (sched_setaffinity(pid, sizeof(set), &set) != 0) return psq_errno(errno);
    return PSUTIL_OK;
}

int psutil_proc_io(int pid, psutil_IOInfo* out) {
    int rc = psq_guard(pid);
    if (rc != PSUTIL_OK) return rc;
    memset(out, 0, sizeof(*out));
    out->read_chars = PSUTIL_NONE_I64;
    out->write_chars = PSUTIL_NONE_I64;
    char path[256];
    char line[512];
    snprintf(path, sizeof(path), "/proc/%d/io", pid);
    FILE* f = fopen(path, "r");
    if (!f) return psq_errno(errno);
    while (fgets(line, sizeof(line), f)) {
        unsigned long long v = 0;
        if (sscanf(line, "syscr: %llu", &v) == 1) out->read_count = v;
        else if (sscanf(line, "syscw: %llu", &v) == 1) out->write_count = v;
        else if (sscanf(line, "read_bytes: %llu", &v) == 1) out->read_bytes = v;
        else if (sscanf(line, "write_bytes: %llu", &v) == 1) out->write_bytes = v;
        else if (sscanf(line, "rchar: %llu", &v) == 1) out->read_chars = (long long)v;
        else if (sscanf(line, "wchar: %llu", &v) == 1) out->write_chars = (long long)v;
    }
    fclose(f);
    return PSUTIL_OK;
}

int psutil_proc_mem_full(int pid, psutil_MemFullInfo* out) {
    int rc = psq_guard(pid);
    if (rc != PSUTIL_OK) return rc;
    memset(out, 0, sizeof(*out));
    out->text = PSUTIL_NONE_U64;
    out->lib = PSUTIL_NONE_U64;
    out->data = PSUTIL_NONE_U64;
    out->dirty = PSUTIL_NONE_U64;
    out->uss = PSUTIL_NONE_I64;
    out->pss = PSUTIL_NONE_I64;
    out->swap = PSUTIL_NONE_I64;
    unsigned long long v[7] = {0};
    char path[256];
    char line[512];
    snprintf(path, sizeof(path), "/proc/%d/statm", pid);
    FILE* f = fopen(path, "r");
    if (!f) return psq_errno(errno);
    int got = 0;
    if (fgets(line, sizeof(line), f)) {
        got = sscanf(line, "%llu %llu %llu %llu %llu %llu %llu",
                     &v[0], &v[1], &v[2], &v[3], &v[4], &v[5], &v[6]);
    }
    fclose(f);
    if (got < 2) return PSUTIL_NO_PROC;
    long page = sysconf(_SC_PAGESIZE);
    if (page <= 0) page = 4096;
    out->vms = v[0] * (unsigned long long)page;
    out->rss = v[1] * (unsigned long long)page;
    out->shared = got > 2 ? v[2] * (unsigned long long)page : 0;
    out->text = got > 3 ? v[3] * (unsigned long long)page : PSUTIL_NONE_U64;
    out->lib = got > 4 ? v[4] * (unsigned long long)page : PSUTIL_NONE_U64;
    out->data = got > 5 ? v[5] * (unsigned long long)page : PSUTIL_NONE_U64;
    out->dirty = got > 6 ? v[6] * (unsigned long long)page : PSUTIL_NONE_U64;

    // pypi psutil: 优先 smaps_rollup，失败时回退 smaps。
    // uss 累加所有 Private_*（含 Private_Hugetlb），pss/swap 同理。
    snprintf(path, sizeof(path), "/proc/%d/smaps_rollup", pid);
    f = fopen(path, "r");
    if (f) {
        unsigned long long priv = 0;
        while (fgets(line, sizeof(line), f)) {
            unsigned long long x = 0;
            char* colon = NULL;
            if (strncmp(line, "Private_", 8) == 0) {
                colon = strchr(line, ':');
                if (colon && sscanf(colon + 1, "%llu", &x) == 1) priv += x;
            } else if (sscanf(line, "Pss: %llu", &x) == 1) {
                out->pss = (long long)(x * 1024ULL);
            } else if (sscanf(line, "Swap: %llu", &x) == 1) {
                out->swap = (long long)(x * 1024ULL);
            }
        }
        fclose(f);
        out->uss = (long long)(priv * 1024ULL);
    } else {
        snprintf(path, sizeof(path), "/proc/%d/smaps", pid);
        f = fopen(path, "r");
        if (f) {
            unsigned long long priv = 0, pss = 0, sw = 0;
            while (fgets(line, sizeof(line), f)) {
                unsigned long long x = 0;
                char* colon = NULL;
                if (strncmp(line, "Private_", 8) == 0) {
                    colon = strchr(line, ':');
                    if (colon && sscanf(colon + 1, "%llu", &x) == 1) priv += x;
                } else if (sscanf(line, "Pss: %llu", &x) == 1) pss += x;
                else if (sscanf(line, "Swap: %llu", &x) == 1) sw += x;
            }
            fclose(f);
            out->uss = (long long)(priv * 1024ULL);
            out->pss = (long long)(pss * 1024ULL);
            out->swap = (long long)(sw * 1024ULL);
        }
    }
    return PSUTIL_OK;
}

int psutil_proc_ram_total(unsigned long long* out) {
    char line[512];
    FILE* f = fopen("/proc/meminfo", "r");
    if (!f) return PSUTIL_NO_PROC;
    while (fgets(line, sizeof(line), f)) {
        unsigned long long kb = 0;
        if (sscanf(line, "MemTotal: %llu kB", &kb) == 1) {
            fclose(f);
            *out = kb * 1024ULL;
            return PSUTIL_OK;
        }
    }
    fclose(f);
    return PSUTIL_NO_PROC;
}

static void psq_open_file_mode(psutil_OpenFile* item) {
    if (item->flags < 0) return;
    int acc = item->flags & O_ACCMODE;
    char* p = item->mode;
    if (acc == O_RDONLY) *p++ = 'r';
    else if (acc == O_WRONLY) *p++ = 'w';
    else *p++ = 'r', *p++ = '+';
    if (item->flags & O_APPEND) *p++ = 'a';
    *p = '\0';
}

int psutil_proc_open_files(int pid, psutil_OpenFile* out, int cap) {
    int rc = psq_guard(pid);
    if (rc != PSUTIL_OK) return rc;
    char path[256];
    snprintf(path, sizeof(path), "/proc/%d/fd", pid);
    DIR* d = opendir(path);
    if (!d) return psq_errno(errno);
    int n = 0;
    struct dirent* e;
    while ((e = readdir(d)) != NULL && n < cap) {
        if (e->d_name[0] == '.') continue;
        char link[256];
        char buf[4096];
        snprintf(link, sizeof(link), "/proc/%d/fd/%s", pid, e->d_name);
        ssize_t k = readlink(link, buf, sizeof(buf) - 1);
        if (k < 0) continue;
        buf[k] = '\0';
        // pypi psutil 只统计绝对路径且为普通文件的 fd。
        if (buf[0] != '/') continue;
        struct stat st;
        if (stat(buf, &st) != 0 || !S_ISREG(st.st_mode)) continue;
        psutil_OpenFile* item = &out[n++];
        memset(item, 0, sizeof(*item));
        item->fd = atoi(e->d_name);
        item->position = PSUTIL_NONE_I64;
        item->flags = PSUTIL_NONE_INT;
        psq_copy(item->path, (int)sizeof(item->path), buf);
        char info[256];
        char iline[512];
        snprintf(info, sizeof(info), "/proc/%d/fdinfo/%s", pid, e->d_name);
        FILE* f = fopen(info, "r");
        if (f) {
            while (fgets(iline, sizeof(iline), f)) {
                long long pos = 0;
                int flags = 0;
                if (sscanf(iline, "pos: %lld", &pos) == 1) item->position = pos;
                else if (sscanf(iline, "flags: %o", &flags) == 1) item->flags = flags;
            }
            fclose(f);
        }
        psq_open_file_mode(item);
    }
    closedir(d);
    return n;
}

int psutil_proc_memory_maps(int pid, psutil_MapInfo* out, int cap) {
    int rc = psq_guard(pid);
    if (rc != PSUTIL_OK) return rc;
    char path[256];
    char line[1024];
    snprintf(path, sizeof(path), "/proc/%d/smaps", pid);
    FILE* f = fopen(path, "r");
    if (!f) return psq_errno(errno);
    int n = 0;
    psutil_MapInfo cur;
    memset(&cur, 0, sizeof(cur));
    int have = 0;
    while (fgets(line, sizeof(line), f)) {
        unsigned long long start = 0, end = 0, x = 0;
        int used = 0;
        if (sscanf(line, "%llx-%llx %15s %*s %*s %*s %n",
                   &start, &end, cur.perms, &used) >= 3) {
            if (have && n < cap) out[n++] = cur;
            memset(&cur, 0, sizeof(cur));
            have = 1;
            cur.size = end - start;
            cur.pss = PSUTIL_NONE_I64;
            cur.swap = PSUTIL_NONE_I64;
            psq_copy(cur.addr, (int)sizeof(cur.addr), line);
            cur.addr[strcspn(cur.addr, " ")] = '\0';
            const char* p = line + used;
            while (*p == ' ' || *p == '\t') p++;
            psq_copy(cur.path, (int)sizeof(cur.path), p);
            psq_strip_nl(cur.path);
            continue;
        }
        if (!have) continue;
        if (sscanf(line, "Rss: %llu", &x) == 1) cur.rss = x * 1024ULL;
        else if (sscanf(line, "Pss: %llu", &x) == 1) cur.pss = (long long)(x * 1024ULL);
        else if (sscanf(line, "Shared_Clean: %llu", &x) == 1) cur.shared_clean = x * 1024ULL;
        else if (sscanf(line, "Shared_Dirty: %llu", &x) == 1) cur.shared_dirty = x * 1024ULL;
        else if (sscanf(line, "Private_Clean: %llu", &x) == 1) cur.private_clean = x * 1024ULL;
        else if (sscanf(line, "Private_Dirty: %llu", &x) == 1) cur.private_dirty = x * 1024ULL;
        else if (sscanf(line, "Referenced: %llu", &x) == 1) cur.referenced = x * 1024ULL;
        else if (sscanf(line, "Anonymous: %llu", &x) == 1) cur.anonymous = x * 1024ULL;
        else if (sscanf(line, "Swap: %llu", &x) == 1) cur.swap = (long long)(x * 1024ULL);
    }
    if (have && n < cap) out[n++] = cur;
    fclose(f);
    return n;
}

static int psq_inode_fd(int pid, unsigned long long inode) {
    char path[256];
    snprintf(path, sizeof(path), "/proc/%d/fd", pid);
    DIR* d = opendir(path);
    if (!d) return -1;
    int result = -1;
    struct dirent* e;
    char want[64];
    snprintf(want, sizeof(want), "socket:[%llu]", inode);
    while ((e = readdir(d)) != NULL) {
        char link[256];
        char buf[256];
        snprintf(link, sizeof(link), "/proc/%d/fd/%s", pid, e->d_name);
        ssize_t k = readlink(link, buf, sizeof(buf) - 1);
        if (k < 0) continue;
        buf[k] = '\0';
        if (strcmp(buf, want) == 0) {
            result = atoi(e->d_name);
            break;
        }
    }
    closedir(d);
    return result;
}

static void psq_v4(char* out, int cap, const char* hex) {
    unsigned long long v = strtoull(hex, NULL, 16);
    snprintf(out, (size_t)cap, "%u.%u.%u.%u",
             (unsigned)(v & 0xff), (unsigned)((v >> 8) & 0xff),
             (unsigned)((v >> 16) & 0xff), (unsigned)((v >> 24) & 0xff));
}

static void psq_v6(char* out, int cap, const char* hex) {
    int pos = 0;
    for (int w = 0; w < 4 && strlen(hex) >= (size_t)(w * 8 + 8); w++) {
        unsigned long v = strtoul(hex + w * 8, NULL, 16);
        unsigned int b[4] = {
            (unsigned int)(v & 0xff),
            (unsigned int)((v >> 8) & 0xff),
            (unsigned int)((v >> 16) & 0xff),
            (unsigned int)((v >> 24) & 0xff)
        };
        for (int g = 0; g < 2 && pos < cap - 6; g++) {
            unsigned int x = b[g * 2] | (b[g * 2 + 1] << 8);
            pos += snprintf(out + pos, (size_t)(cap - pos), "%s%x",
                            pos ? ":" : "", x);
        }
    }
    if (pos == 0) out[0] = '\0';
}

static const char* psq_state_name(unsigned int st) {
    switch (st) {
        case 0x01: return "ESTABLISHED";
        case 0x02: return "SYN_SENT";
        case 0x03: return "SYN_RECV";
        case 0x04: return "FIN_WAIT1";
        case 0x05: return "FIN_WAIT2";
        case 0x06: return "TIME_WAIT";
        case 0x07: return "CLOSE";
        case 0x08: return "CLOSE_WAIT";
        case 0x09: return "LAST_ACK";
        case 0x0A: return "LISTEN";
        case 0x0B: return "CLOSING";
        default: return "NONE";
    }
}

int psutil_proc_connections(int pid, psutil_ConnInfo* out, int cap,
                            int want_unix) {
    int rc = psq_guard(pid);
    if (rc != PSUTIL_OK) return rc;
    int n = 0;
    char line[1024];
    if (want_unix) {
        FILE* f = fopen("/proc/net/unix", "r");
        if (!f) return PSUTIL_NO_PROC;
        while (fgets(line, sizeof(line), f) && n < cap) {
            char* toks[16];
            int cnt = 0;
            char* save = NULL;
            char* tok = strtok_r(line, " \t\n", &save);
            while (tok && cnt < 16) {
                toks[cnt++] = tok;
                tok = strtok_r(NULL, " \t\n", &save);
            }
            if (cnt < 8) continue;
            unsigned long long inode = strtoull(toks[6], NULL, 10);
            int fd = psq_inode_fd(pid, inode);
            if (fd < 0) continue;
            psutil_ConnInfo* it = &out[n++];
            memset(it, 0, sizeof(*it));
            it->fd = fd;
            it->family = 1;
            it->typ = (strcmp(toks[4], "0001") == 0 || strcmp(toks[4], "01") == 0) ? 1 : 2;
            if (cnt > 8) psq_copy(it->laddr_ip, (int)sizeof(it->laddr_ip), toks[8]);
            psq_copy(it->status, (int)sizeof(it->status), "NONE");
        }
        fclose(f);
        return n;
    }
    const char* tables[4] = { "/proc/net/tcp", "/proc/net/tcp6",
                              "/proc/net/udp", "/proc/net/udp6" };
    for (int t = 0; t < 4 && n < cap; t++) {
        FILE* f = fopen(tables[t], "r");
        if (!f) continue;
        int is_v6 = (t == 1 || t == 3);
        int is_udp = (t >= 2);
        int line_no = 0;
        while (fgets(line, sizeof(line), f) && n < cap) {
            if (line_no++ == 0) continue;
            char local[80], rem[80];
            unsigned int st = 0;
            unsigned long long inode = 0;
            if (sscanf(line, "%*d: %79s %79s %x %*s %*s %*s %*s %*s %llu",
                       local, rem, &st, &inode) != 4) continue;
            int fd = psq_inode_fd(pid, inode);
            if (fd < 0) continue;
            psutil_ConnInfo* it = &out[n++];
            memset(it, 0, sizeof(*it));
            it->fd = fd;
            it->family = is_v6 ? 10 : 2;
            it->typ = is_udp ? 2 : 1;
            char* colon = strrchr(local, ':');
            if (colon) {
                *colon = '\0';
                it->laddr_port = (int)strtoul(colon + 1, NULL, 16);
                if (is_v6) psq_v6(it->laddr_ip, (int)sizeof(it->laddr_ip), local);
                else psq_v4(it->laddr_ip, (int)sizeof(it->laddr_ip), local);
            }
            colon = strrchr(rem, ':');
            if (colon) {
                *colon = '\0';
                it->raddr_port = (int)strtoul(colon + 1, NULL, 16);
                if (is_v6) psq_v6(it->raddr_ip, (int)sizeof(it->raddr_ip), rem);
                else psq_v4(it->raddr_ip, (int)sizeof(it->raddr_ip), rem);
            }
            psq_copy(it->status, (int)sizeof(it->status),
                     is_udp ? "NONE" : psq_state_name(st));
        }
        fclose(f);
    }
    return n;
}

int psutil_proc_signal(int pid, int sig) {
    int rc = psq_guard(pid);
    if (rc != PSUTIL_OK) return rc;
    if (kill(pid, sig) != 0) return psq_errno(errno);
    return PSUTIL_OK;
}

int psutil_proc_suspend(int pid) { return psutil_proc_signal(pid, SIGSTOP); }
int psutil_proc_resume(int pid) { return psutil_proc_signal(pid, SIGCONT); }

#elif defined(__APPLE__)

#include <libproc.h>
#include <pwd.h>
#include <sys/sysctl.h>
#include <unistd.h>

int psutil_proc_exe(int pid, char* out, int cap) {
    if (!psutil_os_pid_exists(pid)) return PSUTIL_NO_PROC;
    if (proc_pidpath(pid, out, (uint32_t)cap) <= 0) return PSUTIL_ACCESS_DENIED;
    return PSUTIL_OK;
}

int psutil_proc_cwd(int pid, char* out, int cap) {
    if (!psutil_os_pid_exists(pid)) return PSUTIL_NO_PROC;
    struct proc_vnodepathinfo vpi;
    memset(&vpi, 0, sizeof(vpi));
    int ret = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &vpi, sizeof(vpi));
    if (ret != (int)sizeof(vpi)) return PSUTIL_ACCESS_DENIED;
    psq_copy(out, cap, vpi.pvi_cdir.vip_path);
    return PSUTIL_OK;
}

int psutil_proc_status(int pid, char* out, int cap) {
    struct proc_bsdinfo info;
    memset(&info, 0, sizeof(info));
    if (proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, sizeof(info)) !=
        (int)sizeof(info)) return PSUTIL_NO_PROC;
    const char* s = "?";
    switch (info.pbi_status) {
        case SIDL: s = "I"; break;
        case SRUN: s = "R"; break;
        case SSLEEP: s = "S"; break;
        case SSTOP: s = "T"; break;
        case SZOMB: s = "Z"; break;
        default: break;
    }
    psq_copy(out, cap, s);
    return PSUTIL_OK;
}

int psutil_proc_uids(int pid, unsigned long long out[3]) {
    struct proc_bsdinfo info;
    memset(&info, 0, sizeof(info));
    if (proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, sizeof(info)) !=
        (int)sizeof(info)) return PSUTIL_NO_PROC;
    out[0] = out[1] = out[2] = (unsigned long long)info.pbi_uid;
    return PSUTIL_OK;
}

int psutil_proc_gids(int pid, unsigned long long out[3]) {
    struct proc_bsdinfo info;
    memset(&info, 0, sizeof(info));
    if (proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, sizeof(info)) !=
        (int)sizeof(info)) return PSUTIL_NO_PROC;
    out[0] = out[1] = out[2] = (unsigned long long)info.pbi_gid;
    return PSUTIL_OK;
}

int psutil_proc_username(int pid, char* out, int cap) {
    unsigned long long u[3];
    int rc = psutil_proc_uids(pid, u);
    if (rc != PSUTIL_OK) return rc;
    struct passwd* pw = getpwuid((uid_t)u[1]);
    if (!pw) return PSUTIL_NO_PROC;
    psq_copy(out, cap, pw->pw_name);
    return PSUTIL_OK;
}

int psutil_proc_create_time(int pid, double* out) {
    struct proc_bsdinfo info;
    memset(&info, 0, sizeof(info));
    if (proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, sizeof(info)) !=
        (int)sizeof(info)) return PSUTIL_NO_PROC;
    *out = (double)info.pbi_starttv.tv_sec +
           (double)info.pbi_starttv.tv_usec / 1000000.0;
    return PSUTIL_OK;
}

int psutil_proc_ram_total(unsigned long long* out) {
    uint64_t mem = 0;
    size_t len = sizeof(mem);
    if (sysctlbyname("hw.memsize", &mem, &len, NULL, 0) != 0) return PSUTIL_NO_PROC;
    *out = (unsigned long long)mem;
    return PSUTIL_OK;
}

int psutil_proc_signal(int pid, int sig) {
    if (!psutil_os_pid_exists(pid)) return PSUTIL_NO_PROC;
    if (kill(pid, sig) != 0) return psq_errno(errno);
    return PSUTIL_OK;
}

int psutil_proc_suspend(int pid) { return psutil_proc_signal(pid, SIGSTOP); }
int psutil_proc_resume(int pid) { return psutil_proc_signal(pid, SIGCONT); }

static int psq_osx_unsupported(void) { return PSUTIL_UNSUPPORTED; }

int psutil_proc_terminal(int pid, char* o, int c) { (void)pid;(void)o;(void)c; return psq_osx_unsupported(); }
int psutil_proc_cpu_times(int pid, double* a, double* b, double* c, double* d, double* e) { (void)pid;(void)a;(void)b;(void)c;(void)d;(void)e; return psq_osx_unsupported(); }
int psutil_proc_ctx_switches(int pid, unsigned long long* a, unsigned long long* b) { (void)pid;(void)a;(void)b; return psq_osx_unsupported(); }
int psutil_proc_num_threads(int pid) { (void)pid; return PSUTIL_UNSUPPORTED; }
int psutil_proc_num_fds(int pid) { (void)pid; return PSUTIL_UNSUPPORTED; }
int psutil_proc_num_handles(int pid) { (void)pid; return PSUTIL_UNSUPPORTED; }
int psutil_proc_nice(int pid, int* o) { (void)pid;(void)o; return psq_osx_unsupported(); }
int psutil_proc_set_nice(int pid, int v) { (void)pid;(void)v; return psq_osx_unsupported(); }
int psutil_proc_ionice(int pid, int* c, int* v) { (void)pid;(void)c;(void)v; return psq_osx_unsupported(); }
int psutil_proc_set_ionice(int pid, int c, int v) { (void)pid;(void)c;(void)v; return psq_osx_unsupported(); }
int psutil_proc_affinity(int pid, unsigned long long* m, int c, int* n) { (void)pid;(void)m;(void)c;(void)n; return psq_osx_unsupported(); }
int psutil_proc_set_affinity(int pid, const unsigned long long* m, int n) { (void)pid;(void)m;(void)n; return psq_osx_unsupported(); }
int psutil_proc_io(int pid, psutil_IOInfo* o) { (void)pid;(void)o; return psq_osx_unsupported(); }
int psutil_proc_mem_full(int pid, psutil_MemFullInfo* o) { (void)pid;(void)o; return psq_osx_unsupported(); }
int psutil_proc_open_files(int pid, psutil_OpenFile* o, int c) { (void)pid;(void)o;(void)c; return psq_osx_unsupported(); }
int psutil_proc_memory_maps(int pid, psutil_MapInfo* o, int c) { (void)pid;(void)o;(void)c; return psq_osx_unsupported(); }
int psutil_proc_connections(int pid, psutil_ConnInfo* o, int c, int u) { (void)pid;(void)o;(void)c;(void)u; return psq_osx_unsupported(); }

#elif defined(_WIN32)

#include <psapi.h>
#include <tlhelp32.h>
#include <windows.h>

static int psq_win_pid(int pid) {
    HANDLE h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, (DWORD)pid);
    if (!h) return GetLastError() == ERROR_INVALID_PARAMETER ? PSUTIL_NO_PROC
                                                             : PSUTIL_ACCESS_DENIED;
    CloseHandle(h);
    return PSUTIL_OK;
}

int psutil_proc_exe(int pid, char* out, int cap) {
    int rc = psq_win_pid(pid);
    if (rc != PSUTIL_OK) return rc;
    HANDLE h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, (DWORD)pid);
    if (!h) return PSUTIL_ACCESS_DENIED;
    DWORD n = (DWORD)cap;
    if (!QueryFullProcessImagePathA(h, 0, out, &n)) {
        CloseHandle(h);
        return PSUTIL_ACCESS_DENIED;
    }
    CloseHandle(h);
    return PSUTIL_OK;
}

int psutil_proc_create_time(int pid, double* out) {
    int rc = psq_win_pid(pid);
    if (rc != PSUTIL_OK) return rc;
    HANDLE h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, (DWORD)pid);
    if (!h) return PSUTIL_ACCESS_DENIED;
    FILETIME c, e, k, u;
    if (!GetProcessTimes(h, &c, &e, &k, &u)) {
        CloseHandle(h);
        return PSUTIL_ACCESS_DENIED;
    }
    CloseHandle(h);
    ULARGE_INTEGER v;
    v.LowPart = c.dwLowDateTime;
    v.HighPart = c.dwHighDateTime;
    *out = (double)v.QuadPart / 10000000.0 - 11644473600.0;
    return PSUTIL_OK;
}

int psutil_proc_cpu_times(int pid, double* user, double* system,
                          double* cuser, double* csystem, double* iowait) {
    int rc = psq_win_pid(pid);
    if (rc != PSUTIL_OK) return rc;
    HANDLE h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, (DWORD)pid);
    if (!h) return PSUTIL_ACCESS_DENIED;
    FILETIME c, e, k, u;
    if (!GetProcessTimes(h, &c, &e, &k, &u)) {
        CloseHandle(h);
        return PSUTIL_ACCESS_DENIED;
    }
    CloseHandle(h);
    ULARGE_INTEGER ku, kk;
    ku.LowPart = u.dwLowDateTime;
    ku.HighPart = u.dwHighDateTime;
    kk.LowPart = k.dwLowDateTime;
    kk.HighPart = k.dwHighDateTime;
    *user = (double)ku.QuadPart / 10000000.0;
    *system = (double)kk.QuadPart / 10000000.0;
    *cuser = 0.0;
    *csystem = 0.0;
    *iowait = PSUTIL_NONE_F64;
    return PSUTIL_OK;
}

int psutil_proc_num_threads(int pid) {
    int rc = psq_win_pid(pid);
    if (rc != PSUTIL_OK) return rc;
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
    if (snap == INVALID_HANDLE_VALUE) return PSUTIL_ACCESS_DENIED;
    THREADENTRY32 te;
    te.dwSize = sizeof(te);
    int n = 0;
    BOOL ok = Thread32First(snap, &te);
    while (ok) {
        if ((int)te.th32OwnerProcessID == pid) n++;
        ok = Thread32Next(snap, &te);
    }
    CloseHandle(snap);
    return n;
}

int psutil_proc_num_handles(int pid) {
    int rc = psq_win_pid(pid);
    if (rc != PSUTIL_OK) return rc;
    HANDLE h = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, (DWORD)pid);
    if (!h) return PSUTIL_ACCESS_DENIED;
    DWORD n = 0;
    if (!GetProcessHandleCount(h, &n)) {
        CloseHandle(h);
        return PSUTIL_ACCESS_DENIED;
    }
    CloseHandle(h);
    return (int)n;
}

int psutil_proc_io(int pid, psutil_IOInfo* out) {
    int rc = psq_win_pid(pid);
    if (rc != PSUTIL_OK) return rc;
    HANDLE h = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, (DWORD)pid);
    if (!h) return PSUTIL_ACCESS_DENIED;
    IO_COUNTERS io;
    if (!GetProcessIoCounters(h, &io)) {
        CloseHandle(h);
        return PSUTIL_ACCESS_DENIED;
    }
    CloseHandle(h);
    memset(out, 0, sizeof(*out));
    out->read_count = (unsigned long long)io.ReadOperationCount;
    out->write_count = (unsigned long long)io.WriteOperationCount;
    out->read_bytes = (unsigned long long)io.ReadTransferCount;
    out->write_bytes = (unsigned long long)io.WriteTransferCount;
    out->read_chars = PSUTIL_NONE_I64;
    out->write_chars = PSUTIL_NONE_I64;
    return PSUTIL_OK;
}

int psutil_proc_ram_total(unsigned long long* out) {
    MEMORYSTATUSEX st;
    st.dwLength = sizeof(st);
    if (!GlobalMemoryStatusEx(&st)) return PSUTIL_NO_PROC;
    *out = (unsigned long long)st.ullTotalPhys;
    return PSUTIL_OK;
}

int psutil_proc_affinity(int pid, unsigned long long* mask, int cap,
                         int* count) {
    int rc = psq_win_pid(pid);
    if (rc != PSUTIL_OK) return rc;
    HANDLE h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, (DWORD)pid);
    if (!h) return PSUTIL_ACCESS_DENIED;
    DWORD_PTR sys = 0, proc_mask = 0;
    if (!GetProcessAffinityMask(h, &proc_mask, &sys)) {
        CloseHandle(h);
        return PSUTIL_ACCESS_DENIED;
    }
    CloseHandle(h);
    if (cap > 0) mask[0] = (unsigned long long)proc_mask;
    int n = 0;
    for (int i = 0; i < 64; i++) if (((unsigned long long)proc_mask >> i) & 1ULL) n++;
    *count = n;
    return PSUTIL_OK;
}

int psutil_proc_set_affinity(int pid, const unsigned long long* mask, int count) {
    int rc = psq_win_pid(pid);
    if (rc != PSUTIL_OK) return rc;
    if (count < 1) return PSUTIL_NO_PROC;
    HANDLE h = OpenProcess(PROCESS_SET_INFORMATION, FALSE, (DWORD)pid);
    if (!h) return PSUTIL_ACCESS_DENIED;
    if (!SetProcessAffinityMask(h, (DWORD_PTR)mask[0])) {
        CloseHandle(h);
        return PSUTIL_ACCESS_DENIED;
    }
    CloseHandle(h);
    return PSUTIL_OK;
}

int psutil_proc_signal(int pid, int sig) {
    int rc = psq_win_pid(pid);
    if (rc != PSUTIL_OK) return rc;
    if (sig != 15 && sig != 9) return PSUTIL_UNSUPPORTED;
    HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, (DWORD)pid);
    if (!h) return PSUTIL_ACCESS_DENIED;
    if (!TerminateProcess(h, 1)) {
        CloseHandle(h);
        return PSUTIL_ACCESS_DENIED;
    }
    CloseHandle(h);
    return PSUTIL_OK;
}

static int psq_win_unsupported(void) { return PSUTIL_UNSUPPORTED; }

int psutil_proc_cwd(int pid, char* o, int c) { (void)pid;(void)o;(void)c; return psq_win_unsupported(); }
int psutil_proc_status(int pid, char* o, int c) { (void)pid;(void)o;(void)c; return psq_win_unsupported(); }
int psutil_proc_username(int pid, char* o, int c) { (void)pid;(void)o;(void)c; return psq_win_unsupported(); }
int psutil_proc_uids(int pid, unsigned long long o[3]) { (void)pid;(void)o; return psq_win_unsupported(); }
int psutil_proc_gids(int pid, unsigned long long o[3]) { (void)pid;(void)o; return psq_win_unsupported(); }
int psutil_proc_terminal(int pid, char* o, int c) { (void)pid;(void)o;(void)c; return psq_win_unsupported(); }
int psutil_proc_ctx_switches(int pid, unsigned long long* a, unsigned long long* b) { (void)pid;(void)a;(void)b; return psq_win_unsupported(); }
int psutil_proc_num_fds(int pid) { (void)pid; return PSUTIL_UNSUPPORTED; }
int psutil_proc_nice(int pid, int* o) { (void)pid;(void)o; return psq_win_unsupported(); }
int psutil_proc_set_nice(int pid, int v) { (void)pid;(void)v; return psq_win_unsupported(); }
int psutil_proc_ionice(int pid, int* c, int* v) { (void)pid;(void)c;(void)v; return psq_win_unsupported(); }
int psutil_proc_set_ionice(int pid, int c, int v) { (void)pid;(void)c;(void)v; return psq_win_unsupported(); }
int psutil_proc_mem_full(int pid, psutil_MemFullInfo* o) { (void)pid;(void)o; return psq_win_unsupported(); }
int psutil_proc_open_files(int pid, psutil_OpenFile* o, int c) { (void)pid;(void)o;(void)c; return psq_win_unsupported(); }
int psutil_proc_memory_maps(int pid, psutil_MapInfo* o, int c) { (void)pid;(void)o;(void)c; return psq_win_unsupported(); }
int psutil_proc_connections(int pid, psutil_ConnInfo* o, int c, int u) { (void)pid;(void)o;(void)c;(void)u; return psq_win_unsupported(); }
int psutil_proc_suspend(int pid) { (void)pid; return PSUTIL_UNSUPPORTED; }
int psutil_proc_resume(int pid) { (void)pid; return PSUTIL_UNSUPPORTED; }

#else

static int psq_ni(void) { return PSUTIL_UNSUPPORTED; }

int psutil_proc_exe(int p, char* o, int c) { (void)p;(void)o;(void)c; return psq_ni(); }
int psutil_proc_cwd(int p, char* o, int c) { (void)p;(void)o;(void)c; return psq_ni(); }
int psutil_proc_status(int p, char* o, int c) { (void)p;(void)o;(void)c; return psq_ni(); }
int psutil_proc_username(int p, char* o, int c) { (void)p;(void)o;(void)c; return psq_ni(); }
int psutil_proc_uids(int p, unsigned long long o[3]) { (void)p;(void)o; return psq_ni(); }
int psutil_proc_gids(int p, unsigned long long o[3]) { (void)p;(void)o; return psq_ni(); }
int psutil_proc_terminal(int p, char* o, int c) { (void)p;(void)o;(void)c; return psq_ni(); }
int psutil_proc_create_time(int p, double* o) { (void)p;(void)o; return psq_ni(); }
int psutil_proc_cpu_times(int p, double* a, double* b, double* c, double* d, double* e) { (void)p;(void)a;(void)b;(void)c;(void)d;(void)e; return psq_ni(); }
int psutil_proc_ctx_switches(int p, unsigned long long* a, unsigned long long* b) { (void)p;(void)a;(void)b; return psq_ni(); }
int psutil_proc_num_threads(int p) { (void)p; return PSUTIL_UNSUPPORTED; }
int psutil_proc_num_fds(int p) { (void)p; return PSUTIL_UNSUPPORTED; }
int psutil_proc_num_handles(int p) { (void)p; return PSUTIL_UNSUPPORTED; }
int psutil_proc_nice(int p, int* o) { (void)p;(void)o; return psq_ni(); }
int psutil_proc_set_nice(int p, int v) { (void)p;(void)v; return psq_ni(); }
int psutil_proc_ionice(int p, int* c, int* v) { (void)p;(void)c;(void)v; return psq_ni(); }
int psutil_proc_set_ionice(int p, int c, int v) { (void)p;(void)c;(void)v; return psq_ni(); }
int psutil_proc_affinity(int p, unsigned long long* m, int c, int* n) { (void)p;(void)m;(void)c;(void)n; return psq_ni(); }
int psutil_proc_set_affinity(int p, const unsigned long long* m, int n) { (void)p;(void)m;(void)n; return psq_ni(); }
int psutil_proc_io(int p, psutil_IOInfo* o) { (void)p;(void)o; return psq_ni(); }
int psutil_proc_mem_full(int p, psutil_MemFullInfo* o) { (void)p;(void)o; return psq_ni(); }
int psutil_proc_ram_total(unsigned long long* o) { (void)o; return PSUTIL_UNSUPPORTED; }
int psutil_proc_open_files(int p, psutil_OpenFile* o, int c) { (void)p;(void)o;(void)c; return psq_ni(); }
int psutil_proc_memory_maps(int p, psutil_MapInfo* o, int c) { (void)p;(void)o;(void)c; return psq_ni(); }
int psutil_proc_connections(int p, psutil_ConnInfo* o, int c, int u) { (void)p;(void)o;(void)c;(void)u; return psq_ni(); }
int psutil_proc_signal(int p, int s) { (void)p;(void)s; return psq_ni(); }
int psutil_proc_suspend(int p) { (void)p; return PSUTIL_UNSUPPORTED; }
int psutil_proc_resume(int p) { (void)p; return PSUTIL_UNSUPPORTED; }

#endif

int psutil_signal_term(void) {
#ifdef _WIN32
    return 15;
#else
    return SIGTERM;
#endif
}

int psutil_signal_kill(void) {
#ifdef _WIN32
    return 9;
#else
    return SIGKILL;
#endif
}

int psutil_signal_stop(void) {
#ifdef _WIN32
    return -1;
#else
    return SIGSTOP;
#endif
}

int psutil_signal_cont(void) {
#ifdef _WIN32
    return -1;
#else
    return SIGCONT;
#endif
}
