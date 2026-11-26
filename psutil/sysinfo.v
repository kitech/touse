module psutil

// 系统级查询走相邻的 sysinfo.c。-3 表示平台不支持，避免伪造数值。
#flag -I @DIR/
#flag @DIR/sysinfo.o
#include "@DIR/sysinfo.h"

const max_cpus = 1024
const max_disks = 1024
const max_nics = 256
const max_addrs = 4096
const max_sys_conns = 8192
const max_users = 512

@[typedef]
pub struct C.psutil_SysCpuTimes {
    user       f64
    nice       f64
    system     f64
    idle       f64
    iowait     f64
    irq        f64
    softirq    f64
    steal      f64
    guest      f64
    guest_nice f64
}

@[typedef]
pub struct C.psutil_CpuTimesPercent {
    user       f64
    nice       f64
    system     f64
    idle       f64
    iowait     f64
    irq        f64
    softirq    f64
    steal      f64
    guest      f64
    guest_nice f64
}

@[typedef]
pub struct C.psutil_CpuStats {
    ctx_switches    u64
    interrupts      u64
    soft_interrupts u64
    syscalls        u64
}

@[typedef]
pub struct C.psutil_CpuFreq {
    current f64
    min     f64
    max     f64
}

@[typedef]
pub struct C.psutil_VirtualMemory {
    total     u64
    available u64
    percent   f64
    used      u64
    free_mem  u64
    active    u64
    inactive  u64
    buffers   u64
    cached    u64
    shared    u64
    slab      u64
}

@[typedef]
pub struct C.psutil_SwapMemory {
    total     u64
    used      u64
    free_swap u64
    percent   f64
    sin     u64
    sout    u64
}

@[typedef]
pub struct C.psutil_Partition {
    device     [512]char
    mountpoint [1024]char
    fstype     [128]char
    opts       [512]char
}

@[typedef]
pub struct C.psutil_DiskUsage {
    path      [4096]char
    total     u64
    used      u64
    free_disk u64
    percent   f64
}

@[typedef]
pub struct C.psutil_DiskIO {
    name              [128]char
    read_count        u64
    write_count       u64
    read_bytes        u64
    write_bytes       u64
    read_time         u64
    write_time        u64
    read_merged_count u64
    write_merged_count u64
    busy_time         u64
}

@[typedef]
pub struct C.psutil_NetIO {
    name         [128]char
    bytes_sent   u64
    bytes_recv   u64
    packets_sent u64
    packets_recv u64
    errin        u64
    errout       u64
    dropin       u64
    dropout      u64
}

@[typedef]
pub struct C.psutil_NicAddress {
    name      [128]char
    family    int
    address   [256]char
    netmask   [256]char
    broadcast [256]char
    ptp       [256]char
}

@[typedef]
pub struct C.psutil_NicStats {
    name   [128]char
    isup   int
    duplex int
    speed  u32
    mtu    u32
    flags  [512]char
}

@[typedef]
pub struct C.psutil_SysConnection {
    fd         int
    family     int
    typ        int
    pid        int
    laddr_ip   [128]char
    laddr_port int
    raddr_ip   [128]char
    raddr_port int
    status     [32]char
}

@[typedef]
pub struct C.psutil_User {
    name     [128]char
    terminal [128]char
    host     [256]char
    started  f64
    pid      int
}

fn C.psutil_sys_cpu_times(&C.psutil_SysCpuTimes, int, int) int
fn C.psutil_sys_cpu_percent_seed(&C.psutil_SysCpuTimes, int) int
fn C.psutil_sys_cpu_percent(&C.psutil_SysCpuTimes, int, &f64) int
fn C.psutil_sys_cpu_times_percent_seed(&C.psutil_SysCpuTimes, int) int
fn C.psutil_sys_cpu_times_percent(&C.psutil_SysCpuTimes, int, &C.psutil_CpuTimesPercent) int
fn C.psutil_sys_cpu_count(int) int
fn C.psutil_sys_cpu_stats(&C.psutil_CpuStats) int
fn C.psutil_sys_cpu_freq(&C.psutil_CpuFreq, int) int
fn C.psutil_sys_getloadavg(&f64, int) int
fn C.psutil_sys_virtual_memory(&C.psutil_VirtualMemory) int
fn C.psutil_sys_swap_memory(&C.psutil_SwapMemory) int
fn C.psutil_sys_disk_partitions(int, &C.psutil_Partition, int) int
fn C.psutil_sys_disk_usage(&char, &C.psutil_DiskUsage) int
fn C.psutil_sys_disk_io_counters(int, &C.psutil_DiskIO, int) int
fn C.psutil_sys_net_io_counters(int, &C.psutil_NetIO, int) int
fn C.psutil_sys_net_if_addrs(&C.psutil_NicAddress, int) int
fn C.psutil_sys_net_if_stats(&C.psutil_NicStats, int) int
fn C.psutil_sys_net_connections(&char, &C.psutil_SysConnection, int) int
fn C.psutil_sys_boot_time() f64
fn C.psutil_sys_users(&C.psutil_User, int) int

fn sys_err(code int, op string) ProcessError {
    match code {
        -3 { return proc_err_text(0, err_unsupported, '${op} is not supported on this platform') }
        -2 { return proc_err_text(0, err_access_denied, '${op}: access denied') }
        -1 { return proc_err_text(0, err_invalid_arg, '${op} failed') }
        else { return proc_err_text(0, err_invalid_arg, '${op} failed (code=${code})') }
    }
}

fn opt_cstr(s string) ?string {
    return if s == '' { none } else { s }
}

pub struct SystemCpuTimes {
pub:
    user       f64
    nice       f64
    system     f64
    idle       f64
    iowait     f64
    irq        f64
    softirq    f64
    steal      f64
    guest      f64
    guest_nice f64
}

pub struct CpuTimesPercent {
pub:
    user       f64
    nice       f64
    system     f64
    idle       f64
    iowait     f64
    irq        f64
    softirq    f64
    steal      f64
    guest      f64
    guest_nice f64
}

pub struct CpuStats {
pub:
    ctx_switches    u64
    interrupts      u64
    soft_interrupts u64
    syscalls        u64
}

pub struct CpuFreq {
pub:
    current f64
    min     ?f64
    max     ?f64
}

pub struct VirtualMemoryInfo {
pub:
    total     u64
    available u64
    percent   f64
    used      u64
    free      u64
    active    u64
    inactive  u64
    buffers   u64
    cached    u64
    shared    u64
    slab      u64
}

pub struct SwapMemoryInfo {
pub:
    total   u64
    used    u64
    free    u64
    percent f64
    sin     u64
    sout    u64
}

pub struct Partition {
pub:
    device     string
    mountpoint string
    fstype     string
    opts       string
}

pub struct DiskUsage {
pub:
    path    string
    total   u64
    used    u64
    free    u64
    percent f64
}

pub struct DiskIoCounters {
pub:
    name               string
    read_count         u64
    write_count        u64
    read_bytes         u64
    write_bytes        u64
    read_time          u64
    write_time         u64
    read_merged_count  u64
    write_merged_count u64
    busy_time          u64
}

pub struct NetIoCounters {
pub:
    name         string
    bytes_sent   u64
    bytes_recv   u64
    packets_sent u64
    packets_recv u64
    errin        u64
    errout       u64
    dropin       u64
    dropout      u64
}

pub struct NicAddr {
pub:
    family    int
    address   string
    netmask   ?string
    broadcast ?string
    ptp       ?string
}

pub struct NicStats {
pub:
    isup   bool
    duplex int
    speed  u32
    mtu    u32
    flags  string
}

pub struct SystemConnection {
pub:
    fd         ?int
    family     int
    typ        int
    pid        ?int
    laddr      Addr
    raddr      Addr
    status     string
}

pub struct SystemUser {
pub:
    name     string
    terminal ?string
    host     ?string
    started  f64
    pid      int
}

fn raw_cpu_times(raw C.psutil_SysCpuTimes) SystemCpuTimes {
    return SystemCpuTimes{
        user: raw.user
        nice: raw.nice
        system: raw.system
        idle: raw.idle
        iowait: raw.iowait
        irq: raw.irq
        softirq: raw.softirq
        steal: raw.steal
        guest: raw.guest
        guest_nice: raw.guest_nice
    }
}

fn cpu_times_to_raw(times SystemCpuTimes) C.psutil_SysCpuTimes {
    return C.psutil_SysCpuTimes{
        user: times.user
        nice: times.nice
        system: times.system
        idle: times.idle
        iowait: times.iowait
        irq: times.irq
        softirq: times.softirq
        steal: times.steal
        guest: times.guest
        guest_nice: times.guest_nice
    }
}

fn sys_cpu_times(percpu bool) ![]SystemCpuTimes {
    mut raw := []C.psutil_SysCpuTimes{len: max_cpus}
    n := unsafe { C.psutil_sys_cpu_times(&raw[0], max_cpus, if percpu { 1 } else { 0 }) }
    if n < 0 { return sys_err(n, 'cpu_times') }
    mut res := []SystemCpuTimes{cap: n}
    for i in 0 .. n { res << raw_cpu_times(raw[i]) }
    return res
}

fn sys_cpu_percent_seed(times []SystemCpuTimes) ! {
    if times.len == 0 { return sys_err(-1, 'cpu_percent') }
    mut raw := []C.psutil_SysCpuTimes{len: times.len}
    for i, t in times { raw[i] = cpu_times_to_raw(t) }
    rc := unsafe { C.psutil_sys_cpu_percent_seed(&raw[0], times.len) }
    if rc != 0 { return sys_err(rc, 'cpu_percent') }
}

fn sys_cpu_percent(cur []SystemCpuTimes) ![]f64 {
    if cur.len == 0 { return sys_err(-1, 'cpu_percent') }
    mut raw := []C.psutil_SysCpuTimes{len: cur.len}
    for i, t in cur { raw[i] = cpu_times_to_raw(t) }
    mut out := []f64{len: cur.len}
    rc := unsafe { C.psutil_sys_cpu_percent(&raw[0], cur.len, &out[0]) }
    if rc != 0 { return sys_err(rc, 'cpu_percent') }
    return out
}

fn sys_cpu_times_percent_seed(times []SystemCpuTimes) ! {
    if times.len == 0 { return sys_err(-1, 'cpu_times_percent') }
    mut raw := []C.psutil_SysCpuTimes{len: times.len}
    for i, t in times { raw[i] = cpu_times_to_raw(t) }
    rc := unsafe { C.psutil_sys_cpu_times_percent_seed(&raw[0], times.len) }
    if rc != 0 { return sys_err(rc, 'cpu_times_percent') }
}

fn sys_cpu_times_percent(cur []SystemCpuTimes) ![]CpuTimesPercent {
    if cur.len == 0 { return sys_err(-1, 'cpu_times_percent') }
    mut raw := []C.psutil_SysCpuTimes{len: cur.len}
    for i, t in cur { raw[i] = cpu_times_to_raw(t) }
    mut out := []C.psutil_CpuTimesPercent{len: cur.len}
    rc := unsafe { C.psutil_sys_cpu_times_percent(&raw[0], cur.len, &out[0]) }
    if rc != 0 { return sys_err(rc, 'cpu_times_percent') }
    mut res := []CpuTimesPercent{cap: cur.len}
    for item in out {
        res << CpuTimesPercent{
            user: item.user
            nice: item.nice
            system: item.system
            idle: item.idle
            iowait: item.iowait
            irq: item.irq
            softirq: item.softirq
            steal: item.steal
            guest: item.guest
            guest_nice: item.guest_nice
        }
    }
    return res
}

fn sys_cpu_count(logical bool) !int {
    n := C.psutil_sys_cpu_count(if logical { 1 } else { 0 })
    if n < 0 { return sys_err(n, 'cpu_count') }
    return n
}

fn sys_cpu_stats() !CpuStats {
    mut raw := C.psutil_CpuStats{}
    rc := unsafe { C.psutil_sys_cpu_stats(&raw) }
    if rc != 0 { return sys_err(rc, 'cpu_stats') }
    return CpuStats{
        ctx_switches: raw.ctx_switches
        interrupts: raw.interrupts
        soft_interrupts: raw.soft_interrupts
        syscalls: raw.syscalls
    }
}

fn sys_cpu_freq() ![]CpuFreq {
    mut raw := []C.psutil_CpuFreq{len: max_cpus}
    n := unsafe { C.psutil_sys_cpu_freq(&raw[0], max_cpus) }
    if n < 0 { return sys_err(n, 'cpu_freq') }
    mut res := []CpuFreq{cap: n}
    for i in 0 .. n {
        res << CpuFreq{
            current: raw[i].current
            min: if raw[i].min < 0 { none } else { raw[i].min }
            max: if raw[i].max < 0 { none } else { raw[i].max }
        }
    }
    return res
}

fn sys_getloadavg() ![]f64 {
    mut out := []f64{len: 3}
    n := unsafe { C.psutil_sys_getloadavg(&out[0], 3) }
    if n < 0 { return sys_err(n, 'getloadavg') }
    return out
}

fn sys_virtual_memory() !VirtualMemoryInfo {
    mut raw := C.psutil_VirtualMemory{}
    rc := unsafe { C.psutil_sys_virtual_memory(&raw) }
    if rc != 0 { return sys_err(rc, 'virtual_memory') }
    return VirtualMemoryInfo{
        total: raw.total
        available: raw.available
        percent: raw.percent
        used: raw.used
        free: raw.free_mem
        active: raw.active
        inactive: raw.inactive
        buffers: raw.buffers
        cached: raw.cached
        shared: raw.shared
        slab: raw.slab
    }
}

fn sys_swap_memory() !SwapMemoryInfo {
    mut raw := C.psutil_SwapMemory{}
    rc := unsafe { C.psutil_sys_swap_memory(&raw) }
    if rc != 0 { return sys_err(rc, 'swap_memory') }
    return SwapMemoryInfo{
        total: raw.total
        used: raw.used
        free: raw.free_swap
        percent: raw.percent
        sin: raw.sin
        sout: raw.sout
    }
}

fn sys_disk_partitions(all bool) ![]Partition {
    mut raw := []C.psutil_Partition{len: 256}
    n := unsafe { C.psutil_sys_disk_partitions(if all { 1 } else { 0 }, &raw[0], 256) }
    if n < 0 { return sys_err(n, 'disk_partitions') }
    mut res := []Partition{cap: n}
    for i in 0 .. n {
        res << Partition{
            device: unsafe { cstring_to_vstring(&raw[i].device[0]) }
            mountpoint: unsafe { cstring_to_vstring(&raw[i].mountpoint[0]) }
            fstype: unsafe { cstring_to_vstring(&raw[i].fstype[0]) }
            opts: unsafe { cstring_to_vstring(&raw[i].opts[0]) }
        }
    }
    return res
}

fn sys_disk_usage(path string) !DiskUsage {
    mut raw := C.psutil_DiskUsage{}
    rc := unsafe { C.psutil_sys_disk_usage(&path.str[0], &raw) }
    if rc != 0 { return sys_err(rc, 'disk_usage') }
    return DiskUsage{
        path: unsafe { cstring_to_vstring(&raw.path[0]) }
        total: raw.total
        used: raw.used
        free: raw.free_disk
        percent: raw.percent
    }
}

fn sys_disk_io_counters(perdisk bool) ![]DiskIoCounters {
    mut raw := []C.psutil_DiskIO{len: max_disks}
    n := unsafe { C.psutil_sys_disk_io_counters(if perdisk { 1 } else { 0 }, &raw[0], max_disks) }
    if n < 0 { return sys_err(n, 'disk_io_counters') }
    mut res := []DiskIoCounters{cap: n}
    for i in 0 .. n {
        res << DiskIoCounters{
            name: unsafe { cstring_to_vstring(&raw[i].name[0]) }
            read_count: raw[i].read_count
            write_count: raw[i].write_count
            read_bytes: raw[i].read_bytes
            write_bytes: raw[i].write_bytes
            read_time: raw[i].read_time
            write_time: raw[i].write_time
            read_merged_count: raw[i].read_merged_count
            write_merged_count: raw[i].write_merged_count
            busy_time: raw[i].busy_time
        }
    }
    return res
}

fn sys_net_io_counters(pernic bool) ![]NetIoCounters {
    mut raw := []C.psutil_NetIO{len: max_nics}
    n := unsafe { C.psutil_sys_net_io_counters(if pernic { 1 } else { 0 }, &raw[0], max_nics) }
    if n < 0 { return sys_err(n, 'net_io_counters') }
    mut res := []NetIoCounters{cap: n}
    for i in 0 .. n {
        res << NetIoCounters{
            name: unsafe { cstring_to_vstring(&raw[i].name[0]) }
            bytes_sent: raw[i].bytes_sent
            bytes_recv: raw[i].bytes_recv
            packets_sent: raw[i].packets_sent
            packets_recv: raw[i].packets_recv
            errin: raw[i].errin
            errout: raw[i].errout
            dropin: raw[i].dropin
            dropout: raw[i].dropout
        }
    }
    return res
}

fn sys_net_if_addrs() !map[string][]NicAddr {
    mut raw := []C.psutil_NicAddress{len: max_addrs}
    n := unsafe { C.psutil_sys_net_if_addrs(&raw[0], max_addrs) }
    if n < 0 { return sys_err(n, 'net_if_addrs') }
    mut res := map[string][]NicAddr{}
    for i in 0 .. n {
        name := unsafe { cstring_to_vstring(&raw[i].name[0]) }
        addr := NicAddr{
            family: raw[i].family
            address: unsafe { cstring_to_vstring(&raw[i].address[0]) }
            netmask: opt_cstr(unsafe { cstring_to_vstring(&raw[i].netmask[0]) })
            broadcast: opt_cstr(unsafe { cstring_to_vstring(&raw[i].broadcast[0]) })
            ptp: opt_cstr(unsafe { cstring_to_vstring(&raw[i].ptp[0]) })
        }
        res[name] << addr
    }
    return res
}

fn sys_net_if_stats() !map[string]NicStats {
    mut raw := []C.psutil_NicStats{len: max_nics}
    n := unsafe { C.psutil_sys_net_if_stats(&raw[0], max_nics) }
    if n < 0 { return sys_err(n, 'net_if_stats') }
    mut res := map[string]NicStats{}
    for i in 0 .. n {
        res[unsafe { cstring_to_vstring(&raw[i].name[0]) }] = NicStats{
            isup: raw[i].isup != 0
            duplex: raw[i].duplex
            speed: raw[i].speed
            mtu: raw[i].mtu
            flags: unsafe { cstring_to_vstring(&raw[i].flags[0]) }
        }
    }
    return res
}

fn sys_net_connections(kind string) ![]SystemConnection {
    mut raw := []C.psutil_SysConnection{len: max_sys_conns}
    n := unsafe { C.psutil_sys_net_connections(&kind.str[0], &raw[0], max_sys_conns) }
    if n < 0 { return sys_err(n, 'net_connections') }
    mut res := []SystemConnection{cap: n}
    for i in 0 .. n {
        res << SystemConnection{
            fd: if raw[i].fd < 0 { none } else { raw[i].fd }
            family: raw[i].family
            typ: raw[i].typ
            pid: if raw[i].pid <= 0 { none } else { raw[i].pid }
            laddr: Addr{
                ip: unsafe { cstring_to_vstring(&raw[i].laddr_ip[0]) }
                port: raw[i].laddr_port
            }
            raddr: Addr{
                ip: unsafe { cstring_to_vstring(&raw[i].raddr_ip[0]) }
                port: raw[i].raddr_port
            }
            status: unsafe { cstring_to_vstring(&raw[i].status[0]) }
        }
    }
    return res
}

fn sys_boot_time() !f64 {
    value := C.psutil_sys_boot_time()
    if value < 0 { return sys_err(-3, 'boot_time') }
    return value
}

fn sys_users() ![]SystemUser {
    mut raw := []C.psutil_User{len: max_users}
    n := unsafe { C.psutil_sys_users(&raw[0], max_users) }
    if n < 0 { return sys_err(n, 'users') }
    mut res := []SystemUser{cap: n}
    for i in 0 .. n {
        res << SystemUser{
            name: unsafe { cstring_to_vstring(&raw[i].name[0]) }
            terminal: opt_cstr(unsafe { cstring_to_vstring(&raw[i].terminal[0]) })
            host: opt_cstr(unsafe { cstring_to_vstring(&raw[i].host[0]) })
            started: raw[i].started
            pid: raw[i].pid
        }
    }
    return res
}
