


import touse.qjs
import vcp.tcchf
import vcp.venv
import vcp

r := qjs.new_runtime()
vcp.info(r)
defer { qjs.free_runtime(r) }

qjs.set_memory_limit(r, 16*1024*1024)
qjs.set_max_stack_size(r, 16*1024*1024)

ctx := qjs.new_context(r)
vcp.info(ctx)
defer { qjs.free_context(ctx) }
