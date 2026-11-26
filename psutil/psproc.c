#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "psproc.h"

static int psutil_int_cmp(const void* a, const void* b) {
    int x = *(const int*)a;
    int y = *(const int*)b;
    return (x > y) - (x < y);
}

static void psutil_copy_name(char* dst, int cap, const char* src) {
    if (!src || cap <= 0) return;
    int n = (int)strlen(src);
    if (n >= cap) n = cap - 1;
    memcpy(dst, src, (size_t)n);
    dst[n] = '\0';
}

#if defined(__linux__)
#include <dirent.h>
#include <unistd.h>

static int psutil_stat_field(int pid, int idx, char* buf, int cap) {
    char path[256];
    char line[1024];
    snprintf(path, sizeof(path), "/proc/%d/stat", pid);
    FILE* f = fopen(path, "r");
    if (!f) return 0;
    if (!fgets(line, sizeof(line), f)) {
        fclose(f);
        return 0;
    }
    fclose(f);
    char* p = strrchr(line, ')');
    if (!p) return 0;
    char* tok = strtok(p + 2, " \t\n");
    int i = 0;
    while (tok && i < idx) {
        tok = strtok(NULL, " \t\n");
        i++;
    }
    if (!tok) return 0;
    psutil_copy_name(buf, cap, tok);
    return 1;
}

int psutil_os_pids(int* out, int cap) {
    DIR* d = opendir("/proc");
    if (!d) return -1;
    int n = 0;
    struct dirent* e;
    while ((e = readdir(d)) != NULL && n < cap) {
        char* end = NULL;
        long pid = strtol(e->d_name, &end, 10);
        if (pid <= 0 || *end != '\0') continue;
        out[n++] = (int)pid;
    }
    closedir(d);
    qsort(out, (size_t)n, sizeof(int), psutil_int_cmp);
    return n;
}

int psutil_os_pid_ppid(int pid) {
    char buf[64];
    if (!psutil_stat_field(pid, 1, buf, sizeof(buf))) return -1;
    return atoi(buf);
}

int psutil_os_pid_exists(int pid) {
    char path[256];
    snprintf(path, sizeof(path), "/proc/%d", pid);
    return access(path, F_OK) == 0 ? 1 : 0;
}

int psutil_os_process_name(int pid, char* out, int cap) {
    char path[256];
    char line[512];
    snprintf(path, sizeof(path), "/proc/%d/comm", pid);
    FILE* f = fopen(path, "r");
    if (!f) return -1;
    if (!fgets(line, sizeof(line), f)) {
        fclose(f);
        return -1;
    }
    fclose(f);
    size_t len = strlen(line);
    while (len && (line[len - 1] == '\n' || line[len - 1] == '\r')) line[--len] = '\0';
    psutil_copy_name(out, cap, line);
    return 0;
}

#elif defined(__APPLE__)
#include <libproc.h>

int psutil_os_pids(int* out, int cap) {
    int bytes = proc_listpids(PROC_ALLPIDS, 0, NULL, 0);
    if (bytes <= 0) return -1;
    int* buf = (int*)malloc((size_t)bytes);
    if (!buf) return -1;
    int got = proc_listpids(PROC_ALLPIDS, 0, buf, bytes);
    if (got <= 0) {
        free(buf);
        return -1;
    }
    int n = 0;
    int total = got / (int)sizeof(int);
    for (int i = 0; i < total && n < cap; i++) {
        if (buf[i] > 0) out[n++] = buf[i];
    }
    free(buf);
    qsort(out, (size_t)n, sizeof(int), psutil_int_cmp);
    return n;
}

static int psutil_bsd_info(int pid, struct proc_bsdinfo* info) {
    if (!info) return 0;
    memset(info, 0, sizeof(*info));
    int ret = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, info, (int)sizeof(*info));
    return ret == (int)sizeof(*info) ? 1 : 0;
}

int psutil_os_pid_ppid(int pid) {
    struct proc_bsdinfo info;
    if (!psutil_bsd_info(pid, &info)) return -1;
    return (int)info.pbi_ppid;
}

int psutil_os_pid_exists(int pid) {
    struct proc_bsdinfo info;
    return psutil_bsd_info(pid, &info) ? 1 : 0;
}

int psutil_os_process_name(int pid, char* out, int cap) {
    struct proc_bsdinfo info;
    if (!psutil_bsd_info(pid, &info)) return -1;
    psutil_copy_name(out, cap, info.pbi_name);
    return 0;
}

#elif defined(_WIN32)
#include <windows.h>
#include <tlhelp32.h>

int psutil_os_pids(int* out, int cap) {
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return -1;
    PROCESSENTRY32 pe;
    pe.dwSize = sizeof(pe);
    int n = 0;
    BOOL ok = Process32First(snap, &pe);
    while (ok && n < cap) {
        out[n++] = (int)pe.th32ProcessID;
        ok = Process32Next(snap, &pe);
    }
    CloseHandle(snap);
    qsort(out, (size_t)n, sizeof(int), psutil_int_cmp);
    return n;
}

static BOOL psutil_find_process(int pid, PROCESSENTRY32* pe) {
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return FALSE;
    pe->dwSize = sizeof(*pe);
    BOOL ok = Process32First(snap, pe);
    while (ok) {
        if ((int)pe->th32ProcessID == pid) {
            CloseHandle(snap);
            return TRUE;
        }
        ok = Process32Next(snap, pe);
    }
    CloseHandle(snap);
    return FALSE;
}

int psutil_os_pid_ppid(int pid) {
    PROCESSENTRY32 pe;
    if (!psutil_find_process(pid, &pe)) return -1;
    return (int)pe.th32ParentProcessID;
}

int psutil_os_pid_exists(int pid) {
    PROCESSENTRY32 pe;
    return psutil_find_process(pid, &pe) ? 1 : 0;
}

int psutil_os_process_name(int pid, char* out, int cap) {
    PROCESSENTRY32 pe;
    if (!psutil_find_process(pid, &pe)) return -1;
    psutil_copy_name(out, cap, pe.szExeFile);
    return 0;
}

#else
int psutil_os_pids(int* out, int cap) {
    (void)out;
    (void)cap;
    return -2;
}
int psutil_os_pid_ppid(int pid) {
    (void)pid;
    return -1;
}
int psutil_os_pid_exists(int pid) {
    (void)pid;
    return 0;
}
int psutil_os_process_name(int pid, char* out, int cap) {
    (void)pid;
    (void)out;
    (void)cap;
    return -1;
}
#endif
