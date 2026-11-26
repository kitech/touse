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
| `caps` | `v, cmds[], max_req, max_resp` |
| `info` | `pid, name, exe, args[], start_unix_ms, uptime_ms, os, arch, cc, v_version, v_hash, tid, thread` |
| `gc.stats` | `gc_no, inuse, unmapped, total_bytes, bytes_since_gc, obtained_from_os, gc_parallel, cur_thread_registered` |
| `coro.stats` | `goid, stack_base_u64, stack_size, gc_thread_registered` |
| `coro.list` | `machine_total, machine_active, fiber_total, fiber_active, fiber_total_mem, max_stack_size`（聚合统计，来自 `crn_get_stats()`，不是逐条 fiber 列表） |
| `threads` | `gc_parallel, count, threads[]`；每项 `tid, name, state, is_current`，当前线程项额外含 `goid, gc_registered`（Linux `/proc/self/task`，macOS `task_threads`，Windows Toolhelp；其他平台返回 1006） |
| `mem` | `rss_bytes, vm_size_bytes`（Linux `/proc/self/status`；其他平台返回 1006） |

`GogcStat` 字段映射：`inuse`=`inuse`(heap_size)、`unmapped`=`objcnt`、`total_bytes`=`cgocall`、`bytes_since_gc`=`x`、`obtained_from_os`=`alloc`。`gc_parallel` 来自 `GC_get_parallel()`（本机 BDWGC 未提供 `GC_count_threads()`，故以并行度代替 GC 活跃线程数）。

错误码：`1001` bad_request、`1002` unknown_cmd、`1003` bad_args、`1004` internal、`1005` too_large、`1006` unsupported。

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

注意：导入 `vcp.gc` 会影响进程级 BDWGC 参数；导入 `vcp.yco` 会链接 corona 运行库。
