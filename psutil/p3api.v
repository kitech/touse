module psutil

// Linux RLIMIT_* 常量，取值与 /usr/include/bits/resource.h 一致。
pub const rlimit_cpu = 0
pub const rlimit_fsize = 1
pub const rlimit_data = 2
pub const rlimit_stack = 3
pub const rlimit_core = 4
pub const rlimit_rss = 5
pub const rlimit_nproc = 6
pub const rlimit_nofile = 7
pub const rlimit_memlock = 8
pub const rlimit_as = 9
pub const rlimit_locks = 10
pub const rlimit_sigpending = 11
pub const rlimit_msgqueue = 12
pub const rlimit_nice = 13
pub const rlimit_rtprio = 14
pub const rlimit_rttime = 15

pub const power_time_unknown = -1
pub const power_time_unlimited = -2

fn p3_opt_u64(v u64) ?u64 {
    return if v == none_u64 { none } else { v }
}

fn p3_opt_f64(v f64) ?f64 {
    return if v < 0.0 { none } else { v }
}

fn p3_opt_bool(v int) ?bool {
    if v < 0 { return none }
    return v == 1
}

// OneShot 是一次性进程快照；V 无 with 语义，按值返回，不缓存。
pub struct OneShot {
pub:
    name        string
    ppid        int
    uids        IdTriplet
    gids        IdTriplet
    status      string
    create_time f64
    cpu_times   CpuTimes
    terminal    string
    num_threads int
    memory_info MemoryInfo
}

pub fn (o OneShot) str() string {
    return 'OneShot{name: ${o.name} ppid: ${o.ppid} uids: ${o.uids} gids: ${o.gids} status: ${o.status} create_time: ${o.create_time} cpu_times: ${o.cpu_times} terminal: ${o.terminal} num_threads: ${o.num_threads} memory_info: ${o.memory_info.str1()}}'
}

pub fn oneshot(pid int) !OneShot {
    mut raw := C.psutil_OneShot{}
    rc := unsafe { C.psutil_extra_oneshot(pid, &raw) }
    if rc != 0 { return map_proc_err(pid, rc, 'oneshot') }
    return OneShot{
        name: unsafe { cstring_to_vstring(&raw.name[0]) }
        ppid: raw.ppid
        uids: IdTriplet{real: raw.uids[0], effective: raw.uids[1], saved: raw.uids[2]}
        gids: IdTriplet{real: raw.gids[0], effective: raw.gids[1], saved: raw.gids[2]}
        status: unsafe { cstring_to_vstring(&raw.status[0]) }
        create_time: raw.create_time
        cpu_times: CpuTimes{
            user: raw.user
            system: raw.system
            children_user: raw.children_user
            children_system: raw.children_system
            iowait: p3_opt_f64(raw.iowait)
        }
        terminal: unsafe { cstring_to_vstring(&raw.terminal[0]) }
        num_threads: raw.num_threads
        memory_info: MemoryInfo{
            vms: raw.vms
            rss: raw.rss
            shared: raw.shared
            text: p3_opt_u64(raw.text)
            lib: p3_opt_u64(raw.lib)
            data: p3_opt_u64(raw.data)
            dirty: p3_opt_u64(raw.dirty)
        }
    }
}

// ProcessIdentity 是 V 扩展便捷封装，不是 pypi 公共 API。
pub struct ProcessIdentity {
pub:
    pid         int
    create_time f64
}

pub fn (i ProcessIdentity) str() string {
    return 'ProcessIdentity{pid: ${i.pid} create_time: ${i.create_time}}'
}

pub struct Rlimit {
pub:
    soft i64
    hard i64
}

pub fn (r Rlimit) str() string {
    return 'Rlimit{soft: ${r.soft} hard: ${r.hard}}'
}

pub fn rlimit_of(pid int, resource int) !Rlimit {
    mut raw := C.psutil_Rlimit{}
    rc := unsafe { C.psutil_extra_rlimit(pid, resource, &raw) }
    if rc != 0 { return map_proc_err(pid, rc, 'rlimit') }
    return Rlimit{soft: raw.soft, hard: raw.hard}
}

pub fn set_rlimit_of(pid int, resource int, soft i64, hard i64) ! {
    rc := unsafe { C.psutil_extra_set_rlimit(pid, resource, soft, hard) }
    if rc != 0 { return map_proc_err(pid, rc, 'rlimit(value)') }
}

pub fn process_environ(pid int) !map[string]string {
    mut raw := []C.psutil_EnvVar{len: max_env_vars}
    n := unsafe { C.psutil_extra_environ(pid, &raw[0], max_env_vars) }
    if n < 0 { return map_proc_err(pid, n, 'environ') }
    mut res := map[string]string{}
    for i in 0 .. n {
        key := unsafe { cstring_to_vstring(&raw[i].key[0]) }
        value := unsafe { cstring_to_vstring(&raw[i].value[0]) }
        res[key] = value
    }
    return res
}

pub struct Shwtemp {
pub:
    name     string
    label    string
    current  f64
    high     ?f64
    critical ?f64
}

pub fn (t Shwtemp) str() string {
    return 'Shwtemp{name: ${t.name} label: ${t.label} current: ${t.current} high: ${t.high} critical: ${t.critical}}'
}

pub fn sensors_temperatures(fahrenheit bool) !map[string][]Shwtemp {
    mut raw := []C.psutil_Shwtemp{len: max_shwtemp}
    n := unsafe {
        C.psutil_extra_sensors_temperatures(if fahrenheit { 1 } else { 0 },
            &raw[0], max_shwtemp)
    }
    if n < 0 { return map_proc_err(0, n, 'sensors_temperatures') }
    mut res := map[string][]Shwtemp{}
    for i in 0 .. n {
        chip := unsafe { cstring_to_vstring(&raw[i].chip[0]) }
        item := Shwtemp{
            name: unsafe { cstring_to_vstring(&raw[i].name[0]) }
            label: unsafe { cstring_to_vstring(&raw[i].label[0]) }
            current: raw[i].current
            high: p3_opt_f64(raw[i].high)
            critical: p3_opt_f64(raw[i].critical)
        }
        mut group := res[chip]
        group << item
        res[chip] = group
    }
    return res
}

pub struct Sfan {
pub:
    name  string
    speed int
}

pub fn (f Sfan) str() string {
    return 'Sfan{name: ${f.name} speed: ${f.speed}}'
}

pub fn sensors_fans() !map[string][]Sfan {
    mut raw := []C.psutil_Fan{len: max_sfan}
    n := unsafe { C.psutil_extra_sensors_fans(&raw[0], max_sfan) }
    if n < 0 { return map_proc_err(0, n, 'sensors_fans') }
    mut res := map[string][]Sfan{}
    for i in 0 .. n {
        chip := unsafe { cstring_to_vstring(&raw[i].chip[0]) }
        item := Sfan{
            name: unsafe { cstring_to_vstring(&raw[i].name[0]) }
            speed: raw[i].speed
        }
        mut group := res[chip]
        group << item
        res[chip] = group
    }
    return res
}

pub struct Battery {
pub:
    percent       f64
    secsleft      int
    power_plugged ?bool
}

pub fn (b Battery) str() string {
    return 'Battery{percent: ${b.percent} secsleft: ${b.secsleft} power_plugged: ${b.power_plugged}}'
}

pub fn sensors_battery() ![]Battery {
    mut raw := []C.psutil_Battery{len: max_battery}
    n := unsafe { C.psutil_extra_sensors_battery(&raw[0], max_battery) }
    if n < 0 { return map_proc_err(0, n, 'sensors_battery') }
    mut res := []Battery{cap: n}
    for i in 0 .. n {
        res << Battery{
            percent: raw[i].percent
            secsleft: raw[i].secsleft
            power_plugged: p3_opt_bool(raw[i].power_plugged)
        }
    }
    return res
}

fn windows_service_from(raw C.psutil_WindowsService) WindowsService {
    return WindowsService{
        service_name: unsafe { cstring_to_vstring(&raw.service_name[0]) }
        display_name_value: unsafe { cstring_to_vstring(&raw.display_name[0]) }
        binary_path: unsafe { cstring_to_vstring(&raw.binary_path[0]) }
        user_name: unsafe { cstring_to_vstring(&raw.user_name[0]) }
        start_type_value: raw.start_type
        service_pid: raw.service_pid
        status_value: raw.status
        description_text: unsafe { cstring_to_vstring(&raw.description[0]) }
    }
}

pub struct WindowsService {
pub:
    service_name       string
    display_name_value string
    binary_path        string
    user_name          string
    start_type_value   int
    service_pid        int
    status_value       int
    description_text   string
}

pub fn (s WindowsService) str() string {
    return 'WindowsService{name: ${s.service_name} pid: ${s.service_pid} status: ${s.status_value}}'
}

pub fn (s WindowsService) name() !string { return s.service_name }

pub fn (s WindowsService) display_name() !string { return s.display_name_value }

pub fn (s WindowsService) binpath() !string { return s.binary_path }

pub fn (s WindowsService) username() !string { return s.user_name }

pub fn (s WindowsService) start_type() !int { return s.start_type_value }

pub fn (s WindowsService) pid() !int { return s.service_pid }

pub fn (s WindowsService) status() !int { return s.status_value }

pub fn (s WindowsService) description() !string { return s.description_text }

pub fn (s WindowsService) as_dict(attrs []string, ad_value string) map[string]string {
    mut res := map[string]string{}
    for attr in attrs {
        match attr {
            'name' {
                if v := s.name() { res[attr] = v } else { res[attr] = ad_value }
            }
            'display_name' {
                if v := s.display_name() { res[attr] = v } else { res[attr] = ad_value }
            }
            'binpath' {
                if v := s.binpath() { res[attr] = v } else { res[attr] = ad_value }
            }
            'username' {
                if v := s.username() { res[attr] = v } else { res[attr] = ad_value }
            }
            'start_type' {
                if v := s.start_type() { res[attr] = v.str() } else { res[attr] = ad_value }
            }
            'pid' {
                if v := s.pid() { res[attr] = v.str() } else { res[attr] = ad_value }
            }
            'status' {
                if v := s.status() { res[attr] = v.str() } else { res[attr] = ad_value }
            }
            'description' {
                if v := s.description() { res[attr] = v } else { res[attr] = ad_value }
            }
            else { res[attr] = ad_value }
        }
    }
    return res
}

pub fn win_service_iter() ![]WindowsService {
    mut raw := []C.psutil_WindowsService{len: max_winsvc}
    n := unsafe { C.psutil_extra_win_service_iter(&raw[0], max_winsvc) }
    if n < 0 { return map_proc_err(0, n, 'win_service_iter') }
    mut res := []WindowsService{cap: n}
    for i in 0 .. n { res << windows_service_from(raw[i]) }
    return res
}

pub fn win_service_get(name string) !WindowsService {
    mut raw := C.psutil_WindowsService{}
    rc := unsafe { C.psutil_extra_win_service_get(name.str, &raw) }
    if rc != 0 { return map_proc_err(0, rc, 'win_service_get') }
    return windows_service_from(raw)
}

pub struct HeapInfo {
pub:
    heap_used  u64
    mmap_used  u64
    heap_count int
}

pub fn (h HeapInfo) str() string {
    return 'HeapInfo{heap_used: ${h.heap_used} mmap_used: ${h.mmap_used} heap_count: ${h.heap_count}}'
}

pub fn heap_info() !HeapInfo {
    mut raw := C.psutil_HeapInfo{}
    rc := unsafe { C.psutil_extra_heap_info(&raw) }
    if rc != 0 { return map_proc_err(0, rc, 'heap_info') }
    return HeapInfo{
        heap_used: raw.heap_used
        mmap_used: raw.mmap_used
        heap_count: raw.heap_count
    }
}

pub fn heap_trim() ! {
    rc := unsafe { C.psutil_extra_heap_trim() }
    if rc != 0 { return map_proc_err(0, rc, 'heap_trim') }
}
