module psutil

import os
import arrays
import vcp

// pid => ppid
pub fn pids() map[int]int {
    res := map[int]int{}
    files := os.ls("/proc") or {panic(err)}
    for file in files {
        if !file.is_digit() { continue }
        lines := os.read_file("/proc/$file/stat") or {continue}
        assert lines.len>0, file
        arr := lines.all_after(')').split(' ')
        ppid := arr[2].int()
        pid := file.int()
        res[pid] = ppid
    }
    return res
}

pub fn children(pid int, recu bool) []int{
    res := []int{}
    for k,v in pids() {
        if v == pid { res << k }
    }
    return res
}

pub fn cmdline(pid int) string {
    file := "/proc/$pid/cmdline"
    bcc := os.read_file(file) or {vcp.error(err.str())}
    scc := ''
    for c in bcc { scc += if c==0 {' '} else { c.repeat(1) } }
    return scc
}
pub fn executable(pid int) string {
    file := "/proc/$pid/exe"
    return os.real_path(file)
}

pub fn wkdir(pid int) string {
    file := "/proc/$pid/cwd"
    return os.real_path(file)
}
