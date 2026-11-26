module psutil

import time

// Process 对齐 pypi psutil.Process；只保存 pid，所有属性按需查询。
pub struct Process {
pub:
    pid int
}

pub fn new_process(pid int) Process {
    return Process{pid: pid}
}

pub fn (p Process) str() string {
    return 'psutil.Process(pid=${p.pid})'
}

pub fn (p Process) name() !string {
    return process_name(p.pid)
}

pub fn (p Process) exe() !string {
    return process_exe(p.pid)
}

pub fn (p Process) cwd() !string {
    return process_cwd(p.pid)
}

pub fn (p Process) cmdline() ![]string {
    return cmdline_list(p.pid)
}

pub fn (p Process) create_time() !f64 {
    return process_create_time(p.pid)
}

pub fn (p Process) status() !string {
    return process_status(p.pid)
}

pub fn (p Process) username() !string {
    return process_username(p.pid)
}

pub fn (p Process) uids() !IdTriplet {
    return process_uids(p.pid)
}

pub fn (p Process) gids() !IdTriplet {
    return process_gids(p.pid)
}

pub fn (p Process) terminal() !string {
    return process_terminal(p.pid)
}

pub fn (p Process) ppid() !int {
    value := ppid_of(p.pid)
    if value < 0 { return proc_err(p.pid, err_no_such_process, 'ppid') }
    return value
}

pub fn (p Process) parent() !Process {
    value := p.ppid() or { return err }
    return new_process(value)
}

pub fn (p Process) parents() ![]Process {
    mut res := []Process{}
    mut cur := p
    for {
        value := cur.ppid() or { break }
        if value <= 0 || value == cur.pid { break }
        cur = new_process(value)
        res << cur
    }
    return res
}

pub fn (p Process) children(recursive bool) ![]Process {
    ids := children(p.pid, recursive) or { return err }
    mut res := []Process{cap: ids.len}
    for id in ids { res << new_process(id) }
    return res
}

pub fn (p Process) is_running() bool {
    return os_pid_exists(p.pid)
}

pub fn (p Process) nice() !int {
    return process_nice(p.pid)
}

pub fn (p Process) set_nice(value int) ! {
    return process_set_nice(p.pid, value)
}

pub fn (p Process) ionice() !Ionice {
    return process_ionice(p.pid)
}

pub fn (p Process) set_ionice(ioclass int, value int) ! {
    return process_set_ionice(p.pid, ioclass, value)
}

pub fn (p Process) cpu_affinity() ![]int {
    return process_cpu_affinity(p.pid)
}

pub fn (p Process) set_cpu_affinity(cpus []int) ! {
    return process_set_cpu_affinity(p.pid, cpus)
}

pub fn (p Process) num_ctx_switches() !CtxSwitches {
    return process_ctx_switches(p.pid)
}

pub fn (p Process) num_threads() !int {
    return process_num_threads(p.pid)
}

pub fn (p Process) num_fds() !int {
    return process_num_fds(p.pid)
}

pub fn (p Process) num_handles() !int {
    return process_num_handles(p.pid)
}

pub fn (p Process) cpu_times() !CpuTimes {
    return process_cpu_times(p.pid)
}

pub fn (p Process) cpu_percent(interval f64) !f64 {
    if interval > 0 {
        before := p.cpu_times() or { return err }
        time.sleep(int(interval * 1000.0) * time.millisecond)
        after := p.cpu_times() or { return err }
        a := before.user + before.system
        b := after.user + after.system
        return 100.0 * (b - a) / interval
    }
    ct := p.cpu_times() or { return err }
    return process_cpu_percent_from_total(p.pid, ct.user + ct.system)
}

pub fn (p Process) memory_info() !MemoryInfo {
    return memory_info(p.pid)
}

pub fn (p Process) memory_full_info() !FullMemoryInfo {
    return process_memory_full_info(p.pid)
}

pub fn (p Process) memory_percent(memtype string) !f64 {
    mi := p.memory_info() or { return err }
    total := ram_total() or { return err }
    if total == 0 { return 0.0 }
    value := if memtype == 'vms' { mi.vms } else { mi.rss }
    return 100.0 * f64(value) / f64(total)
}

pub fn (p Process) io_counters() !ProcessIo {
    return process_io_counters(p.pid)
}

pub fn (p Process) open_files() ![]OpenFile {
    return process_open_files(p.pid)
}

pub fn (p Process) memory_maps(grouped bool) ![]MemoryMap {
    return process_memory_maps(p.pid, grouped)
}

pub fn (p Process) net_connections(kind string) ![]Connection {
    return process_net_connections(p.pid, kind)
}

pub fn (p Process) connections(kind string) ![]Connection {
    return p.net_connections(kind)
}

pub fn (p Process) send_signal(sig int) ! {
    return process_send_signal(p.pid, sig)
}

pub fn (p Process) suspend() ! {
    return process_suspend(p.pid)
}

pub fn (p Process) resume() ! {
    return process_resume(p.pid)
}

pub fn (p Process) terminate() ! {
    return p.send_signal(signal_term_value())
}

pub fn (p Process) kill() ! {
    return p.send_signal(signal_kill_value())
}

pub fn (p Process) wait(timeout_ms int) !bool {
    start := time.now().unix_milli()
    for p.is_running() {
        if timeout_ms > 0 && time.now().unix_milli() - start >= i64(timeout_ms) {
            return proc_err(p.pid, err_timeout_expired, 'wait')
        }
        time.sleep(20 * time.millisecond)
    }
    return true
}

pub fn (p Process) as_dict(attrs []string, ad_value string) map[string]string {
    mut res := map[string]string{}
    for attr in attrs {
        match attr {
            'pid' { res[attr] = p.pid.str() }
            'name' { res[attr] = p.name() or { ad_value } }
            'exe' { res[attr] = p.exe() or { ad_value } }
            'cwd' { res[attr] = p.cwd() or { ad_value } }
            'cmdline' {
                if v := p.cmdline() { res[attr] = v.str() } else { res[attr] = ad_value }
            }
            'create_time' {
                if v := p.create_time() { res[attr] = v.str() } else { res[attr] = ad_value }
            }
            'status' { res[attr] = p.status() or { ad_value } }
            'username' { res[attr] = p.username() or { ad_value } }
            'ppid' {
                if v := p.ppid() { res[attr] = v.str() } else { res[attr] = ad_value }
            }
            'num_threads' {
                if v := p.num_threads() { res[attr] = v.str() } else { res[attr] = ad_value }
            }
            'num_fds' {
                if v := p.num_fds() { res[attr] = v.str() } else { res[attr] = ad_value }
            }
            'cpu_times' {
                if v := p.cpu_times() { res[attr] = v.str() } else { res[attr] = ad_value }
            }
            'memory_info' {
                if v := p.memory_info() { res[attr] = v.str1() } else { res[attr] = ad_value }
            }
            'io_counters' {
                if v := p.io_counters() { res[attr] = v.str() } else { res[attr] = ad_value }
            }
            else { res[attr] = ad_value }
        }
    }
    return res
}

pub fn process_iter() ![]Process {
    ids := pids() or { return err }
    mut res := []Process{cap: ids.len}
    for id in ids { res << new_process(id) }
    return res
}

pub struct WaitResult {
pub:
    gone  []Process
    alive []Process
}

pub fn wait_procs(procs []Process, timeout_ms int) !WaitResult {
    start := time.now().unix_milli()
    mut gone := []Process{}
    mut alive := []Process{}
    for p in procs {
        remaining := timeout_ms
        if timeout_ms > 0 {
            used := int(time.now().unix_milli() - start)
            remaining = timeout_ms - used
            if remaining < 0 { remaining = 0 }
        }
        if p.wait(remaining) or { false } {
            gone << p
        } else {
            alive << p
        }
    }
    return WaitResult{gone: gone, alive: alive}
}
