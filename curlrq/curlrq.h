#ifndef CURLRQ_H
#define CURLRQ_H

/**
 * curlrq - rolling curl request queue engine
 * 基于 libcurl multi 接口 + pthread 的并发 HTTP 请求引擎
 *
 * 核心特点:
 *   - 使用 curl_multi_perform 实现滚动并发窗口
 *   - Worker 线程自动管理请求生命周期
 *   - 所有任务完成后线程等待，新任务自动唤醒
 *   - 并发数可控（不超过 3）
 *   - 通过回调返回结果，不阻塞调用方
 */

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ------------------------------------------------------------------ */
/*  请求配置结构体                                                      */
/* ------------------------------------------------------------------ */

/**
 * curlrq_request_t - 单个 HTTP 请求的配置参数
 *
 * 创建请求时填充此结构体，然后传给 curlrq_add()。
 * 调用 curlrq_add() 后会拷贝所需数据，调用方可安全释放原数据。
 */
typedef struct {
    const char          *url;               /* 请求 URL（必填） */
    const char          *method;            /* HTTP 方法，NULL 或 "GET" 表示 GET 请求 */
    const char          *body;              /* 请求体（POST/PUT 等使用） */
    size_t               body_len;          /* 请求体长度，0 表示自动 strlen */
    /**
     * 自定义请求头
     * NULL-terminated 字符串数组，如:
     *   const char *headers[] = {"Content-Type: application/json", "X-Custom: val", NULL};
     * 传 NULL 表示无额外请求头
     */
    const char * const  *headers;
    long                 timeout_ms;        /* 总超时（毫秒），0 表示 libcurl 默认 */
    long                 connect_timeout_ms;/* 连接超时（毫秒），0 表示 libcurl 默认 */
    long                 max_response_size; /* 响应 body 最大字节数，0 表示无限制 */
    int                  verify_ssl;        /* 是否验证 SSL 证书: 1=验证，0=跳过 */
    void                *user_data;         /* 用户自定义数据，回调时原样传回 */
} curlrq_request_t;

/* ------------------------------------------------------------------ */
/*  响应结果结构体                                                      */
/* ------------------------------------------------------------------ */

/**
 * curlrq_response_t - 请求完成后的响应结果
 *
 * 回调函数接收此结构体。使用完后需调用 curlrq_response_free() 释放内部缓存。
 */
typedef struct {
    int    http_code;               /* HTTP 状态码（如 200/404/500），请求失败时为 0 */
    long   total_time_ms;           /* 请求总耗时（毫秒） */
    char  *response_body;           /* 响应 body 数据（malloc 分配） */
    size_t response_body_len;       /* 响应 body 长度 */
    char  *response_headers;        /* 原始响应头（完整字符串，malloc 分配） */
    size_t response_headers_len;    /* 响应头字符串长度 */
    char  *effective_url;           /* 最终请求 URL（跟随重定向后） */
    int    curl_code;               /* libcurl 返回码，CURLE_OK 表示成功 */
    char  *error_msg;              /* 错误描述，成功时为 NULL（malloc 分配） */
} curlrq_response_t;

/* ------------------------------------------------------------------ */
/*  回调函数类型                                                       */
/* ------------------------------------------------------------------ */

/**
 * curlrq_callback_t - 请求完成回调函数类型
 * @param resp     响应结果（内存由引擎分配，回调返回后可通过 curlrq_response_free 释放）
 * @param user_data 创建请求时传入的 user_data
 */
typedef void (*curlrq_callback_t)(curlrq_response_t *resp, void *user_data);

/* ------------------------------------------------------------------ */
/*  引擎句柄（不透明）                                                  */
/* ------------------------------------------------------------------ */

typedef struct curlrq_engine_s curlrq_engine_t;

/* ------------------------------------------------------------------ */
/*  API 函数                                                           */
/* ------------------------------------------------------------------ */

/**
 * curlrq_init - 创建请求引擎
 * @param max_concurrent 最大并发请求数（不超过 3）
 * @return 引擎句柄，失败返回 NULL
 *
 * Worker 线程首次 curlrq_add 时惰性创建，空闲 5 秒后自动退出。
 */
curlrq_engine_t *curlrq_init(int max_concurrent);

/**
 * curlrq_cleanup - 销毁引擎，等待所有请求完成
 * @param engine 引擎句柄
 *
 * 阻塞等待所有活跃请求完成，调用未启动请求的回调（返回错误状态），
 * 然后停止 Worker 线程并释放所有资源。
 */
void curlrq_cleanup(curlrq_engine_t *engine);

/**
 * curlrq_add - 添加 HTTP 请求（非阻塞）
 * @param engine 引擎句柄
 * @param req    请求配置（内部会拷贝所需数据）
 * @param cb     完成回调函数
 * @return 0 成功，-1 失败
 *
 * 请求加入内部队列，Worker 线程自动调度执行。
 * 当并发数未满时立即启动，否则排队等待。
 *
 * 注意：如果引擎正在销毁（curlrq_cleanup 已调用），
 * 新请求会被拒绝并返回 -1。
 */
int curlrq_add(curlrq_engine_t *engine, const curlrq_request_t *req, curlrq_callback_t cb);

/**
 * curlrq_set_max_queue_len - 设置最大队列长度
 * @param engine 引擎句柄
 * @param max_len 最大长度，0=无限制（默认）
 *
 * 超过最大长度的 curlrq_add 会返回 -1。
 * 可在引擎运行中动态调整，不影响已在队列中的请求。
 */
void curlrq_set_max_queue_len(curlrq_engine_t *engine, int max_len);

/**
 * curlrq_set_default_timeout_ms - 设置引擎级默认总超时
 * @param engine 引擎句柄
 * @param ms 毫秒，0=libcurl 默认
 *
 * 所有 curlrq_add 未指定 timeout_ms 的请求继承此值。
 */
void curlrq_set_default_timeout_ms(curlrq_engine_t *engine, long ms);

/**
 * curlrq_set_default_connect_timeout_ms - 设置引擎级默认连接超时
 */
void curlrq_set_default_connect_timeout_ms(curlrq_engine_t *engine, long ms);

/**
 * curlrq_set_default_max_response_size - 设置引擎级默认响应上限
 * @param engine 引擎句柄
 * @param size 字节数，0=无限制
 */
void curlrq_set_default_max_response_size(curlrq_engine_t *engine, long size);

/**
 * curlrq_set_default_verify_ssl - 设置引擎级默认 SSL 验证策略
 * @param engine 引擎句柄
 * @param verify 1=验证，0=跳过
 *
 * 注意：此值会覆盖所有请求的 verify_ssl 设置。
 */
void curlrq_set_default_verify_ssl(curlrq_engine_t *engine, int verify);

/**
 * curlrq_set_default_header - 添加引擎级默认请求头
 * @param engine 引擎句柄
 * @param header 如 "X-API-Key: abc123"（内部会拷贝）
 *
 * 所有请求自动携带此头。可多次调用添加多个头。
 * 请求自身同名头会覆盖引擎默认头。
 */
void curlrq_set_default_header(curlrq_engine_t *engine, const char *header);

/**
 * curlrq_wait - 等待所有待处理请求完成
 * @param engine 引擎句柄
 *
 * 阻塞直到队列和活跃请求均为空。
 */
void curlrq_wait(curlrq_engine_t *engine);

/**
 * curlrq_pending - 获取队列中等待的请求数
 */
int curlrq_pending(curlrq_engine_t *engine);

/**
 * curlrq_active - 获取正在执行的请求数
 */
int curlrq_active(curlrq_engine_t *engine);

/**
 * curlrq_response_free - 释放响应数据结构体内部缓存
 * @param resp 响应结果（不 free 结构体本身，仅释放内部成员）
 *
 * 回调中收到 resp 后，若不再需要其内部数据，调用此函数释放。
 * 或将内部成员指针取出后自行管理。
 */
void curlrq_response_free(curlrq_response_t *resp);

#ifdef __cplusplus
}
#endif

#endif /* CURLRQ_H */
