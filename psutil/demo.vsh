import touse.psutil
import vcp
import time

btime := time.now()
pids := psutil.pids() or {
    vcp.error(err.str())
    return
}
vcp.info(pids.len, pids.str().elide_right(80), time.since(btime))

btime = time.now()
subpids := psutil.children(1, false) or {
    vcp.error(err.str())
    return
}
vcp.info(subpids.len, subpids.str().elide_right(80), time.since(btime))

// reproc
p := psutil.Reproc.from(1)
vcp.info(p.str(), p.pid(), "/")

p.kill() or { vcp.error(err.str()) }
p.terminate() or { vcp.error(err.str()) }

// P1: Process API
me := psutil.current_process()
name := me.name() or { vcp.error(err.str()); return }
status := me.status() or { vcp.error(err.str()); return }
nthreads := me.num_threads() or { vcp.error(err.str()); return }
ctime := me.create_time() or { vcp.error(err.str()); return }
ct := me.cpu_times() or { vcp.error(err.str()); return }
mi := me.memory_info() or { vcp.error(err.str()); return }
io := me.io_counters() or { vcp.error(err.str()); return }
fds := me.num_fds() or { vcp.error(err.str()); return }
terminal := me.terminal() or { vcp.error(err.str()); return }
username := me.username() or { vcp.error(err.str()); return }
uids := me.uids() or { vcp.error(err.str()); return }
affinity := me.cpu_affinity() or { vcp.error(err.str()); return }
nice := me.nice() or { vcp.error(err.str()); return }
ion := me.ionice() or { vcp.error(err.str()); return }
kids := me.children(false) or { vcp.error(err.str()); return }
vcp.info('Process', me.str(), name, status, nthreads.str(), ctime.str(),
    ct.str(), mi.str1(), io.str(), fds.str(), terminal, username,
    uids.str(), affinity.str(), nice.str(), ion.str())
vcp.info('as_dict', me.as_dict(['pid', 'name', 'status', 'num_threads'], 'none'))
vcp.info('children', kids.len)

// P2: system-level API
sys_cpu_times := psutil.cpu_times(false) or { vcp.error(err.str()); return }
sys_cpu_pct := psutil.cpu_percent(0, false) or { vcp.error(err.str()); return }
sys_cpu_tp := psutil.cpu_times_percent(0, false) or { vcp.error(err.str()); return }
logical := psutil.cpu_count(true) or { vcp.error(err.str()); return }
physical := psutil.cpu_count(false) or { vcp.error(err.str()); return }
cpu_stat := psutil.cpu_stats() or { vcp.error(err.str()); return }
vcp.info('P2 cpu', logical.str(), physical.str(), sys_cpu_times.str(),
    sys_cpu_pct.str(), sys_cpu_tp.str(), cpu_stat.str())

vm := psutil.virtual_memory() or { vcp.error(err.str()); return }
sw := psutil.swap_memory() or { vcp.error(err.str()); return }
vcp.info('P2 memory', vm.str(), sw.str())

parts := psutil.disk_partitions(false) or { vcp.error(err.str()); return }
usage := psutil.disk_usage('/') or { vcp.error(err.str()); return }
diskio := psutil.disk_io_counters(false) or { vcp.error(err.str()); return }
vcp.info('P2 disk', parts.len.str(), parts.str().elide_right(120),
    usage.str(), diskio.str())

netio := psutil.net_io_counters(false) or { vcp.error(err.str()); return }
ifstats := psutil.net_if_stats() or { vcp.error(err.str()); return }
ifaddrs := psutil.net_if_addrs() or { vcp.error(err.str()); return }
conns := psutil.net_connections('inet') or { vcp.error(err.str()); return }
vcp.info('P2 net', netio.str(), ifstats.str().elide_right(120),
    ifaddrs.len.str(), conns.len.str())

boot := psutil.boot_time() or { vcp.error(err.str()); return }
sysusers := psutil.users() or { vcp.error(err.str()); return }
vcp.info('P2 other', boot.str(), sysusers.len.str(),
    sysusers.str().elide_right(120))
