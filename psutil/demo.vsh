import touse.psutil
import vcp
import time

btime := time.now()
pids := psutil.pids()
vcp.info(pids.len, pids.str().elide_right(80), time.since(btime))

btime = time.now()
subpids := psutil.children(1, false)
vcp.info(subpids.len, subpids.str().elide_right(80), time.since(btime))
