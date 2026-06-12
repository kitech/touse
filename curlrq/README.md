# curlrq — rolling curl request queue

基于 libcurl multi 接口 + pthread 的并发 HTTP 请求引擎，使用 C99 编写。

## 特性

- **滚动并发窗口** — 使用 `curl_multi_perform` 实现，请求完成立即启动下一个，无需等待整批结束
- **惰性线程** — Worker 线程首次 `curlrq_add` 时创建，空闲 5 秒后自动退出，不浪费资源
- **队列上限** — 可设置最大排队长度，超限时 `curlrq_add` 返回 -1
- **关闭保护** — 引擎销毁期间新请求被拒绝，避免并发丢失
- **并发控制** — 最大并发数硬限制为 3，可在初始化时设置
- **请求方法** — 支持 GET、POST、HEAD、PUT、DELETE、PATCH 等任意 HTTP 方法
- **自定义请求头** — 支持任意数量的自定义 Header
- **请求体** — 支持 POST/PUT 等携带请求体
- **超时控制** — 独立设置连接超时和总超时（毫秒）
- **响应头收集** — 原始响应头完整保留
- **响应大小限制** — 超过限制自动中断传输
- **SSL 验证可配置** — 开启或跳过证书验证
- **请求耗时统计** — 毫秒精度
- **HTTP 状态码** — 原始状态码（如 200/404/500）
- **回调驱动** — 请求完成后通过回调返回结果，不阻塞调用方
- **引擎默认值** — 可设置全局默认超时/SSL/响应上限/请求头，请求未指定时自动继承

## 快速开始

```c
#include "curlrq.h"
#include <curl/curl.h>

static void on_done(curlrq_response_t *resp, void *user_data) {
    printf("HTTP %d, %ld ms, body=%zu bytes\n",
           resp->http_code, resp->total_time_ms, resp->response_body_len);
    curlrq_response_free(resp);  /* 回调负责释放响应数据 */
}

int main(void) {
    curl_global_init(CURL_GLOBAL_ALL);

    curlrq_engine_t *eng = curlrq_init(3);   /* 最大 3 并发 */

    curlrq_request_t req = {
        .url        = "http://example.com",
        .method     = "GET",
        .timeout_ms = 5000,
        .verify_ssl = 0,
        .user_data  = (void *)(long)1,
    };
    curlrq_add(eng, &req, on_done);

    curlrq_wait(eng);
    curlrq_cleanup(eng);
    curl_global_cleanup();
    return 0;
}
```

编译:
```bash
cc -std=c99 -Wall -Wextra -o example example.c curlrq.c -lcurl -lpthread
```

## API 文档

### curlrq_request_t — 请求配置

| 字段 | 类型 | 说明 |
|------|------|------|
| `url` | `const char *` | 请求 URL（必填） |
| `method` | `const char *` | HTTP 方法，NULL/"GET"=GET，"POST"=POST，"HEAD"=HEAD，其余自动设置 CUSTOMREQUEST |
| `body` | `const char *` | 请求体 |
| `body_len` | `size_t` | 请求体长度，0=自动 strlen |
| `headers` | `const char * const *` | 自定义头，NULL-terminated 字符串数组 |
| `timeout_ms` | `long` | 总超时（毫秒），0=继承引擎默认或 libcurl 默认 |
| `connect_timeout_ms` | `long` | 连接超时（毫秒），0=继承引擎默认或 libcurl 默认 |
| `max_response_size` | `long` | 响应 body 最大字节数，0=继承引擎默认或无限制 |
| `verify_ssl` | `int` | SSL 验证：1=开启，0=跳过 |
| `user_data` | `void *` | 用户自定义数据，回调中原样返回 |

### curlrq_response_t — 响应结果

| 字段 | 类型 | 说明 |
|------|------|------|
| `http_code` | `int` | HTTP 状态码，失败为 0 |
| `total_time_ms` | `long` | 请求总耗时（毫秒） |
| `response_body` | `char *` | 响应 body（malloc，需 free） |
| `response_body_len` | `size_t` | 响应 body 长度 |
| `response_headers` | `char *` | 原始响应头（malloc，需 free） |
| `response_headers_len` | `size_t` | 响应头长度 |
| `effective_url` | `char *` | 最终 URL（跟随重定向后） |
| `curl_code` | `int` | libcurl 返回码，CURLE_OK=成功 |
| `error_msg` | `char *` | 错误描述，成功时为 NULL |

### 函数

| 函数 | 说明 |
|------|------|
| `curlrq_init(max_concurrent)` | 创建引擎，首次 curlrq_add 时启动 Worker 线程 |
| `curlrq_cleanup(engine)` | 销毁引擎，等待所有请求完成 |
| `curlrq_add(engine, req, cb)` | 添加请求（非阻塞），队列满或引擎关闭时返回 -1 |
| `curlrq_wait(engine)` | 阻塞等待所有请求完成 |
| `curlrq_pending(engine)` | 查询队列中等待数 |
| `curlrq_active(engine)` | 查询正在执行数 |
| `curlrq_response_free(resp)` | 释放响应内部缓存 |
| `curlrq_set_max_queue_len(engine, max_len)` | 设置队列最大长度，0=无限制（默认） |
| `curlrq_set_default_timeout_ms(engine, ms)` | 设置引擎级默认总超时 |
| `curlrq_set_default_connect_timeout_ms(engine, ms)` | 设置引擎级默认连接超时 |
| `curlrq_set_default_max_response_size(engine, size)` | 设置引擎级默认响应上限 |
| `curlrq_set_default_verify_ssl(engine, verify)` | 设置引擎级默认 SSL 验证 |
| `curlrq_set_default_header(engine, header)` | 添加引擎级默认请求头 |

## 注意事项

1. **线程安全**：回调在 Worker 线程中执行，如果回调中访问共享数据需要自行加锁
2. **内存管理**：响应中的 `response_body`、`response_headers`、`error_msg` 由引擎 malloc 分配，回调中调用 `curlrq_response_free()` 释放
3. **并发限制**：`max_concurrent` 建议不超过 3。引擎会硬限制最大值不超过 `CURLRQ_MAX_CONCURRENT`（3）
4. **libcurl 初始化**：使用引擎前需要在主线程调用 `curl_global_init()`，引擎关闭后调用 `curl_global_cleanup()`
5. **队列上限**：默认无限制。通过 `curlrq_set_max_queue_len()` 设置后，队列满时 `curlrq_add()` 返回 -1
6. **空闲超时**：Worker 线程空闲 5 秒后自动退出，下次 `curlrq_add()` 重新创建
7. **关闭安全**：`curlrq_cleanup()` 已调用后，`curlrq_add()` 立即返回 -1，不丢失请求
8. **引擎默认值**：timeout/connect_timeout/max_response_size 用 0 表示"继承引擎默认"；verify_ssl 引擎默认值设置后覆盖所有请求；default_header 可多次调用添加多个头，请求同名头可覆盖引擎默认

## V 语言绑定

在 V 代码中通过 `#flag` 和 `#include` 直接调用 C API：

```v
#flag -lcurl
#include "curlrq.h"

fn main() {
    C.curl_global_init(CURL_GLOBAL_ALL)
    eng := C.curlrq_init(3)
    // ...
}
```

更完整的绑定见同目录下的 `curlrq.v`。

## 参考项目

- **RollingCurl** (PHP) — 滚动窗口并发 cURL 库，curlrq 的直接设计参考
- **a-curl-library** (C) — 高级异步 HTTP 客户端框架，支持速率限制、请求依赖、插件系统
- **RESTinCurl** (C++) — header-only libcurl 封装，惰性线程 + 空闲超时设计与 curlrq 一致
