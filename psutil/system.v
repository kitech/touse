module psutil

import time

// cpu_times 对齐 pypi psutil.cpu_times(percpu=False)；恒定返回列表，
// percpu=false 时长度为 1（V 无重载且不支持 !?[]T）。
pub fn cpu_times(percpu bool) ![]SystemCpuTimes {
    return sys_cpu_times(percpu)
}

// cpu_percent 对齐 pypi psutil.cpu_percent(interval=None, percpu=False)。
// interval <= 0 使用进程内上一次调用的缓存，首次返回 0；恒定返回列表。
pub fn cpu_percent(interval f64, percpu bool) ![]f64 {
    if interval < 0 {
        return proc_err_text(0, err_invalid_arg, 'cpu_percent: interval must not be negative')
    }
    if interval > 0 {
        before := sys_cpu_times(percpu) or { return err }
        sys_cpu_percent_seed(before) or { return err }
        time.sleep(int(interval * 1000.0) * time.millisecond)
    }
    cur := sys_cpu_times(percpu) or { return err }
    return sys_cpu_percent(cur)
}

// cpu_times_percent 对齐 pypi psutil.cpu_times_percent(interval=None,
// percpu=False)；恒定返回列表，percpu=false 时长度为 1。
pub fn cpu_times_percent(interval f64, percpu bool) ![]CpuTimesPercent {
    if interval < 0 {
        return proc_err_text(0, err_invalid_arg, 'cpu_times_percent: interval must not be negative')
    }
    if interval > 0 {
        before := sys_cpu_times(percpu) or { return err }
        sys_cpu_times_percent_seed(before) or { return err }
        time.sleep(int(interval * 1000.0) * time.millisecond)
    }
    cur := sys_cpu_times(percpu) or { return err }
    return sys_cpu_times_percent(cur)
}

pub fn cpu_count(logical bool) !int {
    return sys_cpu_count(logical)
}

pub fn cpu_stats() !CpuStats {
    return sys_cpu_stats()
}

pub fn virtual_memory() !VirtualMemoryInfo {
    return sys_virtual_memory()
}

pub fn swap_memory() !SwapMemoryInfo {
    return sys_swap_memory()
}

pub fn disk_partitions(all bool) ![]Partition {
    return sys_disk_partitions(all)
}

pub fn disk_usage(path string) !DiskUsage {
    return sys_disk_usage(path)
}

pub fn disk_io_counters(perdisk bool) ![]DiskIoCounters {
    return sys_disk_io_counters(perdisk)
}

pub fn net_io_counters(pernic bool) ![]NetIoCounters {
    return sys_net_io_counters(pernic)
}

fn check_conn_kind(kind string) ! {
    if kind == 'inet' || kind == 'inet4' || kind == 'inet6' || kind == 'tcp' ||
        kind == 'tcp4' || kind == 'tcp6' || kind == 'udp' || kind == 'udp4' ||
        kind == 'udp6' || kind == 'unix' || kind == 'all' {
        return
    }
    return proc_err_text(0, err_invalid_arg, 'net_connections: invalid kind=${kind}')
}

pub fn net_connections(kind string) ![]SystemConnection {
    check_conn_kind(kind) or { return err }
    raw := sys_net_connections(if kind == 'unix' { 'unix' } else { 'inet' }) or {
        return err
    }
    if kind == 'all' || kind == 'unix' { return raw }
    mut res := []SystemConnection{cap: raw.len}
    for c in raw {
        is4 := c.family == 2
        is6 := c.family == 10
        is_tcp := c.typ == 1
        is_udp := c.typ == 2
        matched := match kind {
            'inet' { is4 || is6 }
            'inet4' { is4 }
            'inet6' { is6 }
            'tcp' { is_tcp && (is4 || is6) }
            'tcp4' { is_tcp && is4 }
            'tcp6' { is_tcp && is6 }
            'udp' { is_udp && (is4 || is6) }
            'udp4' { is_udp && is4 }
            'udp6' { is_udp && is6 }
            else { false }
        }
        if matched { res << c }
    }
    return res
}

pub fn net_if_addrs() !map[string][]NicAddr {
    return sys_net_if_addrs()
}

pub fn net_if_stats() !map[string]NicStats {
    return sys_net_if_stats()
}

pub fn boot_time() !f64 {
    return sys_boot_time()
}

pub fn users() ![]SystemUser {
    return sys_users()
}
