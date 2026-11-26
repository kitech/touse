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
