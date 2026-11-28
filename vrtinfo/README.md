# vrtinfo — V 进程内部运行信息服务

## 服务名

- 前缀：`vrtinfo`
- 默认实例：`vrtinfo-<pid>`
- 可选标签：`vrtinfo-<pid>-<tag>`（tag 限 `[A-Za-z0-9_-]{1,16}`）
- 固定实例名：用 `vrtinfo.start_named(name)` 精确绑定，不拼接 pid；名字须为 `[A-Za-z0-9_-]` 且长度 1..48，直接作为 socket 名
- Linux 下 socket：`/tmp/native-ipc-<uid>/<name>`，独占锁 `<name>.lock`

## 传输层

- 使用 `ntipc`：Unix domain socket（Linux/macOS）/ 命名管道（Windows），协议 v1。
- 握手由 ntipc 完成；一帧 = 一个 UTF-8 JSON 对象，无 BOM、无结尾 NUL/换行。
- 请求上限 64 KiB，响应上限 1 MiB（ntipc 帧上限 8 MiB）。
- 长连接不会因为空闲而断开：帧读取用 `read_some` + `wait_for_work` 短轮询（100 ms），绕开 `ntipc.read()` 的 5 秒硬超时；server 侧无限等待，client 侧响应等待上限 30 秒。
- server 在 `vcp.info` 记录 `server started /tmp/native-ipc-<uid>/<name>`、新连接与连接断开（含 socket fd）。

## 应用层协议 v1

请求：

```json
{"v":1,"id":"7","cmd":"gc.stats","args":{}}
```

成功响应：

```json
{"v":1,"id":"7","ok":true,"data":{ ... }}
```

失败响应：

```json
{"v":1,"id":"7","ok":false,"err":{"code":1002,"msg":"unknown command: foo"}}
```

- `v`：固定 `1`。
- `id`：字符串（cJSON 数字为 double，避免精度丢失），服务端原样回显。
- `cmd`：小写点分命令名；`args`：JSON 对象，可省略（默认 `{}`）。
- 一个连接可发多轮请求/响应；协议错（非法 JSON/版本）回 1001 后关闭连接；语义错回错误但保持连接。

## 命令

| cmd | data |
|-----|------|
| `ping` | `pong, name, pid, uptime_ms` |
| `caps` | `v, cmds[], write_cmds[], max_req, max_resp`；`write_cmds[]` 是会修改状态/触发动作的命令，`help` 里以 `*` 标记 |
| `info` | `pid, name, exe, args[], start_unix_ms, uptime_ms, os, arch, cc, v_version, v_hash, tid, thread` |
| `gc.stats` | `gc_no, free_space_divisor, full_freq, is_disabled, non_gc_bytes, inuse, free_bytes, unmapped, total_bytes, bytes_since_gc, obtained_from_os, gc_parallel, cur_thread_registered` |
| `gc.collect` | `pending_before, finalized, pending_after, heap_before/after, free_before/after, obtained_before/after`（显式 full GC + finalizer，会暂停进程；用于判断不可达但未回收的对象） |
| `gc.dump` | `done`（调用 BDWGC `GC_dump()`，输出到进程 stderr；输出可能很大，只读诊断） |
| `gc.set_free_space_divisor` | `old, free_space_divisor`；`vrtic` 用法：`gc.set_free_space_divisor 20`（也可 `{"value":20}`）；范围 1..100；写命令 |
| `gc.set_full_freq` | `old, full_freq`；裸数字 1..1000；仅 incremental/generational 模式有明显效果；写命令 |
| `gc.set_is_disabled` | `old, is_disabled`；0/1；`1` 调用 `GC_disable`（连 `GC_gcollect` 都无效），只建议调试时短暂使用；写命令 |
| `gc.set_non_gc_bytes` | `old, non_gc_bytes`；裸数字 0..1TiB；影响 collection 调度记账；写命令 |
| `coro.stats` | `goid, stack_base_u64, stack_size, gc_thread_registered` |
| `coro.list` | `machine_total, machine_active, fiber_total, fiber_active, fiber_total_mem, max_stack_size`（聚合统计，来自 `crn_get_stats()`，不是逐条 fiber 列表） |
| `threads` | `gc_parallel, count, threads[]`；每项 `tid, name, state, is_current`，当前线程项额外含 `goid, gc_registered`；并尽量提供 `cpu_ms, stksz, used_stksz, wchan, syscall, func, pc`（`0`/空表示不可用）（Linux `/proc/self/task`，macOS `task_threads`，Windows Toolhelp；其他平台返回 1006） |
| `mem` | `rss_bytes, vm_size_bytes`（Linux `/proc/self/status`；其他平台返回 1006） |
| `fibers` | `count, fibers[]`；每项 `id, mcid, state, pkreason, stksz, used_stksz`（`state`: `nostack`/`runnable`/`executing`/`waiting`/`finished`；`emucobypth` 构建返回 1006） |

`GogcStat` 字段映射：`inuse`=`inuse`(heap_size，含 free/碎片，未 unmapped)、`free_bytes`=`free_bytes`、`unmapped`=`objcnt`、`total_bytes`=`cgocall`、`bytes_since_gc`=`x`、`obtained_from_os`=`alloc`。`free_space_divisor` 来自 `GC_get_free_space_divisor()`（BDWGC 默认 3，corona 当前运行值 50）；`full_freq`=`GC_get_full_freq()`；`is_disabled`=`GC_is_disabled()`；`non_gc_bytes`=`GC_get_non_gc_bytes()`。`gc_parallel` 来自 `GC_get_parallel()`（本机 BDWGC 未提供 `GC_count_threads()`，故以并行度代替 GC 活跃线程数）。

判读：`live_upper ≈ inuse - free_bytes`。长时间看 `live_upper` 是否增长，而不是只看 `inuse`（`inuse` 是 heap 高水位，包含 free/碎片）。

`threads` 的栈与函数字段按平台尽力提供：

- `stksz`：Linux 由 `maps` 中包含 `startstack` 的 VMA 大小得出；macOS `pthread_get_stacksize_np`；Windows TEB `StackBase-StackLimit`。
- `used_stksz`：Linux 内核将 `kstkesp` 清零，无法获取；macOS/Windows 由 SP 计算。
- `wchan`：Linux `/proc/self/task/<tid>/wchan`（内核等待函数）；其它平台为空。
- `syscall`：Linux `/proc/self/task/<tid>/syscall` 的系统调用名（futex/epoll_wait/nanosleep 等，按 `SYS_*` 常量映射，跨架构）；其它平台为空。
- `cpu_ms`：线程累计 CPU 时间（user+system，毫秒）；三平台均可用。
- `func`：Linux/macOS 用 `dladdr`（无导出符号时退回 `模块+偏移`）；Windows 无 PDB 时为 `模块+偏移`；运行中的 Linux 线程无 PC，显示 `-`。

错误码：`1001` bad_request、`1002` unknown_cmd、`1003` bad_args、`1004` internal、`1005` too_large、`1006` unsupported。

## 调用方注册命令

`Server.register_command(name, handler)` 允许调用方注册自定义命令：

```v
s := vrtinfo.start_named('vrtinfo-demo') or { panic(err.msg()) }
s.register_command('my.cmd', fn (args string) !string {
	return '{"hello":"world"}'
})
```

- handler 接收请求里的 `args` JSON 对象字符串，返回响应 `data` 的 JSON 字符串。
- 名字非法、与内置命令重名或重复注册时忽略。
- 已注册命令会出现在 `caps` 的 `cmds[]` 中；静态写入命令还会出现在 `write_cmds[]`，`help` 显示时带 `*`。

## 接入与编译

被监控进程内嵌服务：

```v
import vrtinfo
s := vrtinfo.start_named('vrtinfo-demo') or { panic(err.msg()) }
println(s.name)
```

编译（只编译不运行）：

```sh
v -skip-running touse/vrtinfo/demo.vsh
v -skip-running touse/vrtinfo/vrtic.vsh
./vrtinfo/demo                           # 默认固定名 vrtinfo-demo
./vrtinfo/demo -name my-service          # 显式指定
./vrtinfo/vrtic -name vrtinfo-demo
```

## vrtic（交互式客户端）

```sh
vrtic -name vrtinfo-12345 [-timeout 2000]
```

提示符 `name@on>` / `name@off>`，状态来自连接是否打开。

- `help` / `?`：发送 `caps`，打印服务端命令列表。
- `<cmd>` 或 `<cmd> <json对象>`：发送请求并等待响应。
- `reconnect`：本地重连；`quit` / `exit` / Ctrl-D：退出。

列表结果（`threads`、`fibers`、`caps` 的 `cmds`）以纯 ASCII 表格显示；其它结果仍打印原始 JSON。

注意：导入 `vcp.gc` 会影响进程级 BDWGC 参数；导入 `vcp.yco` 会链接 corona 运行库。
