# touse.psutil 对齐说明（P0）

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

## 本批不做

- `Process` 类的完整 pypi 方法集
- 系统级 `cpu_*` / `virtual_memory` / `disk_*` / `net_*`
- `sensors_*`、`win_service_*`、`heap_*`
