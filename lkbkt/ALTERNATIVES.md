# 备选实现清单（≥ 2 星）

> 检索日期：2026-11-21，数据来自 GitHub API / ungh.cc。
> GitHub 直接搜 `leaky bucket language:C` 的结果几乎全是 0–2★ 的课程作业
> （`ahmethedev/Leaky-Bucket`、`renuthomas/LeakyBucket`、`torcodex/Leaky_Bucket` 等），
> 不具备生产参考价值，已排除。阈值取「≥ 2 星」。

## 独立 / 可嵌入的库

| 仓库 | 星 | 算法 | 形态 | 真漏桶 | 可嵌入性 | 结论 |
|---|---:|---|---|---|---|---|
| [nand2/libvmod-throttle](https://github.com/nand2/libvmod-throttle) | 100 | 时间窗限速 | Varnish VMOD (C) | 否 | 中（依赖 Varnish） | 成熟但 2015 后停更 |
| [weserv/rate-limit-nginx-module](https://github.com/weserv/rate-limit-nginx-module) | 47 | 外部计数（Redis/Valkey） | nginx 模块 | 否 | 低（依赖 KV） | 2026 仍活跃 |
| [qmonnet/tbpoc-bpf](https://github.com/qmonnet/tbpoc-bpf) | 41 | token bucket | eBPF/tc PoC | 否 | 中（需内核 + eBPF） | 网络层限速参考 |
| [jart/tokenbucket](https://github.com/jart/tokenbucket) | 35 | token bucket | 单文件 ~92 行 | 否 | 高 | C11 原子无锁，redbean 生产在用 |
| [jedisct1/ratelimit](https://github.com/jedisct1/ratelimit) | 26 | Count-Min Sketch | `.c` + `.h` 两文件 | 否 | 高 | libsodium 作者，copy-in 即用 |
| [cfsego/limit_upload_rate](https://github.com/cfsego/limit_upload_rate) | 21 | 速率限制 | 小库 (C) | 否 | 中 | 上传限速 |
| [onsigntv/redis-rate-limiter](https://github.com/onsigntv/redis-rate-limiter) | 19 | GCRA（漏桶变体） | Redis Module (C) | 近似 | 低（依赖 Redis） | 语义最接近漏桶 |
| [mvv/nf_tbf](https://github.com/mvv/nf_tbf) | 2 | token bucket | netfilter queue | 否 | 低（需内核模块环境） | 参考价值有限 |

## 非独立库（成熟度最高，但难剥离）

| 项目 | 算法 | 说明 |
|---|---|---|
| nginx `ngx_http_limit_req_module.c` | **真漏桶** | 事实标准；本目录 `leakybucket.c` 即复刻它 |
| Linux `net/sched/sch_tbf.c` | token bucket | 内核 qdisc，`tc tbf` |
| FreeBSD `dummynet` / OpenBSD ALTQ | 多种整形 | 内核 C，难抽取 |

## 结论

- 需要**真漏桶**语义：目前只有 nginx 的 `limit_req` 是成熟参考，因此本目录直接复刻它。
- 需要**小、可嵌入**：`jart/tokenbucket`（92 行）与 `jedisct1/ratelimit`（两文件）质量最好，
  但它们属于 token bucket / Count-Min Sketch，不是漏桶。
- C 生态里不存在「独立、成熟、纯漏桶、仅 `.c`/`.h`」的库——与之前 MCP client 的调研结论一致：
  成熟实现都长在 nginx / kernel 这类大项目内部。

## 按场景选型

| 场景 | 推荐 |
|---|---|
| 单机、按 key（IP/用户）限流、真漏桶 | **本目录 `lkbkt`** |
| 只要极小、无锁、allow/deny | `jart/tokenbucket` |
| 想直接 copy 两个文件、近似限流 | `jedisct1/ratelimit` |
| 网络层（tc/eBPF）限速 | `qmonnet/tbpoc-bpf`、Linux `sch_tbf.c` |
| 多实例共享计数 | `onsigntv/redis-rate-limiter`、`weserv/rate-limit-nginx-module` |
