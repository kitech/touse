# touse.psutil 对齐说明

## 破坏性改名

- `pids()` 从 `map[int]int` 改为 `![]int`，对齐 pypi `psutil.pids()`，结果排序。
- 旧 pid→ppid 语义改名为 `pids_map() !map[int]int`。
- `MemoryInfo` 字段直接改为 pypi 风格：`vms`、`rss`、`shared`；不再保留 `virt/res/shrd`。

## 新增 API

- `pid_exists(pid int) bool`
- `process_name(pid int) !string`
- `cmdline_list(pid int) ![]string`
- `memory_info(pid int) !MemoryInfo`
- `thread_list_ex() !ThreadList`，在 `thread_list()` 基础上返回 `truncated`
- `ThreadInfo` 增加 `id`、`user_time`、`system_time`

## 平台策略

- 进程枚举不再直接依赖 `/proc`：Linux 用 `/proc`，macOS 用 `libproc`，Windows 用 Toolhelp，统一放在 `psproc.c`。
- macOS 线程实现按 pypi psutil 7.2.0 的 API 代际：
  - `Process.threads()` 对齐目标使用 `task_threads` + `THREAD_BASIC_INFO`，`id` 为索引 + 1。
  - 不引入 `THREAD_EXTENDED_INFO`（macOS 10.11+），避免抬高旧系统要求。
  - 线程名用 `pthread_getname_np`，旧 SDK 下通过编译宏保护，失败时为空。
- Windows `THREADENTRY32` 无 name 字段，线程名保持为空；状态为 `?`。

## 兼容包装

- `cmdline(pid) string` 保留，但内部改为空格拼接 `cmdline_list()`。
- `process_memory(pid) !MemoryInfo`、`my_process_memory() !MemoryInfo` 保留旧函数名。
- `thread_list()` 签名不变，`vrtinfo` 无需改动。

## P1: Process 公共方法集

`new_process(pid)` / `process_from_pid(pid)` / `current_process()` 对应 pypi 的
`Process(pid)`；`Process` 只保存 `pid`，所有属性按需查询。

已覆盖的 pypi `Process` 方法：

- 标识与父子：`pid`、`name`、`exe`、`cwd`、`cmdline`、`ppid`、`parent`、`parents`、`children`、`is_running`
- 身份与状态：`status`、`username`、`uids`、`gids`、`terminal`、`create_time`（`terminal` 无控制终端时返回空串，对应 pypi 的 `None`）
- 调度与 CPU：`nice`、`set_nice`、`ionice`、`set_ionice`、`cpu_affinity`、`set_cpu_affinity`、`num_ctx_switches`、`num_threads`、`cpu_times`、`cpu_percent`
- 内存：`memory_info`、`memory_full_info`、`memory_percent`；`MemoryInfo` 扩展 Linux `text/lib/data/dirty`
- IO 与文件：`io_counters`、`num_fds`、`num_handles`、`open_files`、`memory_maps`
- 网络：`net_connections`、`connections`（`kind='unix'` 走 Unix socket，其余走 inet 表）
- 进程控制：`send_signal`、`suspend`、`resume`、`terminate`、`kill`、`wait`
- 辅助：`as_dict(attrs, ad_value) map[string]string`（V 0.5 无通用 `any`，值统一字符串化）、`process_iter`、`wait_procs`

错误语义：

- 新增 `ProcessError` 与 `err_no_such_process`、`err_access_denied`、`err_zombie_process`、
  `err_timeout_expired`、`err_unsupported`、`err_invalid_arg`。
- C shim 的状态码映射为带类型的错误；平台不支持的方法返回 `err_unsupported`，不伪造 0/空值。
- `signal_term_value()` / `signal_kill_value()` / `signal_stop_value()` / `signal_cont_value()`
  返回当前平台的信号值。

平台策略：

- Linux 的新增 Process 查询走 `psproc_query.c`，使用 `/proc`、syscall 与标准 POSIX API。
- macOS / Windows 的 `exe`、`cwd`、`status`、`身份`、`create_time`、`cpu_times`、
  `num_threads`、`num_handles`、`io`、`affinity`、`ram_total` 等按各平台 API 实现；
  其余方法保留同名入口并返回 `err_unsupported`，待 CI/实机验证后再补齐。
- `psproc_query.c` 不调用 `vcp`，跨平台差异集中在 C shim 内。

## 仍不做

- `oneshot()` / `rlimit()`：V 无 `with` 语义，留后续适配。
- Windows 专属 `environ` / `description` / `identity` / `start_type`。
- 系统级 `cpu_*` / `virtual_memory` / `disk_*` / `net_*`。
- `sensors_*`、`win_service_*`、`heap_*`。
