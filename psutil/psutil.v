module psutil

import os
import vcp

// pids 返回当前进程 PID 列表，排序后输出，对齐 pypi psutil.pids()。
pub fn pids() ![]int {
    return pids_from_os()
}

// pids_map 保留旧 pid=>ppid 语义，按约定改名为 pids_map()。
pub fn pids_map() !map[int]int {
    res := map[int]int{}
    for pid in pids() or { return err } {
        ppid := ppid_of(pid)
        if ppid >= 0 {
            res[pid] = ppid
        }
    }
    return res
}

pub fn pid_exists(pid int) bool {
    return os_pid_exists(pid)
}

fn sort_ints(mut a []int) {
    for i in 1 .. a.len {
        mut j := i
        for j > 0 && a[j] < a[j - 1] {
            tmp := a[j]
            a[j] = a[j - 1]
            a[j - 1] = tmp
            j--
        }
    }
}

// children 对齐 pypi Process.children(recursive=False)。
pub fn children(pid int, recursive bool) ![]int {
    ppids := pids_map() or { return err }
    mut res := []int{}
    mut seen := map[int]bool{}
    mut stack := []int{}

    for k, v in ppids {
        if v == pid {
            stack << k
            seen[k] = true
        }
    }

    for stack.len > 0 {
        cur := stack.pop()
        res << cur
        if !recursive {
            continue
        }
        for k, v in ppids {
            if v == cur && !seen[k] {
                seen[k] = true
                stack << k
            }
        }
    }

    sort_ints(mut res)
    return res
}

// cmdline_list 对齐 pypi Process.cmdline()，返回真实参数数组。
pub fn cmdline_list(pid int) ![]string {
    $if linux {
        file := '/proc/$pid/cmdline'
        bcc := os.read_file(file) or { return error('cannot read cmdline: ' + err.msg()) }
        mut args := []string{}
        mut cur := ''
        for c in bcc {
            if c == 0 {
                args << cur
                cur = ''
            } else {
                cur += c.repeat(1)
            }
        }
        if cur != '' {
            args << cur
        }
        return args
    } $else {
        return error('cmdline_list is only implemented on Linux in this batch')
    }
}

// cmdline 保留旧行为，返回空格拼接的兼容字符串。
pub fn cmdline(pid int) string {
    args := cmdline_list(pid) or {
        vcp.error(err.str())
        return ''
    }
    return args.join(' ')
}

pub fn executable(pid int) string {
    file := "/proc/$pid/exe"
    return os.real_path(file)
}

pub fn wkdir(pid int) string {
    file := "/proc/$pid/cwd"
    return os.real_path(file)
}
