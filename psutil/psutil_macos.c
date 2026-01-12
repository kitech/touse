#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <libproc.h>
#include <sys/sysctl.h>
#include <pwd.h>
#include <errno.h>
#include <signal.h>

/* Structure to hold process information */
typedef struct {
    int pid;
    char name[256];
    char path[PROC_PIDPATHINFO_MAXSIZE];
    int ppid;
    char user[64];
    char **arguments;  /* Process arguments array */
    int arg_count;     /* Number of arguments */
} ProcessInfo;

/* Get process command line arguments */
int psutil_get_process_arguments(int pid, char ***args, int *arg_count) {
    if (pid <= 0) return -1;
    
    int mib[3] = {CTL_KERN, KERN_PROCARGS2, pid};
    size_t size = 0;
    
    /* Get the size needed */
    if (sysctl(mib, 3, NULL, &size, NULL, 0) == -1) {
        return -1;
    }
    
    if (size == 0) return -1;
    
    /* Allocate buffer for process arguments */
    char *buffer = malloc(size);
    if (!buffer) return -1;
    
    /* Get process arguments */
    if (sysctl(mib, 3, buffer, &size, NULL, 0) == -1) {
        free(buffer);
        return -1;
    }
    
    /* Parse the arguments buffer */
    int argc = *(int *)buffer;
    char *arg_start = buffer + sizeof(int);
    
    /* Skip executable path */
    while (*arg_start != '\0') arg_start++;
    arg_start++; /* Skip null terminator */
    
    /* Allocate array for arguments */
    char **arguments = malloc((argc + 1) * sizeof(char *));
    if (!arguments) {
        free(buffer);
        return -1;
    }
    
    /* Extract individual arguments */
    for (int i = 0; i < argc; i++) {
        arguments[i] = strdup(arg_start);
        if (!arguments[i]) {
            /* Cleanup on failure */
            for (int j = 0; j < i; j++) free(arguments[j]);
            free(arguments);
            free(buffer);
            return -1;
        }
        arg_start += strlen(arg_start) + 1;
    }
    arguments[argc] = NULL; /* NULL terminate the array */
    
    *args = arguments;
    *arg_count = argc;
    free(buffer);
    return 0;
}

/* Free process arguments memory */
void psutil_free_arguments(char **args, int count) {
    if (!args) return;
    
    for (int i = 0; i < count; i++) {
        if (args[i]) free(args[i]);
    }
    free(args);
}

/* Get all running processes */
int psutil_get_all_processes_duped(ProcessInfo** processes, int* count) {
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t size;
    
    /* Get size needed */
    if (sysctl(mib, 4, NULL, &size, NULL, 0) == -1) {
        return -1;
    }
    
    int proc_count = size / sizeof(struct kinfo_proc);
    struct kinfo_proc* proc_list = malloc(size);
    if (!proc_list) {
        return -1;
    }
    
    /* Get process list */
    if (sysctl(mib, 4, proc_list, &size, NULL, 0) == -1) {
        free(proc_list);
        return -1;
    }
    
    /* Allocate memory for ProcessInfo array */
    ProcessInfo* result = malloc(proc_count * sizeof(ProcessInfo));
    if (!result) {
        free(proc_list);
        return -1;
    }
    
    int valid_count = 0;
    for (int i = 0; i < proc_count; i++) {
        int pid = proc_list[i].kp_proc.p_pid;
        
        /* Skip kernel process (pid 0) */
        if (pid <= 0) continue;
        
        ProcessInfo* info = &result[valid_count];
        info->pid = pid;
        info->ppid = proc_list[i].kp_eproc.e_ppid;
        info->arguments = NULL;
        info->arg_count = 0;
        
        /* Get process name */
        strncpy(info->name, proc_list[i].kp_proc.p_comm, sizeof(info->name) - 1);
        info->name[sizeof(info->name) - 1] = '\0';
        
        /* Get executable path */
        if (proc_pidpath(pid, info->path, sizeof(info->path)) <= 0) {
            info->path[0] = '\0';
        }
        
        /* Get username */
        struct passwd* pwd = getpwuid(proc_list[i].kp_eproc.e_ucred.cr_uid);
        if (pwd) {
            strncpy(info->user, pwd->pw_name, sizeof(info->user) - 1);
            info->user[sizeof(info->user) - 1] = '\0';
        } else {
            snprintf(info->user, sizeof(info->user), "%d", 
                     proc_list[i].kp_eproc.e_ucred.cr_uid);
        }
        
        valid_count++;
    }
    
    *processes = result;
    *count = valid_count;
    
    free(proc_list);
    return 0;
}

/* Get process executable path by PID */
int psutil_get_process_path(int pid, char* buffer, size_t buffer_size) {
    if (pid <= 0 || !buffer || buffer_size == 0) {
        return -1;
    }
    
    int ret = proc_pidpath(pid, buffer, buffer_size);
    if (ret <= 0) {
        return -1;
    }
    
    return 0;
}

/* Get process name by PID */
int psutil_get_process_name(int pid, char* buffer, size_t buffer_size) {
    if (pid <= 0 || !buffer || buffer_size == 0) {
        return -1;
    }
    
    struct proc_bsdinfo proc;
    if (proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &proc, sizeof(proc)) <= 0) {
        return -1;
    }
    
    strncpy(buffer, proc.pbi_name, buffer_size - 1);
    buffer[buffer_size - 1] = '\0';
    
    return 0;
}

/* Free process list memory */
void psutil_free_processes_duped(ProcessInfo* processes) {
    if (processes) {
        free(processes);
    }
}

/* Free individual process info including arguments */
void psutil_free_process_info(ProcessInfo* info) {
    if (!info) return;
    
    if (info->arguments) {
        psutil_free_arguments(info->arguments, info->arg_count);
    }
}

/* Get current process PID */
int psutil_get_current_pid(void) {
    return getpid();
}

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <libproc.h>
#include <sys/sysctl.h>
#include <pwd.h>
#include <errno.h>
#include <signal.h>

/* ... 其他函数保持不变 ... */

/* Check if process exists - improved version */
int psutil_process_exists_duped(int pid) {
    if (pid <= 0) {
        return 0;
    }
    
    // Method 1: Try to get process info using proc_pidinfo
    struct proc_bsdinfo proc;
    int ret = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &proc, sizeof(proc));
    if (ret > 0) {
        return 1;  // Process exists
    }
    
    // Method 2: Try to get process path (alternative method)
    char pathbuf[PROC_PIDPATHINFO_MAXSIZE];
    ret = proc_pidpath(pid, pathbuf, sizeof(pathbuf));
    if (ret > 0) {
        return 1;  // Process exists
    }
    
    // Method 3: Use kill(pid, 0) to check if process exists
    if (kill(pid, 0) == 0) {
        return 1;  // Process exists
    }
    
    // Check errno to determine if process doesn't exist or we just lack permissions
    if (errno == ESRCH) {
        return 0;  // No such process
    }
    
    // For other errors (like EPERM), process might still exist
    // Try one more method: check via sysctl
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, pid};
    struct kinfo_proc info;
    size_t size = sizeof(info);
    
    if (sysctl(mib, 4, &info, &size, NULL, 0) == 0) {
        if (size > 0) {
            return 1;  // Process exists
        }
    }
    
    return 0;  // Process likely doesn't exist
}

/* ... 其他函数保持不变 ... */
// 更新后的总行数：约250行

/* Get full process info including arguments */
int psutil_get_full_process_info(int pid, ProcessInfo* info) {
    if (pid <= 0 || !info) {
        return -1;
    }
    
    /* Get basic info */
    if (psutil_get_process_name(pid, info->name, sizeof(info->name)) != 0) {
        return -1;
    }
    
    if (psutil_get_process_path(pid, info->path, sizeof(info->path)) != 0) {
        info->path[0] = '\0';
    }
    
    /* Get process BSD info for PPID and user */
    struct proc_bsdinfo proc;
    if (proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &proc, sizeof(proc)) <= 0) {
        return -1;
    }
    
    info->pid = pid;
    info->ppid = proc.pbi_ppid;
    
    /* Get username */
    struct passwd* pwd = getpwuid(proc.pbi_uid);
    if (pwd) {
        strncpy(info->user, pwd->pw_name, sizeof(info->user) - 1);
        info->user[sizeof(info->user) - 1] = '\0';
    } else {
        snprintf(info->user, sizeof(info->user), "%d", proc.pbi_uid);
    }
    
    /* Get arguments */
    info->arguments = NULL;
    info->arg_count = 0;
    if (psutil_get_process_arguments(pid, &info->arguments, &info->arg_count) != 0) {
        /* Arguments may not be available for all processes */
        info->arguments = NULL;
        info->arg_count = 0;
    }
    
    return 0;
}
// Total lines: 239
