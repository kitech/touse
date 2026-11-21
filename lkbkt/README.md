# lkbkt — 从 nginx 抽取的独立 C 漏桶

把 nginx `ngx_http_limit_req_module`（`src/http/modules/ngx_http_limit_req_module.c`）
的**漏桶算法**抽成一个不依赖 nginx、可单独编译的 C 库。

- 算法逐式复刻，单位与 nginx 完全一致；
- 数据结构重写（nginx 用 rbtree + 共享内存队列，这里用哈希表 + LRU）；
- 只依赖 `libc`，默认单线程、无锁；可通过宏开启 pthread 互斥。

## 文件

| 文件 | 说明 |
|---|---|
| `leakybucket.h` | 公开 API |
| `leakybucket.c` | 实现 |
| `example.c` | 演示：10 r/s + burst=5，逐请求打印 PASS/DELAY/REJECT |
| `lkbkt_test.c` | 行为测试 |
| `ALTERNATIVES.md` | ≥2★ 备选实现清单 |
| `Makefile` | 构建 / 测试 / sanitizer |

## 算法（与 nginx 一致）

单位全部放大 1000 倍，用整数避免浮点：

```
rate   = rate_per_sec * 1000      // 毫请求/秒
burst  = burst_requests * 1000    // 毫请求
delay  = delay_requests * 1000    // 毫请求
excess: 当前水位（毫请求），1000 == 1 个请求

每次请求：
  ms     = now_ms - last_ms
  leak   = rate * ms / 1000
  excess = excess - leak + 1000           // 加 1000 表示本次请求
  if (excess < 0) excess = 0
  if (excess > burst)  -> REJECT，且不修改状态
  else if (excess > delay)
      wait_ms = (excess - delay) * 1000 / rate  -> DELAY
  else -> PASS
```

对时钟的容错也与 nginx 相同：`ms < 0` 视为 0，`ms < -60000` 视为 1。
新 key 首次请求：`excess = 0, last = now`，因此**首个请求必过**（这是 nginx 的实际行为）。

## 三种模式 ↔ nginx 配置

| nginx 配置 | API | 行为 |
|---|---|---|
| `limit_req zone=z burst=5;`（默认） | `lkbkt_new(rate, 5, 0, n)` | 超出速率的请求被延迟，超过 burst 拒绝 |
| `limit_req ... burst=5 nodelay;` | `lkbkt_new(rate, 5, LKBKT_NODELAY, n)` | burst 内直接放行，超过 burst 拒绝 |
| `limit_req ... burst=5 delay=2;` | `lkbkt_new(rate, 5, 2, n)` | 前 2 个超量直接放行，之后延迟，超过 burst 拒绝 |

## 用法

```c
#include "leakybucket.h"

lkbkt_t *lkb = lkbkt_new(10, 5, LKBKT_NODELAY, 1024); /* 10 r/s, burst 5 */
if (!lkb) { /* 处理错误 */ }

uint32_t wait_ms = 0;
lkbkt_result r = lkbkt_check(lkb, ip, strlen(ip), now_ms(), &wait_ms);

switch (r) {
case LKBKT_PASS:   /* 立即处理 */ break;
case LKBKT_DELAY:  /* sleep(wait_ms) 后处理，或返回 Retry-After */ break;
case LKBKT_REJECT: /* 返回 429 */ break;
case LKBKT_ERROR:  /* 参数/内存错误 */ break;
}

lkbkt_free(lkb);
```

`now_ms` 由调用方提供（单调时钟），这样核心可确定性地测试：

```c
uint64_t now_ms(void) { struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000u + (uint64_t)ts.tv_nsec / 1000000u; }
```

## 构建与测试

```sh
make          # 生成 example 和 tests
make test     # 运行断言
./example     # 查看 PASS/DELAY/REJECT 序列
make asan     # AddressSanitizer + UBSan
```

## 与 nginx 的差异

| 方面 | nginx | lkbkt |
|---|---|---|
| 存储 | 共享内存 slab | 普通 `malloc` |
| 索引 | 红黑树 | 链式哈希表（FNV-1a） |
| 过期 | `ngx_queue` 队尾 | 侵入式 LRU 双向链表 |
| 时钟 | `ngx_current_msec` | 调用方传入 `now_ms` |
| 多进程/多线程 | 共享内存自旋锁 | 默认单线程；`-DLKBKT_THREAD_SAFE` 启用 `pthread_mutex` |
| 延迟实现 | 事件循环定时器 | 返回 `wait_ms`，由调用方 sleep/排队 |
| 在途计数 | `lr->count` 防止节点被删 | 同步 `check` 无在途状态，省略 |

容量策略：`max_keys` 满时按 LRU 淘汰最旧 key（nginx 是先尝试回收「空闲且已漏干」的节点，
分配失败才强制删最旧节点）。显式回收用 `lkbkt_expire()`，规则对齐 nginx：空闲 ≥60 s
且水位已漏干才删。

## 复杂度

- `lkbkt_check`：哈希查找 O(1) 均摊；`memcmp` 与 key 长度成正比。
- 插入/淘汰：O(1)。
- 过期扫描：只从 LRU 尾部批量清理，均摊 O(1)。

## 来源与许可

算法来源于 nginx（BSD-2-Clause），本目录为**重新实现**（非逐行复制），
数据结构与内存管理均为新写。
