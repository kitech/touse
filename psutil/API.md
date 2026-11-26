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

## P2: 系统级 API

新增 `sysinfo.h` / `sysinfo.c` / `sysinfo.v` 与 `system.v`，对齐 pypi psutil 7.2.x
的系统级公共函数：

- CPU：`cpu_times(percpu bool)`、`cpu_percent(interval f64, percpu bool)`、
  `cpu_times_percent(interval f64, percpu bool)`、`cpu_count(logical bool)`、
  `cpu_stats()`
- 内存：`virtual_memory()`、`swap_memory()`
- 磁盘：`disk_partitions(all bool)`、`disk_usage(path string)`、
  `disk_io_counters(perdisk bool)`
- 网络：`net_io_counters(pernic bool)`、`net_connections(kind string)`、
  `net_if_addrs()`、`net_if_stats()`
- 其他：`boot_time()`、`users()`

签名边界：

- V 无重载且不支持 `!?[]T`；`cpu_times` / `cpu_percent` / `cpu_times_percent`
  恒定返回列表，`percpu=false` 时长度为 1。
- `disk_io_counters(perdisk=false)` 与 `net_io_counters(pernic=false)` 也恒定返回
  列表：聚合值为长度 1，无数据时为空列表。
- 可空字段使用 `?f64` / `?string` / `?int`；例如 `NicAddr.netmask`、
  `SystemConnection.pid`、`SystemUser.terminal`。
- `cpu_percent(0, ...)` 与 `cpu_times_percent(0, ...)` 首次返回 0，之后使用进程内
  缓存计算；`interval > 0` 时先 seed 缓存再 sleep，语义与 pypi 一致。
- `net_connections(kind)` 支持 `inet`、`inet4`、`inet6`、`tcp`、`tcp4`、`tcp6`、
  `udp`、`udp4`、`udp6`、`unix`、`all`；非法 kind 返回 `err_invalid_arg`。

实现与平台策略：

- Linux 按 pypi 7.2.x 算法读取 `/proc`、`/sys`、`getifaddrs`、utmp；
  `virtual_memory.available` 优先 `MemAvailable`，缺失或为 0 时回退 procps 估算；
  `cached` 包含 `SReclaimable`；`used = total - available`。
- `net_if_stats` 的 flags 用 `SIOCGIFFLAGS`（sysfs 的 flags 文件不含 volatile
  running 位），duplex/speed/mtu 仍读 sysfs。
- `users()` 对齐 pypi 的 `USER_PROCESS` 过滤，并把 utmp 的 `:0` 显示主机映射为
  `localhost`。
- macOS / Windows 保留同名入口，但未在本机验证，统一返回 `err_unsupported`，
  不伪造 0 / 空值；需在 CI / 实机补齐后再声明支持。

## P3: 补充 API

新增 `extra.h` / `extra.c` / `extra.v` 与 `p3api.v`，补齐 pypi psutil 7.2.x
的剩余公共入口；Linux 实现用 `/proc`、sysfs、`prlimit()`、`mallinfo2()`，
其余平台保留同名入口并返回 `err_unsupported`，不伪造 0 / 空值。

- 进程快照：`Process.oneshot()` / `oneshot(pid) !OneShot`。V 无 `with`
  语义，改为一次性按值快照；Linux 只读一次 `/proc/<pid>/stat`、
  `/proc/<pid>/status`、`/proc/<pid>/statm`。字段与逐方法一致：`name`、
  `ppid`、`uids`、`gids`、`status`、`create_time`、`cpu_times`、`terminal`、
  `num_threads`、`memory_info`。
- 资源限制：`Process.rlimit(resource)`、`Process.set_rlimit(resource, soft, hard)`、
  `rlimit_of(pid, resource)`、`set_rlimit_of(...)`。Linux 用 `prlimit()`，
  `RLIM_INFINITY` 映射为 `-1`；`rlimit_cpu` 到 `rlimit_rttime` 常量对齐
  `/usr/include/bits/resource.h`。
- 环境变量：`Process.environ()` / `process_environ(pid) !map[string]string`。
  `environ()` 是 pypi 的跨平台方法，Linux 读 `/proc/<pid>/environ`，
  按 pypi 规则跳过无 `=` 的段，遇到空段停止；C 侧返回 key/value 数组，
  避免 V 侧处理内嵌 NUL。
- 扩展标识：`ProcessIdentity{pid, create_time}` 与 `Process.identity()`。
  pypi 私有 `_get_ident()` 返回相同的 `(pid, create_time)`，这里作为 V 扩展封装，
  不宣称为 pypi 公共 API。
- WindowsService 方法：`Process.description()` / `Process.start_type()` 在
  非 Windows 返回 `err_unsupported`；`WindowsService` 提供 `name`、
  `display_name`、`binpath`、`username`、`start_type`、`pid`、`status`、
  `description`、`as_dict`。`win_service_iter()` / `win_service_get(name)`
  在本机返回 `err_unsupported`，不会用空列表伪装成“无服务”。
- 传感器：`Shwtemp{name, label, current, high, critical}`、
  `sensors_temperatures(fahrenheit bool) !map[string][]Shwtemp`；`name` 是
  sysfs 传感器编号（如 `temp1`），`label` 是 `_label`，map 的 key 是芯片名。
  `Sfan{name, speed}` 与 `sensors_fans()` 同理。`Battery{percent, secsleft,
  power_plugged}` 与 `sensors_battery() ![]Battery` 返回长度 0 或 1，常
  量 `power_time_unknown=-1`、`power_time_unlimited=-2`。
- 堆：`HeapInfo{heap_used, mmap_used, heap_count}`、`heap_info()`、
  `heap_trim()`。Linux glibc 用 `mallinfo2()` 的 `uordblks` / `hblkhd`，
  `malloc_trim(0)`；`heap_count` 固定为 0，表示无法从 glibc 得到独立堆数量。

签名边界：

- 可空字段使用 `?f64` / `?bool` / `?u64`；例如 `Shwtemp.high`、
  `Battery.power_plugged`、`MemoryInfo.text`。
- C shim 数组上限：环境变量 1024 项、温度/风扇各 512 项、Windows 服务 1024 项；
  超出部分截断，不返回错误。
- `sensors_temperatures(true)` 同时转换 `current`、`high`、`critical`；
  pypi 中 high/critical 缺失时互相补位的行为也保留。
