module psutil

// 缺失 .o 时 V 会自动编译相邻的 psproc.c
#flag -I @DIR/
#flag @DIR/psproc.o
#include "@DIR/psproc.h"

const max_pid_list = 65536

fn C.psutil_os_pids(&int, int) int
fn C.psutil_os_pid_ppid(int) int
fn C.psutil_os_pid_exists(int) int
fn C.psutil_os_process_name(int, &char, int) int

fn psproc_error(code int) string {
    if code == -2 {
        return 'process enumeration is not supported on this platform'
    }
    return 'cannot enumerate processes'
}

fn pids_from_os() ![]int {
    mut raw := []int{len: max_pid_list}
    n := unsafe { C.psutil_os_pids(&raw[0], max_pid_list) }
    if n < 0 {
        return error(psproc_error(n))
    }
    mut list := []int{cap: n}
    for i in 0 .. n {
        list << raw[i]
    }
    return list
}

fn ppid_of(pid int) int {
    return C.psutil_os_pid_ppid(pid)
}

fn os_pid_exists(pid int) bool {
    return C.psutil_os_pid_exists(pid) == 1
}

pub fn process_name(pid int) !string {
    mut buf := []char{len: 256}
    ret := unsafe { C.psutil_os_process_name(pid, &buf[0], 256) }
    if ret != 0 {
        return error('cannot read process name')
    }
    return unsafe { cstring_to_vstring(&buf[0]) }
}
