#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <ctype.h>
#include <errno.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef _WIN32
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#endif

#if defined(__linux__)
#include <sys/resource.h>
#include <sys/sysmacros.h>
#endif

#if defined(__linux__) && defined(__GLIBC__)
#include <malloc.h>
#endif

#include "extra.h"
#include "psproc.h"
#include "psproc_query.h"

#define PSE_INVALID_ARG -5
#define PSE_ENV_MAX_BYTES (1024 * 1024)

typedef struct {
    char path[1024];
} pse_Path;

static void pse_copy(char* dst, int cap, const char* src) {
    if (!src || cap <= 0) return;
    int n = (int)strlen(src);
    if (n >= cap) n = cap - 1;
    memcpy(dst, src, (size_t)n);
    dst[n] = '\0';
}

static char* pse_trim(char* s) {
    while (*s && isspace((unsigned char)*s)) s++;
    char* end = s + strlen(s);
    while (end > s && isspace((unsigned char)end[-1])) *--end = '\0';
    return s;
}

static int pse_errno(int e) {
#if !defined(_WIN32)
    if (e == ENOENT || e == ESRCH) return PSUTIL_NO_PROC;
    if (e == EACCES || e == EPERM) return PSUTIL_ACCESS_DENIED;
    if (e == EINVAL || e == ENOSYS) return PSE_INVALID_ARG;
#endif
    (void)e;
    return PSE_INVALID_ARG;
}

static int pse_read_line(const char* path, char* buf, int cap) {
    FILE* f = fopen(path, "r");
    if (!f) return -1;
    if (!fgets(buf, cap, f)) {
        fclose(f);
        return -1;
    }
    fclose(f);
    return 0;
}

#if defined(__linux__)

static long pse_hz(void) {
    long hz = sysconf(_SC_CLK_TCK);
    return hz > 0 ? hz : 100;
}

static double pse_btime(void) {
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

static void pse_terminal_from_nr(unsigned long long nr, char* out, int cap) {
    out[0] = '\0';
    if (nr == 0) return;
    unsigned int maj = major((dev_t)nr);
    unsigned int min = minor((dev_t)nr);
    const char* dirs[2] = {"/dev/pts", "/dev"};
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
                pse_copy(out, cap, full);
                closedir(dp);
                return;
            }
        }
        closedir(dp);
    }
}

static const char* pse_status_name(char letter) {
    switch (letter) {
        case 'R': return "running";
        case 'S': return "sleeping";
        case 'D': return "disk-sleep";
        case 'Z': return "zombie";
        case 'T': return "stopped";
        case 't': return "tracing-stop";
        case 'X': case 'x': return "dead";
        case 'K': return "wake-kill";
        case 'W': return "waking";
        case 'P': return "parked";
        case 'I': return "idle";
        default: return "?";
    }
}

static int pse_status_fields(int pid, char* status, int status_cap,
                             unsigned long long uids[3],
                             unsigned long long gids[3]) {
    char path[256];
    char line[512];
    snprintf(path, sizeof(path), "/proc/%d/status", pid);
    FILE* f = fopen(path, "r");
    if (!f) return pse_errno(errno);
    int got_status = 0;
    int got_uid = 0;
    int got_gid = 0;
    while (fgets(line, sizeof(line), f)) {
        if (strncmp(line, "State:", 6) == 0) {
            char* p = line + 6;
            while (*p == ' ' || *p == '\t') p++;
            pse_copy(status, status_cap, pse_status_name(p[0]));
            got_status = 1;
        } else if (strncmp(line, "Uid:", 4) == 0) {
            got_uid = sscanf(line + 4, "%llu %llu %llu", &uids[0], &uids[1],
                             &uids[2]) == 3;
        } else if (strncmp(line, "Gid:", 4) == 0) {
            got_gid = sscanf(line + 4, "%llu %llu %llu", &gids[0], &gids[1],
                             &gids[2]) == 3;
        }
        if (got_status && got_uid && got_gid) break;
    }
    fclose(f);
    return (got_status && got_uid && got_gid) ? PSUTIL_OK : PSUTIL_NO_PROC;
}

int psutil_extra_oneshot(int pid, psutil_OneShot* out) {
    if (!out || pid <= 0) return PSUTIL_NO_PROC;
    char path[256];
    char line[4096];
    snprintf(path, sizeof(path), "/proc/%d/stat", pid);
    if (pse_read_line(path, line, (int)sizeof(line)) != 0) {
        return pse_errno(errno);
    }
    char* lp = strchr(line, '(');
    char* rp = strrchr(line, ')');
    if (!lp || !rp || rp <= lp) return PSUTIL_NO_PROC;
    size_t name_len = (size_t)(rp - lp - 1);
    if (name_len >= sizeof(out->name)) name_len = sizeof(out->name) - 1;
    memcpy(out->name, lp + 1, name_len);
    out->name[name_len] = '\0';

    char* toks[40];
    int nt = 0;
    char* tok = strtok(rp + 2, " \t\n");
    while (tok && nt < 40) {
        toks[nt++] = tok;
        tok = strtok(NULL, " \t\n");
    }
    if (nt <= 19) return PSUTIL_NO_PROC;

    int rc = pse_status_fields(pid, out->status, (int)sizeof(out->status),
                               out->uids, out->gids);
    if (rc != PSUTIL_OK) return rc;

    double hz = (double)pse_hz();
    out->ppid = (int)strtol(toks[1], NULL, 10);
    out->num_threads = (int)strtol(toks[17], NULL, 10);
    out->create_time = pse_btime() +
                       (double)strtoull(toks[19], NULL, 10) / hz;
    out->user = (double)strtoull(toks[11], NULL, 10) / hz;
    out->system = (double)strtoull(toks[12], NULL, 10) / hz;
    out->children_user = (double)strtoull(toks[13], NULL, 10) / hz;
    out->children_system = (double)strtoull(toks[14], NULL, 10) / hz;
    out->iowait = (nt > 39)
        ? (double)strtoull(toks[39], NULL, 10) / hz
        : PSUTIL_NONE_F64;
    pse_terminal_from_nr(strtoull(toks[4], NULL, 10), out->terminal,
                         (int)sizeof(out->terminal));

    snprintf(path, sizeof(path), "/proc/%d/statm", pid);
    unsigned long long size = 0;
    unsigned long long resident = 0;
    unsigned long long shared = 0;
    FILE* f = fopen(path, "r");
    if (!f) return pse_errno(errno);
    if (fscanf(f, "%llu %llu %llu", &size, &resident, &shared) != 3) {
        fclose(f);
        return PSUTIL_NO_PROC;
    }
    fclose(f);
    unsigned long long page = (unsigned long long)sysconf(_SC_PAGESIZE);
    if (page == 0) page = 4096;
    out->vms = size * page;
    out->rss = resident * page;
    out->shared = shared * page;
    out->text = PSUTIL_NONE_U64;
    out->lib = PSUTIL_NONE_U64;
    out->data = PSUTIL_NONE_U64;
    out->dirty = PSUTIL_NONE_U64;
    return PSUTIL_OK;
}

static long long pse_rlim_value(rlim_t value) {
    if (value == RLIM_INFINITY) return -1;
    return (long long)value;
}

static rlim_t pse_rlim_from(long long value) {
    if (value < 0) return RLIM_INFINITY;
    return (rlim_t)value;
}

int psutil_extra_rlimit(int pid, int resource, psutil_Rlimit* out) {
#if defined(__linux__)
    if (!out || pid <= 0) return PSUTIL_NO_PROC;
    struct rlimit lim;
    memset(&lim, 0, sizeof(lim));
    if (prlimit((pid_t)pid, resource, NULL, &lim) != 0) {
        return pse_errno(errno);
    }
    out->soft = pse_rlim_value(lim.rlim_cur);
    out->hard = pse_rlim_value(lim.rlim_max);
    return PSUTIL_OK;
#else
    (void)pid; (void)resource; (void)out;
    return PSUTIL_UNSUPPORTED;
#endif
}

int psutil_extra_set_rlimit(int pid, int resource, long long soft,
                            long long hard) {
#if defined(__linux__)
    if (pid <= 0) return PSUTIL_NO_PROC;
    if (soft >= 0 && hard >= 0 && soft > hard) return PSE_INVALID_ARG;
    struct rlimit lim;
    lim.rlim_cur = pse_rlim_from(soft);
    lim.rlim_max = pse_rlim_from(hard);
    if (prlimit((pid_t)pid, resource, &lim, NULL) != 0) {
        return pse_errno(errno);
    }
    return PSUTIL_OK;
#else
    (void)pid; (void)resource; (void)soft; (void)hard;
    return PSUTIL_UNSUPPORTED;
#endif
}

int psutil_extra_environ(int pid, psutil_EnvVar* out, int cap) {
#if defined(__linux__)
    if (pid <= 0 || !out) return PSUTIL_NO_PROC;
    char path[256];
    snprintf(path, sizeof(path), "/proc/%d/environ", pid);
    FILE* f = fopen(path, "rb");
    if (!f) return pse_errno(errno);
    char* data = (char*)malloc(PSE_ENV_MAX_BYTES);
    if (!data) {
        fclose(f);
        return PSUTIL_UNSUPPORTED;
    }
    size_t total = 0;
    while (total < PSE_ENV_MAX_BYTES) {
        size_t got = fread(data + total, 1, 4096, f);
        if (got == 0) break;
        total += got;
    }
    fclose(f);

    int count = 0;
    size_t pos = 0;
    while (pos < total) {
        size_t end = pos;
        while (end < total && data[end] != '\0') end++;
        if (end == pos) break;
        char* eq = (char*)memchr(data + pos, '=', end - pos);
        if (eq && eq != data + pos && count < cap) {
            size_t eq_off = (size_t)(eq - data);
            size_t key_len = eq_off - pos;
            size_t val_len = end - (eq_off + 1);
            if (key_len >= sizeof(out[count].key)) {
                key_len = sizeof(out[count].key) - 1;
            }
            if (val_len >= sizeof(out[count].value)) {
                val_len = sizeof(out[count].value) - 1;
            }
            memcpy(out[count].key, data + pos, key_len);
            out[count].key[key_len] = '\0';
            memcpy(out[count].value, eq + 1, val_len);
            out[count].value[val_len] = '\0';
            count++;
        }
        pos = end + 1;
    }
    free(data);
    return count;
#else
    (void)pid; (void)out; (void)cap;
    return PSUTIL_UNSUPPORTED;
#endif
}
#endif

static int pse_read_text(const char* path, char* buf, int cap) {
    if (pse_read_line(path, buf, cap) != 0) return -1;
    size_t n = strlen(buf);
    while (n && (buf[n - 1] == '\n' || buf[n - 1] == '\r')) buf[--n] = '\0';
    return 0;
}

static int pse_read_i64_file(const char* path, long long* out) {
    char buf[256];
    if (pse_read_text(path, buf, (int)sizeof(buf)) != 0) return -1;
    char* end = NULL;
    long long value = strtoll(buf, &end, 10);
    if (end == buf) return -1;
    *out = value;
    return 0;
}

static int pse_read_f64_file(const char* path, double* out) {
    char buf[256];
    if (pse_read_text(path, buf, (int)sizeof(buf)) != 0) return -1;
    char* end = NULL;
    double value = strtod(buf, &end);
    if (end == buf) return -1;
    *out = value;
    return 0;
}

static int pse_path_cmp(const void* a, const void* b) {
    const pse_Path* pa = (const pse_Path*)a;
    const pse_Path* pb = (const pse_Path*)b;
    return strcmp(pa->path, pb->path);
}

static int pse_duplicate_coretemp(const char* dir, const char* base) {
    const char* mark = "/hwmon/";
    const char* p = strstr(dir, mark);
    if (strncmp(dir, "/sys/devices/platform/coretemp.", 31) != 0 || !p) {
        return 0;
    }
    char alt[1200];
    snprintf(alt, sizeof(alt), "/sys/class/hwmon/%s/%s_input",
             p + strlen(mark), base);
    struct stat st;
    return stat(alt, &st) == 0;
}

static void pse_collect_from_dir(const char* dir, const char* prefix,
                                 pse_Path* out, int* count, int cap) {
    DIR* dp = opendir(dir);
    if (!dp) return;
    size_t plen = strlen(prefix);
    struct dirent* e;
    while ((e = readdir(dp)) != NULL) {
        const char* n = e->d_name;
        size_t len = strlen(n);
        const char* suffix = "_input";
        size_t slen = strlen(suffix);
        if (len <= slen || strncmp(n, prefix, plen) != 0 ||
            strcmp(n + len - slen, suffix) != 0) {
            continue;
        }
        if (*count >= cap) break;
        char base[512];
        size_t keep = len - slen;
        if (keep >= sizeof(base)) keep = sizeof(base) - 1;
        memcpy(base, n, keep);
        base[keep] = '\0';
        if (pse_duplicate_coretemp(dir, base)) continue;
        snprintf(out[*count].path, sizeof(out[*count].path), "%s/%s", dir,
                 base);
        (*count)++;
    }
    closedir(dp);
}

static void pse_collect_bases(const char* prefix, pse_Path* out, int* count,
                              int cap) {
    DIR* dp = opendir("/sys/class/hwmon");
    if (dp) {
        struct dirent* e;
        while ((e = readdir(dp)) != NULL) {
            if (strncmp(e->d_name, "hwmon", 5) != 0) continue;
            char dir[512];
            snprintf(dir, sizeof(dir), "/sys/class/hwmon/%s", e->d_name);
            pse_collect_from_dir(dir, prefix, out, count, cap);
            char dev[600];
            snprintf(dev, sizeof(dev), "%s/device", dir);
            pse_collect_from_dir(dev, prefix, out, count, cap);
        }
        closedir(dp);
    }
    if (strcmp(prefix, "temp") == 0) {
        DIR* plat = opendir("/sys/devices/platform");
        if (plat) {
            struct dirent* e;
            while ((e = readdir(plat)) != NULL) {
                if (strncmp(e->d_name, "coretemp.", 9) != 0) continue;
                char root[768];
                snprintf(root, sizeof(root), "/sys/devices/platform/%s/hwmon",
                         e->d_name);
                DIR* hd = opendir(root);
                if (!hd) continue;
                struct dirent* he;
                while ((he = readdir(hd)) != NULL) {
                    if (strncmp(he->d_name, "hwmon", 5) != 0) continue;
                    char dir[1024];
                    snprintf(dir, sizeof(dir), "%s/%s", root, he->d_name);
                    pse_collect_from_dir(dir, prefix, out, count, cap);
                }
                closedir(hd);
            }
            closedir(plat);
        }
    }
    qsort(out, (size_t)*count, sizeof(out[0]), pse_path_cmp);
    int unique = 0;
    for (int i = 0; i < *count; i++) {
        if (unique == 0 || strcmp(out[i].path, out[unique - 1].path) != 0) {
            out[unique++] = out[i];
        }
    }
    *count = unique;
}

static void pse_sensor_id(const char* base, char* out, int cap) {
    const char* p = strrchr(base, '/');
    pse_copy(out, cap, p ? p + 1 : base);
}

static void pse_parent_path(const char* path, char* out, int cap) {
    const char* p = strrchr(path, '/');
    size_t n = p ? (size_t)(p - path) : 1;
    if (n >= (size_t)cap) n = (size_t)cap - 1;
    memcpy(out, path, n);
    out[n] = '\0';
}

static double pse_celsius(double value, int fahrenheit) {
    if (!fahrenheit) return value;
    return value * 9.0 / 5.0 + 32.0;
}

int psutil_extra_sensors_temperatures(int fahrenheit, psutil_Shwtemp* out,
                                      int cap) {
#if defined(__linux__)
    pse_Path bases[PSUTIL_MAX_SHWTEMP];
    int count = 0;
    pse_collect_bases("temp", bases, &count, PSUTIL_MAX_SHWTEMP);
    int written = 0;
    for (int i = 0; i < count && written < cap; i++) {
        const char* base = bases[i].path;
        char file[1200];
        double current = 0.0;
        snprintf(file, sizeof(file), "%s_input", base);
        if (pse_read_f64_file(file, &current) != 0) continue;
        char parent[1024];
        pse_parent_path(base, parent, (int)sizeof(parent));
        char name_file[1200];
        char label_file[1200];
        snprintf(name_file, sizeof(name_file), "%s/name", parent);
        snprintf(label_file, sizeof(label_file), "%s_label", base);
        char chip[256];
        char label[256];
        if (pse_read_text(name_file, chip, (int)sizeof(chip)) != 0) continue;
        if (pse_read_text(label_file, label, (int)sizeof(label)) != 0) {
            label[0] = '\0';
        }
        double high = PSUTIL_NONE_F64;
        double critical = PSUTIL_NONE_F64;
        snprintf(file, sizeof(file), "%s_max", base);
        if (pse_read_f64_file(file, &high) == 0) {
            high = pse_celsius(high / 1000.0, fahrenheit);
        }
        snprintf(file, sizeof(file), "%s_crit", base);
        if (pse_read_f64_file(file, &critical) == 0) {
            critical = pse_celsius(critical / 1000.0, fahrenheit);
        }
        if (high >= 0.0 && high != 0.0 && critical < 0.0) critical = high;
        if (critical >= 0.0 && critical != 0.0 && high < 0.0) high = critical;
        pse_copy(out[written].chip, (int)sizeof(out[written].chip),
                 pse_trim(chip));
        pse_sensor_id(base, out[written].name,
                      (int)sizeof(out[written].name));
        pse_copy(out[written].label, (int)sizeof(out[written].label),
                 pse_trim(label));
        out[written].current = pse_celsius(current / 1000.0, fahrenheit);
        out[written].high = high;
        out[written].critical = critical;
        written++;
    }
    return written;
#else
    (void)fahrenheit; (void)out; (void)cap;
    return PSUTIL_UNSUPPORTED;
#endif
}

int psutil_extra_sensors_fans(psutil_Fan* out, int cap) {
#if defined(__linux__)
    pse_Path bases[PSUTIL_MAX_SFAN];
    int count = 0;
    pse_collect_bases("fan", bases, &count, PSUTIL_MAX_SFAN);
    int written = 0;
    for (int i = 0; i < count && written < cap; i++) {
        const char* base = bases[i].path;
        char file[1200];
        long long speed = 0;
        snprintf(file, sizeof(file), "%s_input", base);
        if (pse_read_i64_file(file, &speed) != 0) continue;
        char parent[1024];
        pse_parent_path(base, parent, (int)sizeof(parent));
        char name_file[1200];
        snprintf(name_file, sizeof(name_file), "%s/name", parent);
        char chip[256];
        if (pse_read_text(name_file, chip, (int)sizeof(chip)) != 0) continue;
        char label_file[1200];
        char label[256];
        snprintf(label_file, sizeof(label_file), "%s_label", base);
        if (pse_read_text(label_file, label, (int)sizeof(label)) != 0 ||
            pse_trim(label)[0] == '\0') {
            pse_sensor_id(base, label, (int)sizeof(label));
        }
        pse_copy(out[written].chip, (int)sizeof(out[written].chip),
                 pse_trim(chip));
        pse_copy(out[written].name, (int)sizeof(out[written].name),
                 pse_trim(label));
        out[written].speed = (int)speed;
        written++;
    }
    return written;
#else
    (void)out; (void)cap;
    return PSUTIL_UNSUPPORTED;
#endif
}

static int pse_contains_battery(const char* name) {
    const char* p = name;
    while (*p) {
        if (*p == 'B' && strncmp(p, "BAT", 3) == 0) return 1;
        if (tolower((unsigned char)*p) == 'b') {
            const char* q = p;
            const char* word = "battery";
            while (*q && *word && tolower((unsigned char)*q) == *word) {
                q++;
                word++;
            }
            if (*word == '\0') return 1;
        }
        p++;
    }
    return 0;
}

static int pse_multi_i64(const char* root, const char* a, const char* b,
                         long long* out) {
    char path[1200];
    snprintf(path, sizeof(path), "%s/%s", root, a);
    if (pse_read_i64_file(path, out) == 0) return 0;
    snprintf(path, sizeof(path), "%s/%s", root, b);
    return pse_read_i64_file(path, out);
}

static void pse_lower(char* s) {
    for (; *s; s++) *s = (char)tolower((unsigned char)*s);
}

int psutil_extra_sensors_battery(psutil_Battery* out, int cap) {
#if defined(__linux__)
    if (!out || cap <= 0) return PSUTIL_UNSUPPORTED;
    const char* root_dir = "/sys/class/power_supply";
    DIR* dp = opendir(root_dir);
    if (!dp) return 0;
    char names[256][256];
    int n = 0;
    struct dirent* e;
    while ((e = readdir(dp)) != NULL && n < 256) {
        if (!pse_contains_battery(e->d_name)) continue;
        pse_copy(names[n], (int)sizeof(names[n]), e->d_name);
        n++;
    }
    closedir(dp);
    if (n == 0) return 0;
    int selected = 0;
    for (int i = 1; i < n; i++) {
        if (strcmp(names[i], names[selected]) < 0) selected = i;
    }
    char root[1200];
    snprintf(root, sizeof(root), "%s/%s", root_dir, names[selected]);

    long long energy_now = 0;
    long long energy_full = 0;
    long long power_now = 0;
    long long time_to_empty = 0;
    int has_now = pse_multi_i64(root, "energy_now", "charge_now",
                                &energy_now) == 0;
    int has_full = pse_multi_i64(root, "energy_full", "charge_full",
                                 &energy_full) == 0;
    int has_power = pse_multi_i64(root, "power_now", "current_now",
                                  &power_now) == 0;
    char file[1400];
    snprintf(file, sizeof(file), "%s/time_to_empty_now", root);
    int has_empty = pse_read_i64_file(file, &time_to_empty) == 0;

    double percent = -1.0;
    if (has_full && has_now && energy_full != 0) {
        percent = 100.0 * (double)energy_now / (double)energy_full;
    } else {
        snprintf(file, sizeof(file), "%s/capacity", root);
        long long capacity = 0;
        if (pse_read_i64_file(file, &capacity) == 0) percent = (double)capacity;
    }
    if (percent < 0.0) return 0;

    int plugged = -1;
    long long online = 0;
    if (pse_multi_i64(root_dir, "AC0/online", "AC/online", &online) == 0) {
        plugged = online == 1 ? 1 : 0;
    } else {
        snprintf(file, sizeof(file), "%s/status", root);
        char status[128];
        if (pse_read_text(file, status, (int)sizeof(status)) == 0) {
            char* s = pse_trim(status);
            pse_lower(s);
            if (strcmp(s, "discharging") == 0) plugged = 0;
            else if (strcmp(s, "charging") == 0 || strcmp(s, "full") == 0) {
                plugged = 1;
            }
        }
    }

    int secsleft = PSUTIL_POWER_TIME_UNKNOWN;
    if (plugged == 1) {
        secsleft = PSUTIL_POWER_TIME_UNLIMITED;
    } else if (has_now && has_power && power_now != 0) {
        secsleft = (int)((double)energy_now / llabs(power_now) * 3600.0);
    } else if (has_empty) {
        secsleft = (int)(time_to_empty * 60);
        if (secsleft < 0) secsleft = PSUTIL_POWER_TIME_UNKNOWN;
    }

    out[0].percent = percent;
    out[0].secsleft = secsleft;
    out[0].power_plugged = plugged;
    return 1;
#else
    (void)out; (void)cap;
    return PSUTIL_UNSUPPORTED;
#endif
}

int psutil_extra_heap_info(psutil_HeapInfo* out) {
#if defined(__linux__) && defined(__GLIBC__)
    if (!out) return PSE_INVALID_ARG;
    struct mallinfo2 info = mallinfo2();
    out->heap_used = (unsigned long long)info.uordblks;
    out->mmap_used = (unsigned long long)info.hblkhd;
    out->heap_count = 0;
    return PSUTIL_OK;
#else
    (void)out;
    return PSUTIL_UNSUPPORTED;
#endif
}

int psutil_extra_heap_trim(void) {
#if defined(__linux__) && defined(__GLIBC__)
    malloc_trim(0);
    return PSUTIL_OK;
#else
    return PSUTIL_UNSUPPORTED;
#endif
}

int psutil_extra_win_service_iter(psutil_WindowsService* out, int cap) {
    (void)out;
    (void)cap;
    return PSUTIL_UNSUPPORTED;
}

int psutil_extra_win_service_get(const char* name, psutil_WindowsService* out) {
    (void)name;
    (void)out;
    return PSUTIL_UNSUPPORTED;
}

// extra.h 约定：非 Linux 平台保留同名入口并返回 PSUTIL_UNSUPPORTED，避免伪造数值。
// 以上 4 个原定义位于前部 #if defined(__linux__) 块内，macOS/Windows 链接会缺符号。
#if !defined(__linux__)
int psutil_extra_oneshot(int pid, psutil_OneShot* out) {
    (void)pid; (void)out;
    return PSUTIL_UNSUPPORTED;
}
int psutil_extra_rlimit(int pid, int resource, psutil_Rlimit* out) {
    (void)pid; (void)resource; (void)out;
    return PSUTIL_UNSUPPORTED;
}
int psutil_extra_set_rlimit(int pid, int resource, long long soft,
                            long long hard) {
    (void)pid; (void)resource; (void)soft; (void)hard;
    return PSUTIL_UNSUPPORTED;
}
int psutil_extra_environ(int pid, psutil_EnvVar* out, int cap) {
    (void)pid; (void)out; (void)cap;
    return PSUTIL_UNSUPPORTED;
}
#endif
