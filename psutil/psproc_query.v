module psutil

// 缺失 .o 时 V 会自动编译相邻的 psproc_query.c
#flag -I @DIR/
#flag @DIR/psproc_query.o
#include "@DIR/psproc_query.h"

const max_open_files = 4096
const max_maps = 4096
const max_conns = 4096
const none_u64 = 0xffffffffffffffff

@[typedef]
pub struct C.psutil_IOInfo {
    read_count  u64
    write_count u64
    read_bytes  u64
    write_bytes u64
    read_chars  i64
    write_chars i64
}

@[typedef]
pub struct C.psutil_MemFullInfo {
    rss    u64
    vms    u64
    shared u64
    text   u64
    lib    u64
    data   u64
    dirty  u64
    uss    i64
    pss    i64
    swap   i64
}

@[typedef]
pub struct C.psutil_OpenFile {
    fd       int
    path     [4096]char
    position i64
    flags    int
    mode     [16]char
}

@[typedef]
pub struct C.psutil_MapInfo {
    path          [4096]char
    addr          [128]char
    perms         [16]char
    rss           u64
    size          u64
    pss           i64
    shared_clean  u64
    shared_dirty  u64
    private_clean u64
    private_dirty u64
    referenced    u64
    anonymous     u64
    swap          i64
}

@[typedef]
pub struct C.psutil_ConnInfo {
    fd         int
    family     int
    typ        int
    laddr_ip   [128]char
    laddr_port int
    raddr_ip   [128]char
    raddr_port int
    status     [32]char
}

fn C.psutil_proc_exe(int, &char, int) int
fn C.psutil_proc_cwd(int, &char, int) int
fn C.psutil_proc_status(int, &char, int) int
fn C.psutil_proc_username(int, &char, int) int
fn C.psutil_proc_uids(int, &u64) int
fn C.psutil_proc_gids(int, &u64) int
fn C.psutil_proc_terminal(int, &char, int) int
fn C.psutil_proc_create_time(int, &f64) int
fn C.psutil_proc_cpu_times(int, &f64, &f64, &f64, &f64, &f64) int
fn C.psutil_proc_cpu_percent(int, f64, &f64) int
fn C.psutil_proc_ctx_switches(int, &u64, &u64) int
fn C.psutil_proc_num_threads(int) int
fn C.psutil_proc_num_fds(int) int
fn C.psutil_proc_num_handles(int) int
fn C.psutil_proc_nice(int, &int) int
fn C.psutil_proc_set_nice(int, int) int
fn C.psutil_proc_ionice(int, &int, &int) int
fn C.psutil_proc_set_ionice(int, int, int) int
fn C.psutil_proc_affinity(int, &u64, int, &int) int
fn C.psutil_proc_set_affinity(int, &u64, int) int
fn C.psutil_proc_io(int, &C.psutil_IOInfo) int
fn C.psutil_proc_mem_full(int, &C.psutil_MemFullInfo) int
fn C.psutil_proc_ram_total(&u64) int
fn C.psutil_proc_open_files(int, &C.psutil_OpenFile, int) int
fn C.psutil_proc_memory_maps(int, &C.psutil_MapInfo, int) int
fn C.psutil_proc_connections(int, &C.psutil_ConnInfo, int, int) int
fn C.psutil_proc_signal(int, int) int
fn C.psutil_proc_suspend(int) int
fn C.psutil_proc_resume(int) int
fn C.psutil_signal_term() int
fn C.psutil_signal_kill() int
fn C.psutil_signal_stop() int
fn C.psutil_signal_cont() int

fn qerr(pid int, code int, op string) ProcessError {
    return map_proc_err(pid, code, op)
}

fn opt_u64(v u64) ?u64 {
    return if v == none_u64 { none } else { v }
}

fn opt_i64(v i64) ?i64 {
    return if v < 0 { none } else { v }
}

fn opt_i64_u64(v i64) ?u64 {
    return if v < 0 { none } else { u64(v) }
}

fn new_str_buf() []char {
    return []char{len: 4096}
}

pub fn process_exe(pid int) !string {
    mut buf := new_str_buf()
    rc := unsafe { C.psutil_proc_exe(pid, &buf[0], 4096) }
    if rc != 0 { return qerr(pid, rc, 'exe') }
    return unsafe { cstring_to_vstring(&buf[0]) }
}

pub fn process_cwd(pid int) !string {
    mut buf := new_str_buf()
    rc := unsafe { C.psutil_proc_cwd(pid, &buf[0], 4096) }
    if rc != 0 { return qerr(pid, rc, 'cwd') }
    return unsafe { cstring_to_vstring(&buf[0]) }
}

pub fn process_status(pid int) !string {
    mut buf := []char{len: 64}
    rc := unsafe { C.psutil_proc_status(pid, &buf[0], 64) }
    if rc != 0 { return qerr(pid, rc, 'status') }
    return unsafe { cstring_to_vstring(&buf[0]) }
}

pub fn process_username(pid int) !string {
    mut buf := []char{len: 256}
    rc := unsafe { C.psutil_proc_username(pid, &buf[0], 256) }
    if rc != 0 { return qerr(pid, rc, 'username') }
    return unsafe { cstring_to_vstring(&buf[0]) }
}

pub struct IdTriplet {
pub:
    real      u64
    effective u64
    saved     u64
}

pub fn process_uids(pid int) !IdTriplet {
    mut raw := []u64{len: 3}
    rc := unsafe { C.psutil_proc_uids(pid, &raw[0]) }
    if rc != 0 { return qerr(pid, rc, 'uids') }
    return IdTriplet{real: raw[0], effective: raw[1], saved: raw[2]}
}

pub fn process_gids(pid int) !IdTriplet {
    mut raw := []u64{len: 3}
    rc := unsafe { C.psutil_proc_gids(pid, &raw[0]) }
    if rc != 0 { return qerr(pid, rc, 'gids') }
    return IdTriplet{real: raw[0], effective: raw[1], saved: raw[2]}
}

pub fn process_terminal(pid int) !string {
    mut buf := []char{len: 512}
    rc := unsafe { C.psutil_proc_terminal(pid, &buf[0], 512) }
    if rc != 0 { return qerr(pid, rc, 'terminal') }
    return unsafe { cstring_to_vstring(&buf[0]) }
}

pub fn process_create_time(pid int) !f64 {
    mut out := 0.0
    rc := unsafe { C.psutil_proc_create_time(pid, &out) }
    if rc != 0 { return qerr(pid, rc, 'create_time') }
    return out
}

pub struct CpuTimes {
pub:
    user            f64
    system          f64
    children_user   f64
    children_system f64
    iowait          ?f64
}

pub fn process_cpu_times(pid int) !CpuTimes {
    mut user := 0.0
    mut system := 0.0
    mut cuser := 0.0
    mut csystem := 0.0
    mut iowait := 0.0
    rc := unsafe { C.psutil_proc_cpu_times(pid, &user, &system, &cuser, &csystem, &iowait) }
    if rc != 0 { return qerr(pid, rc, 'cpu_times') }
    return CpuTimes{
        user: user
        system: system
        children_user: cuser
        children_system: csystem
        iowait: if iowait < 0 { none } else { iowait }
    }
}

pub fn process_cpu_percent_from_total(pid int, total f64) !f64 {
    mut out := 0.0
    rc := unsafe { C.psutil_proc_cpu_percent(pid, total, &out) }
    if rc != 0 { return qerr(pid, rc, 'cpu_percent') }
    return out
}

pub struct CtxSwitches {
pub:
    voluntary   u64
    involuntary u64
}

pub fn process_ctx_switches(pid int) !CtxSwitches {
    mut vol := u64(0)
    mut invol := u64(0)
    rc := unsafe { C.psutil_proc_ctx_switches(pid, &vol, &invol) }
    if rc != 0 { return qerr(pid, rc, 'num_ctx_switches') }
    return CtxSwitches{voluntary: vol, involuntary: invol}
}

pub fn process_num_threads(pid int) !int {
    n := C.psutil_proc_num_threads(pid)
    if n < 0 { return qerr(pid, n, 'num_threads') }
    return n
}

pub fn process_num_fds(pid int) !int {
    n := C.psutil_proc_num_fds(pid)
    if n < 0 { return qerr(pid, n, 'num_fds') }
    return n
}

pub fn process_num_handles(pid int) !int {
    n := C.psutil_proc_num_handles(pid)
    if n < 0 { return qerr(pid, n, 'num_handles') }
    return n
}

pub fn process_nice(pid int) !int {
    mut value := 0
    rc := unsafe { C.psutil_proc_nice(pid, &value) }
    if rc != 0 { return qerr(pid, rc, 'nice') }
    return value
}

pub fn process_set_nice(pid int, value int) ! {
    rc := C.psutil_proc_set_nice(pid, value)
    if rc != 0 { return qerr(pid, rc, 'nice(value)') }
}

pub struct Ionice {
pub:
    ioclass int
    value   int
}

pub fn process_ionice(pid int) !Ionice {
    mut ioclass := 0
    mut value := 0
    rc := unsafe { C.psutil_proc_ionice(pid, &ioclass, &value) }
    if rc != 0 { return qerr(pid, rc, 'ionice') }
    return Ionice{ioclass: ioclass, value: value}
}

pub fn process_set_ionice(pid int, ioclass int, value int) ! {
    rc := C.psutil_proc_set_ionice(pid, ioclass, value)
    if rc != 0 { return qerr(pid, rc, 'ionice(ioclass,value)') }
}

pub fn process_cpu_affinity(pid int) ![]int {
    mut mask := []u64{len: 1}
    mut count := 0
    rc := unsafe { C.psutil_proc_affinity(pid, &mask[0], 1, &count) }
    if rc != 0 { return qerr(pid, rc, 'cpu_affinity') }
    if count > 64 { count = 64 }
    mut res := []int{cap: count}
    for i := 0; i < 64 && res.len < count; i++ {
        if ((mask[0] >> u32(i)) & 1) != 0 { res << i }
    }
    return res
}

pub fn process_set_cpu_affinity(pid int, cpus []int) ! {
    if cpus.len == 0 {
        return proc_err(pid, err_invalid_arg, 'cpu_affinity(cpus)')
    }
    mut mask := u64(0)
    for cpu in cpus {
        if cpu >= 0 && cpu < 64 { mask |= u64(1) << u32(cpu) }
    }
    rc := unsafe { C.psutil_proc_set_affinity(pid, &mask, 1) }
    if rc != 0 { return qerr(pid, rc, 'cpu_affinity(cpus)') }
}

pub struct ProcessIo {
pub:
    read_count  u64
    write_count u64
    read_bytes  u64
    write_bytes u64
    read_chars  ?u64
    write_chars ?u64
}

pub fn process_io_counters(pid int) !ProcessIo {
    mut raw := C.psutil_IOInfo{}
    rc := unsafe { C.psutil_proc_io(pid, &raw) }
    if rc != 0 { return qerr(pid, rc, 'io_counters') }
    return ProcessIo{
        read_count: raw.read_count
        write_count: raw.write_count
        read_bytes: raw.read_bytes
        write_bytes: raw.write_bytes
        read_chars: opt_i64_u64(raw.read_chars)
        write_chars: opt_i64_u64(raw.write_chars)
    }
}

pub struct FullMemoryInfo {
pub:
    rss    u64
    vms    u64
    shared u64
    text   ?u64
    lib    ?u64
    data   ?u64
    dirty  ?u64
    uss    ?u64
    pss    ?u64
    swap   ?u64
}

pub fn process_memory_full_info(pid int) !FullMemoryInfo {
    mut raw := C.psutil_MemFullInfo{}
    rc := unsafe { C.psutil_proc_mem_full(pid, &raw) }
    if rc != 0 { return qerr(pid, rc, 'memory_full_info') }
    return FullMemoryInfo{
        rss: raw.rss
        vms: raw.vms
        shared: raw.shared
        text: opt_u64(raw.text)
        lib: opt_u64(raw.lib)
        data: opt_u64(raw.data)
        dirty: opt_u64(raw.dirty)
        uss: opt_i64_u64(raw.uss)
        pss: opt_i64_u64(raw.pss)
        swap: opt_i64_u64(raw.swap)
    }
}

pub fn ram_total() !u64 {
    mut total := u64(0)
    rc := unsafe { C.psutil_proc_ram_total(&total) }
    if rc != 0 { return qerr(0, rc, 'ram_total') }
    return total
}

pub struct OpenFile {
pub:
    path     string
    fd       int
    position ?i64
    mode     ?string
    flags    ?int
}

pub fn process_open_files(pid int) ![]OpenFile {
    mut raw := []C.psutil_OpenFile{len: max_open_files}
    n := unsafe { C.psutil_proc_open_files(pid, &raw[0], max_open_files) }
    if n < 0 { return qerr(pid, n, 'open_files') }
    mut res := []OpenFile{cap: n}
    for i in 0 .. n {
        mode_s := unsafe { cstring_to_vstring(&raw[i].mode[0]) }
        res << OpenFile{
            path: unsafe { cstring_to_vstring(&raw[i].path[0]) }
            fd: raw[i].fd
            position: opt_i64(raw[i].position)
            flags: if raw[i].flags < 0 { none } else { raw[i].flags }
            mode: if mode_s == '' { none } else { mode_s }
        }
    }
    return res
}

pub struct MemoryMap {
pub:
    path          string
    addr          string
    perms         string
    rss           u64
    size          u64
    pss           ?u64
    shared_clean  u64
    shared_dirty  u64
    private_clean u64
    private_dirty u64
    referenced    u64
    anonymous     u64
    swap          ?u64
}

pub fn process_memory_maps(pid int, grouped bool) ![]MemoryMap {
    mut raw := []C.psutil_MapInfo{len: max_maps}
    n := unsafe { C.psutil_proc_memory_maps(pid, &raw[0], max_maps) }
    if n < 0 { return qerr(pid, n, 'memory_maps') }
    mut res := []MemoryMap{cap: n}
    for i in 0 .. n {
        res << MemoryMap{
            path: unsafe { cstring_to_vstring(&raw[i].path[0]) }
            addr: unsafe { cstring_to_vstring(&raw[i].addr[0]) }
            perms: unsafe { cstring_to_vstring(&raw[i].perms[0]) }
            rss: raw[i].rss
            size: raw[i].size
            pss: opt_i64_u64(raw[i].pss)
            shared_clean: raw[i].shared_clean
            shared_dirty: raw[i].shared_dirty
            private_clean: raw[i].private_clean
            private_dirty: raw[i].private_dirty
            referenced: raw[i].referenced
            anonymous: raw[i].anonymous
            swap: opt_i64_u64(raw[i].swap)
        }
    }
    if !grouped { return res }
    mut agg := map[string]MemoryMap{}
    mut order := []string{}
    for m in res {
        if m.path in agg {
            mut prev := agg[m.path]
            prev.rss += m.rss
            prev.size += m.size
            prev.shared_clean += m.shared_clean
            prev.shared_dirty += m.shared_dirty
            prev.private_clean += m.private_clean
            prev.private_dirty += m.private_dirty
            prev.referenced += m.referenced
            prev.anonymous += m.anonymous
            agg[m.path] = prev
        } else {
            agg[m.path] = m
            order << m.path
        }
    }
    mut grouped_res := []MemoryMap{cap: order.len}
    for path in order { grouped_res << agg[path] }
    return grouped_res
}

pub struct Addr {
pub:
    ip   string
    port int
}

pub struct Connection {
pub:
    fd     int
    family int
    typ    int
    laddr  Addr
    raddr  Addr
    status string
}

pub fn process_net_connections(pid int, kind string) ![]Connection {
    want_unix := kind == 'unix'
    mut raw := []C.psutil_ConnInfo{len: max_conns}
    n := unsafe { C.psutil_proc_connections(pid, &raw[0], max_conns, if want_unix { 1 } else { 0 }) }
    if n < 0 { return qerr(pid, n, 'net_connections') }
    mut res := []Connection{cap: n}
    for i in 0 .. n {
        res << Connection{
            fd: raw[i].fd
            family: raw[i].family
            typ: raw[i].typ
            laddr: Addr{ip: unsafe { cstring_to_vstring(&raw[i].laddr_ip[0]) }, port: raw[i].laddr_port}
            raddr: Addr{ip: unsafe { cstring_to_vstring(&raw[i].raddr_ip[0]) }, port: raw[i].raddr_port}
            status: unsafe { cstring_to_vstring(&raw[i].status[0]) }
        }
    }
    return res
}

pub fn process_send_signal(pid int, sig int) ! {
    rc := C.psutil_proc_signal(pid, sig)
    if rc != 0 { return qerr(pid, rc, 'send_signal') }
}

pub fn process_suspend(pid int) ! {
    rc := C.psutil_proc_suspend(pid)
    if rc != 0 { return qerr(pid, rc, 'suspend') }
}

pub fn process_resume(pid int) ! {
    rc := C.psutil_proc_resume(pid)
    if rc != 0 { return qerr(pid, rc, 'resume') }
}

pub fn signal_term_value() int { return C.psutil_signal_term() }
pub fn signal_kill_value() int { return C.psutil_signal_kill() }
pub fn signal_stop_value() int { return C.psutil_signal_stop() }
pub fn signal_cont_value() int { return C.psutil_signal_cont() }
