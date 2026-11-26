#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <ctype.h>
#include <errno.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <time.h>

#if defined(__linux__)
#include <dirent.h>
#elif defined(__APPLE__)
#include <sys/sysctl.h>
#endif

#include "psproc_query.h"
#include "sysinfo.h"

static void psys_copy(char* dst, int cap, const char* src) {
    if (!src || cap <= 0) return;
    int n = (int)strlen(src);
    if (n >= cap) n = cap - 1;
    memcpy(dst, src, (size_t)n);
    dst[n] = '\0';
}

static double psys_usage_percent(unsigned long long used,
                                 unsigned long long total) {
    if (total == 0) return 0.0;
    double value = 100.0 * (double)used / (double)total;
    return floor(value * 10.0 + 0.5) / 10.0;
}

static double psys_round1(double value) {
    if (value > 100.0) value = 100.0;
    if (value < 0.0) value = 0.0;
    return floor(value * 10.0 + 0.5) / 10.0;
}

static double psys_cpu_total_d(const psutil_SysCpuTimes* t) {
    double total = t->user + t->nice + t->system + t->idle + t->iowait +
                   t->irq + t->softirq + t->steal + t->guest +
                   t->guest_nice;
    total -= t->guest;
    total -= t->guest_nice;
    return total;
}

static double psys_cpu_busy(const psutil_SysCpuTimes* t) {
    return psys_cpu_total_d(t) - t->idle - t->iowait;
}

static double psys_field(const psutil_SysCpuTimes* t, int idx) {
    switch (idx) {
        case 0: return t->user;
        case 1: return t->nice;
        case 2: return t->system;
        case 3: return t->idle;
        case 4: return t->iowait;
        case 5: return t->irq;
        case 6: return t->softirq;
        case 7: return t->steal;
        case 8: return t->guest;
        case 9: return t->guest_nice;
        default: return 0.0;
    }
}

static void psys_set_field(psutil_CpuTimesPercent* t, int idx, double v) {
    switch (idx) {
        case 0: t->user = v; break;
        case 1: t->nice = v; break;
        case 2: t->system = v; break;
        case 3: t->idle = v; break;
        case 4: t->iowait = v; break;
        case 5: t->irq = v; break;
        case 6: t->softirq = v; break;
        case 7: t->steal = v; break;
        case 8: t->guest = v; break;
        case 9: t->guest_nice = v; break;
        default: break;
    }
}

typedef struct {
    int count;
    psutil_SysCpuTimes values[PSUTIL_MAX_CPUS];
} psys_cpu_cache;

static psys_cpu_cache psys_cache_percent;
static psys_cpu_cache psys_cache_times_percent;

static int psys_cache_seed(psys_cpu_cache* cache,
                           const psutil_SysCpuTimes* cur, int count) {
    if (cur == NULL || count <= 0 || count > PSUTIL_MAX_CPUS) {
        return PSUTIL_UNSUPPORTED;
    }
    cache->count = count;
    for (int i = 0; i < count; i++) cache->values[i] = cur[i];
    return PSUTIL_OK;
}

static void psys_zero_percent(double* out, int count) {
    for (int i = 0; i < count; i++) out[i] = 0.0;
}

static void psys_zero_times_percent(psutil_CpuTimesPercent* out, int count) {
    for (int i = 0; i < count; i++) {
        memset(&out[i], 0, sizeof(out[i]));
    }
}

static int psys_calc_percent(const psutil_SysCpuTimes* cur, int count,
                             psys_cpu_cache* cache, double* out) {
    if (cur == NULL || out == NULL || count <= 0 ||
        count > PSUTIL_MAX_CPUS) {
        return PSUTIL_UNSUPPORTED;
    }
    if (cache->count != count) {
        psys_cache_seed(cache, cur, count);
        psys_zero_percent(out, count);
        return PSUTIL_OK;
    }
    for (int i = 0; i < count; i++) {
        double total_delta = psys_cpu_total_d(&cur[i]) -
                             psys_cpu_total_d(&cache->values[i]);
        if (total_delta <= 0.0) {
            out[i] = 0.0;
        } else {
            double busy_delta = psys_cpu_busy(&cur[i]) -
                                psys_cpu_busy(&cache->values[i]);
            if (busy_delta < 0.0) busy_delta = 0.0;
            double value = 100.0 * busy_delta / total_delta;
            out[i] = psys_round1(value);
        }
        cache->values[i] = cur[i];
    }
    return PSUTIL_OK;
}

static int psys_calc_times_percent(const psutil_SysCpuTimes* cur, int count,
                                   psys_cpu_cache* cache,
                                   psutil_CpuTimesPercent* out) {
    if (cur == NULL || out == NULL || count <= 0 ||
        count > PSUTIL_MAX_CPUS) {
        return PSUTIL_UNSUPPORTED;
    }
    if (cache->count != count) {
        psys_cache_seed(cache, cur, count);
        psys_zero_times_percent(out, count);
        return PSUTIL_OK;
    }
    for (int i = 0; i < count; i++) {
        double total_delta = psys_cpu_total_d(&cur[i]) -
                             psys_cpu_total_d(&cache->values[i]);
        double scale = 100.0 / (total_delta > 1.0 ? total_delta : 1.0);
        for (int field = 0; field < 10; field++) {
            double delta = psys_field(&cur[i], field) -
                           psys_field(&cache->values[i], field);
            if (delta < 0.0) delta = 0.0;
            psys_set_field(&out[i], field, psys_round1(delta * scale));
        }
        cache->values[i] = cur[i];
    }
    return PSUTIL_OK;
}

#if defined(__linux__)

#include <dirent.h>
#include <glob.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <netinet/in.h>
#include <netpacket/packet.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <sys/types.h>
#include <unistd.h>
#include <utmp.h>
#include <arpa/inet.h>

static long psys_clk_ticks(void) {
    long ticks = sysconf(_SC_CLK_TCK);
    return ticks > 0 ? ticks : 100;
}

static long psys_page_size(void) {
    long size = sysconf(_SC_PAGESIZE);
    return size > 0 ? size : 4096;
}

static int psys_is_cpu_label(const char* label) {
    if (strncmp(label, "cpu", 3) != 0) return 0;
    return label[3] == ' ' || label[3] == '\t' || isdigit((unsigned char)label[3]);
}

int psutil_sys_cpu_times(psutil_SysCpuTimes* out, int cap, int percpu) {
    if (out == NULL || cap <= 0) return PSUTIL_UNSUPPORTED;
    FILE* f = fopen("/proc/stat", "r");
    if (!f) return PSUTIL_UNSUPPORTED;
    char line[4096];
    long ticks = psys_clk_ticks();
    int n = 0;
    while (fgets(line, sizeof(line), f)) {
        if (!psys_is_cpu_label(line)) continue;
        char* save = NULL;
        char* label = strtok_r(line, " \t\n", &save);
        if (!label) continue;
        if (!percpu && strcmp(label, "cpu") != 0) continue;
        if (percpu && strcmp(label, "cpu") == 0) continue;
        if (strcmp(label, "cpu") != 0 && !isdigit((unsigned char)label[3])) continue;
        psutil_SysCpuTimes* cur = &out[n];
        memset(cur, 0, sizeof(*cur));
        double* fields[10] = {
            &cur->user, &cur->nice, &cur->system, &cur->idle, &cur->iowait,
            &cur->irq, &cur->softirq, &cur->steal, &cur->guest,
            &cur->guest_nice
        };
        for (int i = 0; i < 10; i++) {
            char* tok = strtok_r(NULL, " \t\n", &save);
            if (!tok) break;
            *fields[i] = strtod(tok, NULL) / (double)ticks;
        }
        n++;
        if (!percpu || n >= cap) break;
    }
    fclose(f);
    return n > 0 ? n : PSUTIL_UNSUPPORTED;
}

int psutil_sys_cpu_percent_seed(const psutil_SysCpuTimes* cur, int count) {
    return psys_cache_seed(&psys_cache_percent, cur, count);
}

int psutil_sys_cpu_percent(const psutil_SysCpuTimes* cur, int count,
                           double* out) {
    return psys_calc_percent(cur, count, &psys_cache_percent, out);
}

int psutil_sys_cpu_times_percent_seed(const psutil_SysCpuTimes* cur,
                                      int count) {
    return psys_cache_seed(&psys_cache_times_percent, cur, count);
}

int psutil_sys_cpu_times_percent(const psutil_SysCpuTimes* cur, int count,
                                 psutil_CpuTimesPercent* out) {
    return psys_calc_times_percent(cur, count, &psys_cache_times_percent, out);
}

static int psys_count_unique_strings(char values[][128], int count) {
    int unique = 0;
    for (int i = 0; i < count; i++) {
        if (values[i][0] == '\0') continue;
        int seen = 0;
        for (int j = 0; j < i; j++) {
            if (strcmp(values[i], values[j]) == 0) {
                seen = 1;
                break;
            }
        }
        if (!seen) unique++;
    }
    return unique;
}

static int psys_cpu_count_logical(void) {
    long logical = sysconf(_SC_NPROCESSORS_ONLN);
    if (logical > 0) return (int)logical;
    int n = 0;
    FILE* f = fopen("/proc/stat", "r");
    if (f) {
        char line[256];
        while (fgets(line, sizeof(line), f)) {
            char label[64];
            if (sscanf(line, "%63s", label) != 1) continue;
            if (strncmp(label, "cpu", 3) == 0 &&
                isdigit((unsigned char)label[3])) {
                n++;
            }
        }
        fclose(f);
    }
    return n > 0 ? n : PSUTIL_UNSUPPORTED;
}

static int psys_cpu_count_cores(void) {
    char values[PSUTIL_MAX_CPUS][128];
    int count = 0;
    glob_t g;
    memset(&g, 0, sizeof(g));
    int rc = glob("/sys/devices/system/cpu/cpu[0-9]*/topology/core_cpus_list",
                  0, NULL, &g);
    if (rc != 0) {
        rc = glob("/sys/devices/system/cpu/cpu[0-9]*/topology/thread_siblings_list",
                  0, NULL, &g);
    }
    if (rc == 0) {
        for (size_t i = 0; i < g.gl_pathc && count < PSUTIL_MAX_CPUS; i++) {
            FILE* f = fopen(g.gl_pathv[i], "r");
            if (!f) continue;
            char buf[128] = {0};
            if (fgets(buf, sizeof(buf), f)) {
                char* p = buf + strlen(buf);
                while (p > buf && (p[-1] == '\n' || p[-1] == '\r')) *--p = '\0';
                psys_copy(values[count], sizeof(values[count]), buf);
                count++;
            }
            fclose(f);
        }
        globfree(&g);
    }
    int unique = psys_count_unique_strings(values, count);
    if (unique > 0) return unique;

    FILE* f = fopen("/proc/cpuinfo", "r");
    if (!f) return PSUTIL_UNSUPPORTED;
    int physical[PSUTIL_MAX_CPUS];
    int cores[PSUTIL_MAX_CPUS];
    int pairs = 0;
    int cur_physical = -1;
    int cur_cores = -1;
    char line[512];
    while (fgets(line, sizeof(line), f)) {
        if (line[0] == '\n' || line[0] == '\r') {
            if (cur_physical >= 0 && cur_cores >= 0 && pairs < PSUTIL_MAX_CPUS) {
                physical[pairs] = cur_physical;
                cores[pairs] = cur_cores;
                pairs++;
            }
            cur_physical = -1;
            cur_cores = -1;
            continue;
        }
        char* colon = strchr(line, ':');
        if (!colon) continue;
        *colon = '\0';
        char* key = line;
        while (*key == ' ' || *key == '\t') key++;
        char* value = colon + 1;
        while (*value == ' ' || *value == '\t') value++;
        if (strcasecmp(key, "physical id") == 0) cur_physical = atoi(value);
        else if (strcasecmp(key, "cpu cores") == 0) cur_cores = atoi(value);
    }
    if (cur_physical >= 0 && cur_cores >= 0 && pairs < PSUTIL_MAX_CPUS) {
        physical[pairs] = cur_physical;
        cores[pairs] = cur_cores;
        pairs++;
    }
    fclose(f);
    int total = 0;
    for (int i = 0; i < pairs; i++) {
        int seen = 0;
        for (int j = 0; j < i; j++) {
            if (physical[i] == physical[j]) {
                seen = 1;
                break;
            }
        }
        if (!seen) total += cores[i];
    }
    return total > 0 ? total : PSUTIL_UNSUPPORTED;
}

int psutil_sys_cpu_count(int logical) {
    return logical ? psys_cpu_count_logical() : psys_cpu_count_cores();
}

int psutil_sys_cpu_stats(psutil_CpuStats* out) {
    if (!out) return PSUTIL_UNSUPPORTED;
    memset(out, 0, sizeof(*out));
    FILE* f = fopen("/proc/stat", "r");
    if (!f) return PSUTIL_UNSUPPORTED;
    char line[1024];
    int found = 0;
    while (fgets(line, sizeof(line), f)) {
        unsigned long long value = 0;
        if (sscanf(line, "ctxt %llu", &value) == 1) {
            out->ctx_switches = value;
            found++;
        } else if (sscanf(line, "intr %llu", &value) == 1) {
            out->interrupts = value;
            found++;
        } else if (sscanf(line, "softirq %llu", &value) == 1) {
            out->soft_interrupts = value;
            found++;
        }
        if (found == 3) break;
    }
    fclose(f);
    return found == 3 ? PSUTIL_OK : PSUTIL_UNSUPPORTED;
}

typedef struct {
    int num;
    char path[256];
} psys_freq_path;

static int psys_freq_cmp(const void* a, const void* b) {
    const psys_freq_path* x = (const psys_freq_path*)a;
    const psys_freq_path* y = (const psys_freq_path*)b;
    return (x->num > y->num) - (x->num < y->num);
}

static double psys_freq_read(const char* path) {
    char buf[128];
    FILE* f = fopen(path, "r");
    if (!f) return -1.0;
    if (!fgets(buf, sizeof(buf), f)) { fclose(f); return -1.0; }
    fclose(f);
    double v = atof(buf);
    return v > 0.0 ? v : -1.0;
}

int psutil_sys_cpu_freq(psutil_CpuFreq* out, int cap) {
    if (!out || cap <= 0) return PSUTIL_UNSUPPORTED;
    psys_freq_path paths[PSUTIL_MAX_CPUS];
    int n = 0;
    const char* roots[2] = {
        "/sys/devices/system/cpu/cpufreq",
        "/sys/devices/system/cpu"
    };
    for (int r = 0; r < 2 && n == 0; r++) {
        DIR* d = opendir(roots[r]);
        if (!d) continue;
        struct dirent* e;
        while ((e = readdir(d)) != NULL && n < cap) {
            int num = -1;
            if (r == 0 && strncmp(e->d_name, "policy", 6) == 0)
                num = atoi(e->d_name + 6);
            else if (r == 1 && strncmp(e->d_name, "cpu", 3) == 0)
                num = atoi(e->d_name + 3);
            if (num < 0) continue;
            snprintf(paths[n].path, sizeof(paths[n].path), "%s/%s", roots[r], e->d_name);
            paths[n].num = num;
            n++;
        }
        closedir(d);
    }
    qsort(paths, (size_t)n, sizeof(paths[0]), psys_freq_cmp);
    for (int i = 0; i < n; i++) {
        char p[512];
        snprintf(p, sizeof(p), "%s/scaling_cur_freq", paths[i].path);
        double cur = psys_freq_read(p);
        if (cur < 0.0) {
            snprintf(p, sizeof(p), "%s/cpuinfo_cur_freq", paths[i].path);
            cur = psys_freq_read(p);
        }
        memset(&out[i], 0, sizeof(out[i]));
        if (cur < 0.0) continue; /* offline cpu: 全 0 */
        snprintf(p, sizeof(p), "%s/scaling_min_freq", paths[i].path);
        double lo = psys_freq_read(p);
        snprintf(p, sizeof(p), "%s/scaling_max_freq", paths[i].path);
        double hi = psys_freq_read(p);
        out[i].current = cur / 1000.0;
        out[i].min = lo < 0.0 ? 0.0 : lo / 1000.0;
        out[i].max = hi < 0.0 ? 0.0 : hi / 1000.0;
    }
    if (n > 0) return n;
    /* 回退：/proc/cpuinfo 的 "cpu MHz"，min/max = 0（对齐 pypi 备用实现） */
    FILE* f = fopen("/proc/cpuinfo", "r");
    if (!f) return PSUTIL_UNSUPPORTED;
    char line[512];
    while (fgets(line, sizeof(line), f) && n < cap) {
        char* colon = strchr(line, ':');
        if (!colon || strncasecmp(line, "cpu MHz", 7) != 0) continue;
        double v = atof(colon + 1);
        if (v <= 0.0) continue;
        out[n].current = v;
        out[n].min = 0.0;
        out[n].max = 0.0;
        n++;
    }
    fclose(f);
    return n > 0 ? n : PSUTIL_UNSUPPORTED;
}

int psutil_sys_getloadavg(double* out, int cap) {
    if (!out || cap < 3) return PSUTIL_UNSUPPORTED;
    if (getloadavg(out, 3) != 3) return PSUTIL_UNSUPPORTED;
    return 3;
}

typedef struct {
    char key[64];
    unsigned long long value;
} psys_mem_entry;

static int psys_read_meminfo(psys_mem_entry* out, int cap) {
    if (!out || cap <= 0) return 0;
    FILE* f = fopen("/proc/meminfo", "r");
    if (!f) return 0;
    char line[512];
    int n = 0;
    while (fgets(line, sizeof(line), f) && n < cap) {
        char key[64];
        unsigned long long value = 0;
        if (sscanf(line, "%63s %llu", key, &value) != 2) continue;
        psys_copy(out[n].key, sizeof(out[n].key), key);
        out[n].value = value * 1024ULL;
        n++;
    }
    fclose(f);
    return n;
}

static unsigned long long psys_mem_get(const psys_mem_entry* entries, int n,
                                       const char* key) {
    for (int i = 0; i < n; i++) {
        if (strcmp(entries[i].key, key) == 0) return entries[i].value;
    }
    return 0;
}

static int psys_mem_has(const psys_mem_entry* entries, int n,
                        const char* key) {
    for (int i = 0; i < n; i++) {
        if (strcmp(entries[i].key, key) == 0) return 1;
    }
    return 0;
}

static unsigned long long psys_avail_vmem(const psys_mem_entry* entries,
                                          int n) {
    unsigned long long free = psys_mem_get(entries, n, "MemFree:");
    unsigned long long fallback = free + psys_mem_get(entries, n, "Cached:");
    if (!psys_mem_has(entries, n, "Active(file):") ||
        !psys_mem_has(entries, n, "Inactive(file):") ||
        !psys_mem_has(entries, n, "SReclaimable:")) {
        return fallback;
    }
    FILE* f = fopen("/proc/zoneinfo", "r");
    if (!f) return fallback;
    unsigned long long watermark = 0;
    char line[512];
    while (fgets(line, sizeof(line), f)) {
        char key[64];
        unsigned long long value = 0;
        if (sscanf(line, "%63s %llu", key, &value) == 2 &&
            strcmp(key, "low") == 0) {
            watermark += value;
        }
    }
    fclose(f);
    watermark *= (unsigned long long)psys_page_size();
    unsigned long long active_file = psys_mem_get(entries, n, "Active(file):");
    unsigned long long inactive_file = psys_mem_get(entries, n, "Inactive(file):");
    unsigned long long reclaimable = psys_mem_get(entries, n, "SReclaimable:");
    long double pagecache = (long double)active_file + (long double)inactive_file;
    long double pagecache_low = (long double)watermark;
    if (pagecache_low > pagecache / 2.0L) pagecache_low = pagecache / 2.0L;
    pagecache -= pagecache_low;
    long double slab_low = (long double)watermark;
    if (slab_low > (long double)reclaimable / 2.0L) {
        slab_low = (long double)reclaimable / 2.0L;
    }
    long double avail = (long double)free - (long double)watermark + pagecache +
                        (long double)reclaimable - slab_low;
    if (avail < 0) return 0;
    return (unsigned long long)avail;
}

int psutil_sys_virtual_memory(psutil_VirtualMemory* out) {
    if (!out) return PSUTIL_UNSUPPORTED;
    psys_mem_entry mems[128];
    int n = psys_read_meminfo(mems, 128);
    if (n == 0 || !psys_mem_has(mems, n, "MemTotal:") ||
        !psys_mem_has(mems, n, "MemFree:")) {
        return PSUTIL_UNSUPPORTED;
    }
    memset(out, 0, sizeof(*out));
    out->total = psys_mem_get(mems, n, "MemTotal:");
    out->free_mem = psys_mem_get(mems, n, "MemFree:");
    out->buffers = psys_mem_get(mems, n, "Buffers:");
    out->cached = psys_mem_get(mems, n, "Cached:") +
                  psys_mem_get(mems, n, "SReclaimable:");
    out->shared = psys_mem_get(mems, n, "Shmem:");
    if (out->shared == 0) out->shared = psys_mem_get(mems, n, "MemShared:");
    out->active = psys_mem_get(mems, n, "Active:");
    out->inactive = psys_mem_get(mems, n, "Inactive:");
    if (out->inactive == 0) {
        out->inactive = psys_mem_get(mems, n, "Inact_dirty:") +
                        psys_mem_get(mems, n, "Inact_clean:") +
                        psys_mem_get(mems, n, "Inact_laundry:");
    }
    out->slab = psys_mem_get(mems, n, "Slab:");
    out->available = psys_mem_get(mems, n, "MemAvailable:");
    if (out->available == 0) out->available = psys_avail_vmem(mems, n);
    if (out->available > out->total) out->available = out->free_mem;
    out->used = out->total - out->available;
    out->percent = psys_usage_percent(out->total - out->available, out->total);
    return PSUTIL_OK;
}

int psutil_sys_swap_memory(psutil_SwapMemory* out) {
    if (!out) return PSUTIL_UNSUPPORTED;
    psys_mem_entry mems[128];
    int n = psys_read_meminfo(mems, 128);
    if (n == 0 || !psys_mem_has(mems, n, "SwapTotal:") ||
        !psys_mem_has(mems, n, "SwapFree:")) {
        return PSUTIL_UNSUPPORTED;
    }
    memset(out, 0, sizeof(*out));
    out->total = psys_mem_get(mems, n, "SwapTotal:");
    out->free_swap = psys_mem_get(mems, n, "SwapFree:");
    out->used = out->total - out->free_swap;
    out->percent = psys_usage_percent(out->used, out->total);
    FILE* f = fopen("/proc/vmstat", "r");
    if (f) {
        char line[512];
        unsigned long long value = 0;
        while (fgets(line, sizeof(line), f)) {
            if (sscanf(line, "pswpin %llu", &value) == 1) {
                out->sin = value * 4096ULL;
            } else if (sscanf(line, "pswpout %llu", &value) == 1) {
                out->sout = value * 4096ULL;
            }
            if (out->sin > 0 && out->sout > 0) break;
        }
        fclose(f);
    }
    return PSUTIL_OK;
}

static int psys_fs_allows(const char* fstype) {
    FILE* f = fopen("/proc/filesystems", "r");
    if (!f) return 1;
    char line[512];
    int found = 0;
    while (fgets(line, sizeof(line), f)) {
        char* p = line;
        while (*p == ' ' || *p == '\t') p++;
        size_t n = strlen(p);
        while (n && (p[n - 1] == '\n' || p[n - 1] == '\r' || p[n - 1] == ' ')) {
            p[--n] = '\0';
        }
        if (n == 0) continue;
        if (strncmp(p, "nodev", 5) == 0) {
            char* fs = p + 5;
            while (*fs == ' ' || *fs == '\t') fs++;
            if (strcmp(fs, "zfs") != 0) continue;
            if (strcmp(fs, fstype) == 0) found = 1;
        } else if (strcmp(p, fstype) == 0) {
            found = 1;
        }
        if (found) break;
    }
    fclose(f);
    return found;
}

static void psys_unescape_mount(char* dst, int cap, const char* src) {
    int n = 0;
    while (*src && n < cap - 1) {
        if (src[0] == '\\' && isdigit((unsigned char)src[1]) &&
            isdigit((unsigned char)src[2]) && isdigit((unsigned char)src[3])) {
            int value = (src[1] - '0') * 64 + (src[2] - '0') * 8 +
                        (src[3] - '0');
            dst[n++] = (char)value;
            src += 4;
        } else {
            dst[n++] = *src++;
        }
    }
    dst[n] = '\0';
}

static void psys_resolve_root_device(char* device, int cap) {
    if (strcmp(device, "/dev/root") != 0 && strcmp(device, "rootfs") != 0) return;
    unsigned long long major = 0;
    unsigned long long minor = 0;
    struct statvfs st;
    if (statvfs("/", &st) != 0) return;
    major = (unsigned long long)st.f_fsid & 0xffULL;
    minor = ((unsigned long long)st.f_fsid >> 8) & 0xffULL;
    FILE* f = fopen("/proc/partitions", "r");
    if (!f) return;
    char line[512];
    while (fgets(line, sizeof(line), f)) {
        unsigned long long ma = 0;
        unsigned long long mi = 0;
        char name[128] = {0};
        if (sscanf(line, "%llu %llu %llu %127s", &ma, &mi, &ma, name) != 4) continue;
        if (ma == major && mi == minor) {
            char path[512];
            snprintf(path, sizeof(path), "/dev/%s", name);
            if (access(path, F_OK) == 0) psys_copy(device, cap, path);
            break;
        }
    }
    fclose(f);
}

int psutil_sys_disk_partitions(int all, psutil_Partition* out, int cap) {
    if (!out || cap <= 0) return PSUTIL_UNSUPPORTED;
    const char* mounts_path = "/proc/self/mounts";
    if (access("/etc/mtab", F_OK) == 0) mounts_path = "/etc/mtab";
    FILE* f = fopen(mounts_path, "r");
    if (!f) return PSUTIL_UNSUPPORTED;
    char line[4096];
    int n = 0;
    while (fgets(line, sizeof(line), f) && n < cap) {
        char raw_device[512] = {0};
        char raw_mount[1024] = {0};
        char fstype[128] = {0};
        char opts[512] = {0};
        if (sscanf(line, "%511s %1023s %127s %511s", raw_device, raw_mount,
                   fstype, opts) != 4) {
            continue;
        }
        char device[512];
        psys_unescape_mount(device, sizeof(device), raw_device);
        if (strcmp(device, "none") == 0) device[0] = '\0';
        psys_resolve_root_device(device, sizeof(device));
        if (!all && (device[0] == '\0' || !psys_fs_allows(fstype))) continue;
        psys_copy(out[n].device, sizeof(out[n].device), device);
        psys_unescape_mount(out[n].mountpoint, sizeof(out[n].mountpoint), raw_mount);
        psys_copy(out[n].fstype, sizeof(out[n].fstype), fstype);
        psys_copy(out[n].opts, sizeof(out[n].opts), opts);
        n++;
    }
    fclose(f);
    return n;
}

int psutil_sys_disk_usage(const char* path, psutil_DiskUsage* out) {
    if (!path || !out) return PSUTIL_UNSUPPORTED;
    struct statvfs st;
    if (statvfs(path, &st) != 0) return PSUTIL_UNSUPPORTED;
    unsigned long long total = st.f_blocks * st.f_frsize;
    unsigned long long avail_root = st.f_bfree * st.f_frsize;
    unsigned long long avail_user = st.f_bavail * st.f_frsize;
    unsigned long long used = total >= avail_root ? total - avail_root : 0;
    unsigned long long total_user = used + avail_user;
    memset(out, 0, sizeof(*out));
    psys_copy(out->path, sizeof(out->path), path);
    out->total = total;
    out->used = used;
    out->free_disk = avail_user;
    out->percent = psys_usage_percent(used, total_user);
    return PSUTIL_OK;
}

static int psys_is_storage_device(const char* name) {
    char path[1024];
    size_t n = 0;
    for (const char* p = name; *p && n < sizeof(path) - 10; p++) {
        path[n++] = (*p == '/') ? '!' : *p;
    }
    memcpy(path + n, "/", 1);
    n++;
    const char* suffix = "/sys/block/";
    memmove(path + strlen(suffix), path, n + 1);
    memcpy(path, suffix, strlen(suffix));
    return access(path, F_OK) == 0;
}

typedef struct {
    char name[128];
    unsigned long long reads;
    unsigned long long writes;
    unsigned long long rbytes;
    unsigned long long wbytes;
    unsigned long long rtime;
    unsigned long long wtime;
    unsigned long long reads_merged;
    unsigned long long writes_merged;
    unsigned long long busy_time;
} psys_disk_raw;

int psutil_sys_disk_io_counters(int perdisk, psutil_DiskIO* out, int cap) {
    if (!out || cap <= 0) return PSUTIL_UNSUPPORTED;
    FILE* f = fopen("/proc/diskstats", "r");
    if (!f) return PSUTIL_UNSUPPORTED;
    psys_disk_raw raws[PSUTIL_MAX_DISKS];
    int count = 0;
    char line[2048];
    while (fgets(line, sizeof(line), f) && count < PSUTIL_MAX_DISKS) {
        char* fields[32];
        int nfields = 0;
        char* save = NULL;
        char* tok = strtok_r(line, " \t\n", &save);
        while (tok && nfields < 32) {
            fields[nfields++] = tok;
            tok = strtok_r(NULL, " \t\n", &save);
        }
        if (nfields < 7) continue;
        psys_disk_raw raw;
        memset(&raw, 0, sizeof(raw));
        if (nfields == 15) {
            psys_copy(raw.name, sizeof(raw.name), fields[3]);
            raw.reads = strtoull(fields[2], NULL, 10);
            raw.reads_merged = strtoull(fields[4], NULL, 10);
            raw.rbytes = strtoull(fields[5], NULL, 10);
            raw.rtime = strtoull(fields[6], NULL, 10);
            raw.writes = strtoull(fields[7], NULL, 10);
            raw.writes_merged = strtoull(fields[8], NULL, 10);
            raw.wbytes = strtoull(fields[9], NULL, 10);
            raw.wtime = strtoull(fields[10], NULL, 10);
            raw.busy_time = strtoull(fields[12], NULL, 10);
        } else if (nfields == 14 || nfields >= 18) {
            psys_copy(raw.name, sizeof(raw.name), fields[2]);
            raw.reads = strtoull(fields[3], NULL, 10);
            raw.reads_merged = strtoull(fields[4], NULL, 10);
            raw.rbytes = strtoull(fields[5], NULL, 10);
            raw.rtime = strtoull(fields[6], NULL, 10);
            raw.writes = strtoull(fields[7], NULL, 10);
            raw.writes_merged = strtoull(fields[8], NULL, 10);
            raw.wbytes = strtoull(fields[9], NULL, 10);
            raw.wtime = strtoull(fields[10], NULL, 10);
            raw.busy_time = strtoull(fields[12], NULL, 10);
        } else if (nfields == 7) {
            psys_copy(raw.name, sizeof(raw.name), fields[2]);
            raw.reads = strtoull(fields[3], NULL, 10);
            raw.rbytes = strtoull(fields[4], NULL, 10);
            raw.writes = strtoull(fields[5], NULL, 10);
            raw.wbytes = strtoull(fields[6], NULL, 10);
        } else {
            continue;
        }
        if (!perdisk && !psys_is_storage_device(raw.name)) continue;
        raws[count++] = raw;
    }
    fclose(f);
    if (count == 0) return 0;
    if (!perdisk) {
        psutil_DiskIO sum;
        memset(&sum, 0, sizeof(sum));
        for (int i = 0; i < count; i++) {
            sum.read_count += raws[i].reads;
            sum.write_count += raws[i].writes;
            sum.read_bytes += raws[i].rbytes * 512ULL;
            sum.write_bytes += raws[i].wbytes * 512ULL;
            sum.read_time += raws[i].rtime;
            sum.write_time += raws[i].wtime;
            sum.read_merged_count += raws[i].reads_merged;
            sum.write_merged_count += raws[i].writes_merged;
            sum.busy_time += raws[i].busy_time;
        }
        out[0] = sum;
        return 1;
    }
    int n = count < cap ? count : cap;
    for (int i = 0; i < n; i++) {
        psutil_DiskIO* dst = &out[i];
        memset(dst, 0, sizeof(*dst));
        psys_copy(dst->name, sizeof(dst->name), raws[i].name);
        dst->read_count = raws[i].reads;
        dst->write_count = raws[i].writes;
        dst->read_bytes = raws[i].rbytes * 512ULL;
        dst->write_bytes = raws[i].wbytes * 512ULL;
        dst->read_time = raws[i].rtime;
        dst->write_time = raws[i].wtime;
        dst->read_merged_count = raws[i].reads_merged;
        dst->write_merged_count = raws[i].writes_merged;
        dst->busy_time = raws[i].busy_time;
    }
    return n;
}

int psutil_sys_net_io_counters(int pernic, psutil_NetIO* out, int cap) {
    if (!out || cap <= 0) return PSUTIL_UNSUPPORTED;
    FILE* f = fopen("/proc/net/dev", "r");
    if (!f) return PSUTIL_UNSUPPORTED;
    char line[2048];
    int n = 0;
    int line_no = 0;
    int seen = 0;
    while (fgets(line, sizeof(line), f)) {
        if (line_no++ < 2) continue;
        char* colon = strrchr(line, ':');
        if (!colon) continue;
        *colon = '\0';
        char name[128];
        psys_copy(name, sizeof(name), line);
        char* p = colon + 1;
        unsigned long long values[16] = {0};
        for (int i = 0; i < 16; i++) {
            while (*p == ' ' || *p == '\t') p++;
            if (!*p) break;
            values[i] = strtoull(p, &p, 10);
        }
        psutil_NetIO cur;
        memset(&cur, 0, sizeof(cur));
        seen = 1;
        psys_copy(cur.name, sizeof(cur.name), name);
        cur.bytes_recv = values[0];
        cur.packets_recv = values[1];
        cur.errin = values[2];
        cur.dropin = values[3];
        cur.bytes_sent = values[8];
        cur.packets_sent = values[9];
        cur.errout = values[10];
        cur.dropout = values[11];
        if (pernic) {
            if (n >= cap) break;
            out[n++] = cur;
        } else {
            out[0].bytes_sent += cur.bytes_sent;
            out[0].bytes_recv += cur.bytes_recv;
            out[0].packets_sent += cur.packets_sent;
            out[0].packets_recv += cur.packets_recv;
            out[0].errin += cur.errin;
            out[0].errout += cur.errout;
            out[0].dropin += cur.dropin;
            out[0].dropout += cur.dropout;
        }
    }
    fclose(f);
    if (!pernic && seen) return 1;
    return n;
}

static void psys_append_scope(char* buf, int cap, const char* addr,
                              uint32_t scope_id) {
    psys_copy(buf, cap, addr);
    if (scope_id == 0) return;
    char ifname[IF_NAMESIZE] = {0};
    if (if_indextoname(scope_id, ifname) == NULL) return;
    size_t n = strlen(buf);
    if (n + 1 + strlen(ifname) >= (size_t)cap) return;
    buf[n++] = '%';
    strcpy(buf + n, ifname);
}

static void psys_format_mac(char* dst, int cap, const unsigned char* addr,
                            int len) {
    int n = 0;
    for (int i = 0; i < len && n < cap - 4; i++) {
        n += snprintf(dst + n, (size_t)(cap - n), "%s%02x",
                      i == 0 ? "" : ":", addr[i]);
    }
}

static int psys_addr_cmp(const void* a, const void* b) {
    const psutil_NicAddress* x = (const psutil_NicAddress*)a;
    const psutil_NicAddress* y = (const psutil_NicAddress*)b;
    int rc = strcmp(x->name, y->name);
    if (rc != 0) return rc;
    return x->family - y->family;
}

int psutil_sys_net_if_addrs(psutil_NicAddress* out, int cap) {
    if (!out || cap <= 0) return PSUTIL_UNSUPPORTED;
    struct ifaddrs* head = NULL;
    if (getifaddrs(&head) != 0) return PSUTIL_UNSUPPORTED;
    int n = 0;
    for (struct ifaddrs* ifa = head; ifa && n < cap; ifa = ifa->ifa_next) {
        if (!ifa->ifa_addr) continue;
        psutil_NicAddress* cur = &out[n];
        memset(cur, 0, sizeof(*cur));
        psys_copy(cur->name, sizeof(cur->name), ifa->ifa_name);
        int family = ifa->ifa_addr->sa_family;
        char addr[INET6_ADDRSTRLEN + IF_NAMESIZE + 2] = {0};
        if (family == AF_INET) {
            struct sockaddr_in* sin = (struct sockaddr_in*)ifa->ifa_addr;
            inet_ntop(AF_INET, &sin->sin_addr, addr, sizeof(addr));
            psys_copy(cur->address, sizeof(cur->address), addr);
            if (ifa->ifa_netmask) {
                struct sockaddr_in* mask = (struct sockaddr_in*)ifa->ifa_netmask;
                inet_ntop(AF_INET, &mask->sin_addr, addr, sizeof(addr));
                psys_copy(cur->netmask, sizeof(cur->netmask), addr);
            }
            if ((ifa->ifa_flags & IFF_BROADCAST) && ifa->ifa_ifu.ifu_broadaddr &&
                ifa->ifa_ifu.ifu_broadaddr->sa_family == AF_INET) {
                struct sockaddr_in* bcast =
                    (struct sockaddr_in*)ifa->ifa_ifu.ifu_broadaddr;
                inet_ntop(AF_INET, &bcast->sin_addr, addr, sizeof(addr));
                psys_copy(cur->broadcast, sizeof(cur->broadcast), addr);
            }
            if ((ifa->ifa_flags & IFF_POINTOPOINT) && ifa->ifa_dstaddr &&
                ifa->ifa_dstaddr->sa_family == AF_INET) {
                struct sockaddr_in* ptp = (struct sockaddr_in*)ifa->ifa_dstaddr;
                inet_ntop(AF_INET, &ptp->sin_addr, addr, sizeof(addr));
                psys_copy(cur->ptp, sizeof(cur->ptp), addr);
            }
        } else if (family == AF_INET6) {
            struct sockaddr_in6* sin6 = (struct sockaddr_in6*)ifa->ifa_addr;
            char plain[INET6_ADDRSTRLEN] = {0};
            inet_ntop(AF_INET6, &sin6->sin6_addr, plain, sizeof(plain));
            psys_append_scope(addr, sizeof(addr), plain, sin6->sin6_scope_id);
            psys_copy(cur->address, sizeof(cur->address), addr);
            if (ifa->ifa_netmask) {
                struct sockaddr_in6* mask = (struct sockaddr_in6*)ifa->ifa_netmask;
                inet_ntop(AF_INET6, &mask->sin6_addr, addr, sizeof(addr));
                psys_copy(cur->netmask, sizeof(cur->netmask), addr);
            }
        } else if (family == AF_PACKET) {
            struct sockaddr_ll* ll = (struct sockaddr_ll*)ifa->ifa_addr;
            psys_format_mac(addr, sizeof(addr), ll->sll_addr, ll->sll_halen > 0 ? ll->sll_halen : 6);
            psys_copy(cur->address, sizeof(cur->address), addr);
            if ((ifa->ifa_flags & IFF_BROADCAST) && ifa->ifa_ifu.ifu_broadaddr &&
                ifa->ifa_ifu.ifu_broadaddr->sa_family == AF_PACKET) {
                struct sockaddr_ll* bcast =
                    (struct sockaddr_ll*)ifa->ifa_ifu.ifu_broadaddr;
                psys_format_mac(addr, sizeof(addr), bcast->sll_addr, bcast->sll_halen > 0 ? bcast->sll_halen : 6);
                psys_copy(cur->broadcast, sizeof(cur->broadcast), addr);
            }
        } else {
            continue;
        }
        cur->family = family;
        n++;
    }
    freeifaddrs(head);
    qsort(out, (size_t)n, sizeof(out[0]), psys_addr_cmp);
    return n;
}

static void psys_append_flag(char* flags, int cap, const char* name) {
    size_t len = strlen(flags);
    if (len >= (size_t)(cap - 1)) return;
    if (len > 0) strncat(flags, ",", (size_t)(cap - len - 1));
    strncat(flags, name, (size_t)(cap - strlen(flags) - 1));
}

static unsigned int psys_read_uint(const char* path) {
    FILE* f = fopen(path, "r");
    if (!f) return 0;
    unsigned int value = 0;
    if (fscanf(f, "%u", &value) != 1) value = 0;
    fclose(f);
    return value;
}

static void psys_read_text(const char* path, char* out, int cap) {
    out[0] = '\0';
    FILE* f = fopen(path, "r");
    if (!f) return;
    if (fgets(out, cap, f)) {
        size_t n = strlen(out);
        while (n && (out[n - 1] == '\n' || out[n - 1] == '\r')) out[--n] = '\0';
    }
    fclose(f);
}

static unsigned long long psys_if_flags(const char* name) {
    int fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd < 0) return 0;
    struct ifreq req;
    memset(&req, 0, sizeof(req));
    psys_copy(req.ifr_name, sizeof(req.ifr_name), name);
    unsigned long long flags = 0;
    if (ioctl(fd, SIOCGIFFLAGS, &req) == 0) {
        flags = (unsigned short)req.ifr_flags;
    }
    close(fd);
    return flags;
}

int psutil_sys_net_if_stats(psutil_NicStats* out, int cap) {
    if (!out || cap <= 0) return PSUTIL_UNSUPPORTED;
    DIR* dir = opendir("/sys/class/net");
    if (!dir) return PSUTIL_UNSUPPORTED;
    int n = 0;
    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL && n < cap) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }
        char base[1024];
        snprintf(base, sizeof(base), "/sys/class/net/%s", entry->d_name);
        psutil_NicStats* cur = &out[n];
        memset(cur, 0, sizeof(*cur));
        psys_copy(cur->name, sizeof(cur->name), entry->d_name);
        char path[1200];
        snprintf(path, sizeof(path), "%s/mtu", base);
        cur->mtu = psys_read_uint(path);
        unsigned long long flags = psys_if_flags(entry->d_name);
        if (flags & 0x1) psys_append_flag(cur->flags, sizeof(cur->flags), "up");
        if (flags & 0x8) psys_append_flag(cur->flags, sizeof(cur->flags), "loopback");
        if (flags & 0x2) psys_append_flag(cur->flags, sizeof(cur->flags), "broadcast");
        if (flags & 0x10) psys_append_flag(cur->flags, sizeof(cur->flags), "pointopoint");
        if (flags & 0x40) psys_append_flag(cur->flags, sizeof(cur->flags), "running");
        if (flags & 0x80) psys_append_flag(cur->flags, sizeof(cur->flags), "noarp");
        if (flags & 0x1000) psys_append_flag(cur->flags, sizeof(cur->flags), "multicast");
        cur->isup = strstr(cur->flags, "running") != NULL ? 1 : 0;
        snprintf(path, sizeof(path), "%s/duplex", base);
        char duplex[64] = {0};
        psys_read_text(path, duplex, sizeof(duplex));
        if (strcmp(duplex, "full") == 0) cur->duplex = PSUTIL_DUPLEX_FULL;
        else if (strcmp(duplex, "half") == 0) cur->duplex = PSUTIL_DUPLEX_HALF;
        else cur->duplex = PSUTIL_DUPLEX_UNKNOWN;
        snprintf(path, sizeof(path), "%s/speed", base);
        cur->speed = psys_read_uint(path);
        if (cur->speed == 0xffffffffU) cur->speed = 0;
        n++;
    }
    closedir(dir);
    return n;
}

typedef struct {
    unsigned long long inode;
    int pid;
    int fd;
} psys_socket_owner;

static int psys_owner_cmp(const void* a, const void* b) {
    const psys_socket_owner* x = (const psys_socket_owner*)a;
    const psys_socket_owner* y = (const psys_socket_owner*)b;
    return (x->inode > y->inode) - (x->inode < y->inode);
}

static int psys_build_socket_owners(psys_socket_owner* out, int cap) {
    DIR* proc = opendir("/proc");
    if (!proc) return 0;
    int n = 0;
    struct dirent* entry;
    while ((entry = readdir(proc)) != NULL && n < cap) {
        if (!isdigit((unsigned char)entry->d_name[0])) continue;
        int pid = atoi(entry->d_name);
        char fdpath[256];
        snprintf(fdpath, sizeof(fdpath), "/proc/%d/fd", pid);
        DIR* fd_dir = opendir(fdpath);
        if (!fd_dir) continue;
        struct dirent* fd_entry;
        while ((fd_entry = readdir(fd_dir)) != NULL && n < cap) {
            if (!isdigit((unsigned char)fd_entry->d_name[0])) continue;
            char link[256];
            snprintf(link, sizeof(link), "%s/%s", fdpath, fd_entry->d_name);
            char target[512] = {0};
            ssize_t rc = readlink(link, target, sizeof(target) - 1);
            if (rc <= 0) continue;
            target[rc] = '\0';
            if (strncmp(target, "socket:[", 8) != 0) continue;
            char* end = NULL;
            unsigned long long inode = strtoull(target + 8, &end, 10);
            if (inode == 0 || !end || *end != ']') continue;
            out[n].inode = inode;
            out[n].pid = pid;
            out[n].fd = atoi(fd_entry->d_name);
            n++;
        }
        closedir(fd_dir);
    }
    closedir(proc);
    qsort(out, (size_t)n, sizeof(out[0]), psys_owner_cmp);
    return n;
}

static psys_socket_owner* psys_find_owner(psys_socket_owner* owners, int n,
                                          unsigned long long inode) {
    psys_socket_owner key;
    key.inode = inode;
    key.pid = 0;
    key.fd = -1;
    return (psys_socket_owner*)bsearch(&key, owners, (size_t)n,
                                       sizeof(owners[0]), psys_owner_cmp);
}

static const char* psys_tcp_status(const char* hex) {
    if (strcmp(hex, "01") == 0) return "ESTABLISHED";
    if (strcmp(hex, "02") == 0) return "SYN_SENT";
    if (strcmp(hex, "03") == 0) return "SYN_RECV";
    if (strcmp(hex, "04") == 0) return "FIN_WAIT1";
    if (strcmp(hex, "05") == 0) return "FIN_WAIT2";
    if (strcmp(hex, "06") == 0) return "TIME_WAIT";
    if (strcmp(hex, "07") == 0) return "CLOSE";
    if (strcmp(hex, "08") == 0) return "CLOSE_WAIT";
    if (strcmp(hex, "09") == 0) return "LAST_ACK";
    if (strcmp(hex, "0A") == 0) return "LISTEN";
    if (strcmp(hex, "0B") == 0) return "CLOSING";
    return "NONE";
}

static int psys_hex_byte(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

static int psys_parse_addr(const char* text, int family, char* ip, int ipcap,
                           int* port) {
    const char* colon = strrchr(text, ':');
    if (!colon) return 0;
    *port = (int)strtol(colon + 1, NULL, 16);
    int bytes = family == AF_INET6 ? 16 : 4;
    unsigned char raw[16] = {0};
    for (int i = 0; i < bytes; i++) {
        int hi = psys_hex_byte(text[i * 2]);
        int lo = psys_hex_byte(text[i * 2 + 1]);
        if (hi < 0 || lo < 0) return 0;
        raw[i] = (unsigned char)((hi << 4) | lo);
    }
    if (family == AF_INET) {
        unsigned char swapped[4] = {raw[3], raw[2], raw[1], raw[0]};
        inet_ntop(AF_INET, swapped, ip, (size_t)ipcap);
    } else {
        unsigned char ordered[16];
        for (int i = 0; i < 4; i++) {
            ordered[i * 4 + 0] = raw[i * 4 + 3];
            ordered[i * 4 + 1] = raw[i * 4 + 2];
            ordered[i * 4 + 2] = raw[i * 4 + 1];
            ordered[i * 4 + 3] = raw[i * 4 + 0];
        }
        inet_ntop(AF_INET6, ordered, ip, (size_t)ipcap);
    }
    return 1;
}

static int psys_parse_inet(const char* path, int family, int typ,
                           psutil_SysConnection* out, int cap,
                           psys_socket_owner* owners, int nowners) {
    FILE* f = fopen(path, "r");
    if (!f) return 0;
    char line[2048];
    int n = 0;
    int line_no = 0;
    while (fgets(line, sizeof(line), f) && n < cap) {
        if (line_no++ == 0) continue;
        char* fields[24];
        int count = 0;
        char* save = NULL;
        char* tok = strtok_r(line, " \t\n", &save);
        while (tok && count < 24) {
            fields[count++] = tok;
            tok = strtok_r(NULL, " \t\n", &save);
        }
        if (count < 10) continue;
        psutil_SysConnection* cur = &out[n];
        memset(cur, 0, sizeof(*cur));
        cur->family = family;
        cur->typ = typ;
        cur->fd = -1;
        cur->pid = 0;
        psys_parse_addr(fields[1], family, cur->laddr_ip,
                        sizeof(cur->laddr_ip), &cur->laddr_port);
        psys_parse_addr(fields[2], family, cur->raddr_ip,
                        sizeof(cur->raddr_ip), &cur->raddr_port);
        if (typ == 1) {
            psys_copy(cur->status, sizeof(cur->status),
                      psys_tcp_status(fields[3]));
        } else {
            psys_copy(cur->status, sizeof(cur->status), "NONE");
        }
        unsigned long long inode = strtoull(fields[9], NULL, 10);
        psys_socket_owner* owner = psys_find_owner(owners, nowners, inode);
        if (owner) {
            cur->pid = owner->pid;
            cur->fd = owner->fd;
        }
        n++;
    }
    fclose(f);
    return n;
}

static int psys_parse_unix(psutil_SysConnection* out, int cap,
                           psys_socket_owner* owners, int nowners) {
    FILE* f = fopen("/proc/net/unix", "r");
    if (!f) return 0;
    char line[4096];
    int n = 0;
    int line_no = 0;
    while (fgets(line, sizeof(line), f) && n < cap) {
        if (line_no++ == 0) continue;
        char* fields[8];
        int count = 0;
        char* save = NULL;
        char* tok = strtok_r(line, " \t\n", &save);
        while (tok && count < 8) {
            fields[count++] = tok;
            tok = strtok_r(NULL, " \t\n", &save);
        }
        if (count < 7) continue;
        int typ = atoi(fields[4]);
        if (typ != 1 && typ != 2 && typ != 3) continue;
        psutil_SysConnection* cur = &out[n];
        memset(cur, 0, sizeof(*cur));
        cur->family = 1;
        cur->typ = typ;
        cur->fd = -1;
        cur->pid = 0;
        psys_copy(cur->status, sizeof(cur->status), "NONE");
        if (count > 7) {
            psys_copy(cur->laddr_ip, sizeof(cur->laddr_ip), fields[7]);
        }
        unsigned long long inode = strtoull(fields[6], NULL, 10);
        psys_socket_owner* owner = psys_find_owner(owners, nowners, inode);
        if (owner) {
            cur->pid = owner->pid;
            cur->fd = owner->fd;
        }
        n++;
    }
    fclose(f);
    return n;
}

int psutil_sys_net_connections(const char* kind, psutil_SysConnection* out,
                               int cap) {
    if (!out || cap <= 0 || !kind) return PSUTIL_UNSUPPORTED;
    int want_unix = strcmp(kind, "unix") == 0;
    int want_inet = !want_unix;
    psys_socket_owner* owners =
        (psys_socket_owner*)malloc(sizeof(psys_socket_owner) * 16384);
    int nowners = 0;
    if (owners) nowners = psys_build_socket_owners(owners, 16384);
    int n = 0;
    if (want_inet) {
        n += psys_parse_inet("/proc/net/tcp", 2, 1, out + n, cap - n,
                             owners, nowners);
        n += psys_parse_inet("/proc/net/tcp6", 10, 1, out + n, cap - n,
                             owners, nowners);
        n += psys_parse_inet("/proc/net/udp", 2, 2, out + n, cap - n,
                             owners, nowners);
        n += psys_parse_inet("/proc/net/udp6", 10, 2, out + n, cap - n,
                             owners, nowners);
    } else {
        n += psys_parse_unix(out + n, cap - n, owners, nowners);
    }
    free(owners);
    return n;
}

double psutil_sys_boot_time(void) {
    FILE* f = fopen("/proc/stat", "r");
    if (!f) return -1.0;
    char line[1024];
    double value = -1.0;
    while (fgets(line, sizeof(line), f)) {
        if (strncmp(line, "btime", 5) == 0) {
            if (sscanf(line + 5, "%lf", &value) != 1) value = -1.0;
            break;
        }
    }
    fclose(f);
    return value;
}

int psutil_sys_users(psutil_User* out, int cap) {
    if (!out || cap <= 0) return PSUTIL_UNSUPPORTED;
    setutent();
    int n = 0;
    struct utmp* u;
    while ((u = getutent()) != NULL && n < cap) {
        if (u->ut_type != USER_PROCESS) continue;
        if (u->ut_user[0] == '\0') continue;
        psutil_User* cur = &out[n];
        memset(cur, 0, sizeof(*cur));
        psys_copy(cur->name, sizeof(cur->name), u->ut_user);
        psys_copy(cur->terminal, sizeof(cur->terminal), u->ut_line);
        psys_copy(cur->host, sizeof(cur->host),
                  u->ut_host[0] == ':' ? "localhost" : u->ut_host);
        cur->started = (double)u->ut_tv.tv_sec;
        cur->pid = (int)u->ut_pid;
        n++;
    }
    endutent();
    return n;
}

#else

int psutil_sys_cpu_freq(psutil_CpuFreq* out, int cap) {
#if defined(__APPLE__)
    uint64_t hz = 0;
    size_t len = sizeof(hz);
    if (!out || cap <= 0) return PSUTIL_UNSUPPORTED;
    if (sysctlbyname("hw.cpufrequency", &hz, &len, NULL, 0) != 0 || hz == 0)
        return PSUTIL_UNSUPPORTED;
    out[0].current = (double)hz / 1000000.0;
    out[0].min = 0.0;
    out[0].max = 0.0;
    return 1;
#else
    (void)out; (void)cap;
    return PSUTIL_UNSUPPORTED;
#endif
}
int psutil_sys_getloadavg(double* out, int cap) {
#if defined(__APPLE__)
    if (!out || cap < 3) return PSUTIL_UNSUPPORTED;
    if (getloadavg(out, 3) != 3) return PSUTIL_UNSUPPORTED;
    return 3;
#else
    (void)out; (void)cap;
    return PSUTIL_UNSUPPORTED;
#endif
}

int psutil_sys_cpu_times(psutil_SysCpuTimes* out, int cap, int percpu) {
    (void)out; (void)cap; (void)percpu;
    return PSUTIL_UNSUPPORTED;
}
int psutil_sys_cpu_percent_seed(const psutil_SysCpuTimes* cur, int count) {
    (void)cur; (void)count;
    return PSUTIL_UNSUPPORTED;
}
int psutil_sys_cpu_percent(const psutil_SysCpuTimes* cur, int count,
                           double* out) {
    (void)cur; (void)count; (void)out;
    return PSUTIL_UNSUPPORTED;
}
int psutil_sys_cpu_times_percent_seed(const psutil_SysCpuTimes* cur,
                                      int count) {
    (void)cur; (void)count;
    return PSUTIL_UNSUPPORTED;
}
int psutil_sys_cpu_times_percent(const psutil_SysCpuTimes* cur, int count,
                                 psutil_CpuTimesPercent* out) {
    (void)cur; (void)count; (void)out;
    return PSUTIL_UNSUPPORTED;
}
int psutil_sys_cpu_count(int logical) {
    (void)logical;
    return PSUTIL_UNSUPPORTED;
}
int psutil_sys_cpu_stats(psutil_CpuStats* out) {
    (void)out;
    return PSUTIL_UNSUPPORTED;
}
int psutil_sys_virtual_memory(psutil_VirtualMemory* out) {
    (void)out;
    return PSUTIL_UNSUPPORTED;
}
int psutil_sys_swap_memory(psutil_SwapMemory* out) {
    (void)out;
    return PSUTIL_UNSUPPORTED;
}
int psutil_sys_disk_partitions(int all, psutil_Partition* out, int cap) {
    (void)all; (void)out; (void)cap;
    return PSUTIL_UNSUPPORTED;
}
int psutil_sys_disk_usage(const char* path, psutil_DiskUsage* out) {
    (void)path; (void)out;
    return PSUTIL_UNSUPPORTED;
}
int psutil_sys_disk_io_counters(int perdisk, psutil_DiskIO* out, int cap) {
    (void)perdisk; (void)out; (void)cap;
    return PSUTIL_UNSUPPORTED;
}
int psutil_sys_net_io_counters(int pernic, psutil_NetIO* out, int cap) {
    (void)pernic; (void)out; (void)cap;
    return PSUTIL_UNSUPPORTED;
}
int psutil_sys_net_if_addrs(psutil_NicAddress* out, int cap) {
    (void)out; (void)cap;
    return PSUTIL_UNSUPPORTED;
}
int psutil_sys_net_if_stats(psutil_NicStats* out, int cap) {
    (void)out; (void)cap;
    return PSUTIL_UNSUPPORTED;
}
int psutil_sys_net_connections(const char* kind, psutil_SysConnection* out,
                               int cap) {
    (void)kind; (void)out; (void)cap;
    return PSUTIL_UNSUPPORTED;
}
double psutil_sys_boot_time(void) {
    return -1.0;
}
int psutil_sys_users(psutil_User* out, int cap) {
    (void)out; (void)cap;
    return PSUTIL_UNSUPPORTED;
}

#endif
