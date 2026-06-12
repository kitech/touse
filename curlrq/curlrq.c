/**
 * curlrq.c - rolling curl request queue engine implementation
 * 基于 libcurl multi 接口 + pthread 的并发 HTTP 请求引擎实现
 *
 * 内部结构:
 *   - 请求队列 (request_node_t 单向链表)：待发请求
 *   - 活跃列表 (active_request_t 单向链表)：正在执行的请求
 *   - Worker 线程：运行 curl_multi_perform 循环，自动调度
 *   - 互斥锁 + 条件变量：线程安全的任务投递与唤醒
 */

#include "curlrq.h"

#define _POSIX_C_SOURCE 199309L  /* clock_gettime, CLOCK_REALTIME, ETIMEDOUT */
#include <curl/curl.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <time.h>
#include <errno.h>

/* ------------------------------------------------------------------ */
/*  内部常量                                                           */
/* ------------------------------------------------------------------ */

#define CURLRQ_MAX_CONCURRENT   3   /* 最大并发数硬限制 */
#define CURLRQ_MULTI_WAIT_MS   50   /* curl_multi_wait 超时(毫秒) */
#define CURLRQ_IDLE_TIMEOUT_SEC 5   /* Worker 线程空闲超时(秒) */

/* ------------------------------------------------------------------ */
/*  内部数据结构                                                       */
/* ------------------------------------------------------------------ */

/**
 * request_node_t - 队列节点
 * 内部持有请求配置的深层拷贝，确保外部数据释放后仍可安全使用。
 */
typedef struct request_node_s {
    curlrq_request_t     req;              /* 请求配置拷贝 */
    struct curl_slist   *headers;          /* 转换后的 curl_slist 链表 */
    curlrq_callback_t    callback;         /* 完成回调 */
    struct request_node_s *next;           /* 链表下一节点 */
} request_node_t;

/**
 * active_request_t - 活跃请求控制块
 * 每个正在执行的请求对应一个此结构体。
 */
typedef struct active_request_s {
    CURL                 *easy;            /* libcurl easy 句柄 */
    request_node_t       *node;            /* 原始请求数据 */
    char                 *url;             /* 拷贝的 URL */
    char                 *body;            /* 拷贝的请求体 */
    size_t                body_len;        /* 请求体长度 */
    struct curl_slist    *headers;         /* 请求头链表 */
    char                 *write_buf;       /* 响应 body 缓存 */
    size_t                write_len;       /* 已写入长度 */
    size_t                write_cap;       /* 缓存容量 */
    char                 *header_buf;      /* 响应头缓存 */
    size_t                header_len;      /* 已写入的头长度 */
    size_t                header_cap;      /* 头缓存容量 */
    struct active_request_s *next;         /* 链表下一节点 */
} active_request_t;

/**
 * curlrq_engine_s - 引擎主结构体
 */
struct curlrq_engine_s {
    int              max_concurrent;       /* 最大并发数（<=3） */
    int              active_count;         /* 当前活跃请求数 */
    int              shutdown;             /* 清理标志，1=正在关闭 */

    request_node_t  *queue_head;           /* 请求队列头 */
    request_node_t  *queue_tail;           /* 请求队列尾 */

    active_request_t *active_list;         /* 活跃请求链表 */

    CURLM           *multi;                /* curl multi 句柄 */

    pthread_mutex_t  mutex;                /* 保护队列+活跃列表 */
    pthread_cond_t   cond;                 /* 条件变量（新任务/关闭通知） */
    pthread_t        thread;               /* Worker 线程 ID */
    int              thread_running;       /* 0=无线程, 1=线程运行中 */
    int              max_queue_len;        /* 最大队列长度，0=无限制 */
    int              queue_len;            /* 当前队列长度 */

    /* 引擎级默认值 */
    long             default_timeout_ms;
    long             default_connect_timeout_ms;
    long             default_max_response_size;
    int              default_verify_ssl;
    struct curl_slist *default_headers;    /* 引擎级默认头链表 */
};

/* ------------------------------------------------------------------ */
/*  前向声明（内部函数）                                                */
/* ------------------------------------------------------------------ */

static void *worker_thread(void *arg);
static int  start_request(curlrq_engine_t *engine, request_node_t *node);
static void complete_request(curlrq_engine_t *engine, CURL *easy, CURLcode cr);
static void cleanup_active(curlrq_engine_t *engine, active_request_t *ar, CURLcode cr);
static void drain_queue(curlrq_engine_t *engine);

/* CURLOPT_WRITEFUNCTION / HEADERFUNCTION 回调 */
static size_t write_body_cb(void *data, size_t size, size_t nmemb, void *userp);
static size_t write_header_cb(void *data, size_t size, size_t nmemb, void *userp);

/* 工具函数 */
static char *strdup_safe(const char *s);
static struct curl_slist *build_slist(const char * const *headers);

/* ------------------------------------------------------------------ */
/*  公共 API 实现                                                      */
/* ------------------------------------------------------------------ */

curlrq_engine_t *curlrq_init(int max_concurrent)
{
    curlrq_engine_t *engine;

    /* 限制最大并发数 */
    if (max_concurrent < 1) max_concurrent = 1;
    if (max_concurrent > CURLRQ_MAX_CONCURRENT) max_concurrent = CURLRQ_MAX_CONCURRENT;

    engine = (curlrq_engine_t *)calloc(1, sizeof(*engine));
    if (!engine) return NULL;

    engine->max_concurrent = max_concurrent;
    engine->multi = curl_multi_init();
    if (!engine->multi) {
        free(engine);
        return NULL;
    }

    pthread_mutex_init(&engine->mutex, NULL);
    pthread_cond_init(&engine->cond, NULL);

    /*
     * 不启动 Worker 线程，首次 curlrq_add 时惰性创建。
     * 避免引擎空闲时也占用线程资源。
     */
    engine->thread_running = 0;
    engine->max_queue_len   = 0;    /* 默认无限制 */
    engine->queue_len       = 0;

    /* 引擎级默认值全部初始为 0（不生效） */
    engine->default_timeout_ms         = 0;
    engine->default_connect_timeout_ms = 0;
    engine->default_max_response_size  = 0;
    engine->default_verify_ssl         = 0;
    engine->default_headers            = NULL;

    return engine;
}

void curlrq_set_max_queue_len(curlrq_engine_t *engine, int max_len)
{
    if (!engine) return;
    pthread_mutex_lock(&engine->mutex);
    engine->max_queue_len = (max_len < 0) ? 0 : max_len;
    pthread_mutex_unlock(&engine->mutex);
}

void curlrq_set_default_timeout_ms(curlrq_engine_t *engine, long ms)
{
    if (!engine) return;
    pthread_mutex_lock(&engine->mutex);
    engine->default_timeout_ms = ms > 0 ? ms : 0;
    pthread_mutex_unlock(&engine->mutex);
}

void curlrq_set_default_connect_timeout_ms(curlrq_engine_t *engine, long ms)
{
    if (!engine) return;
    pthread_mutex_lock(&engine->mutex);
    engine->default_connect_timeout_ms = ms > 0 ? ms : 0;
    pthread_mutex_unlock(&engine->mutex);
}

void curlrq_set_default_max_response_size(curlrq_engine_t *engine, long size)
{
    if (!engine) return;
    pthread_mutex_lock(&engine->mutex);
    engine->default_max_response_size = size > 0 ? size : 0;
    pthread_mutex_unlock(&engine->mutex);
}

void curlrq_set_default_verify_ssl(curlrq_engine_t *engine, int verify)
{
    if (!engine) return;
    pthread_mutex_lock(&engine->mutex);
    engine->default_verify_ssl = verify ? 1 : 0;
    pthread_mutex_unlock(&engine->mutex);
}

void curlrq_set_default_header(curlrq_engine_t *engine, const char *header)
{
    if (!engine || !header || header[0] == '\0') return;
    pthread_mutex_lock(&engine->mutex);
    struct curl_slist *new_list = curl_slist_append(engine->default_headers, header);
    if (new_list) engine->default_headers = new_list;
    pthread_mutex_unlock(&engine->mutex);
}

void curlrq_cleanup(curlrq_engine_t *engine)
{
    if (!engine) return;

    pthread_mutex_lock(&engine->mutex);
    if (engine->thread_running) {
        /* 通知 Worker 线程关闭，等待退出 */
        engine->shutdown = 1;
        pthread_cond_broadcast(&engine->cond);
        pthread_mutex_unlock(&engine->mutex);
        pthread_join(engine->thread, NULL);
    } else {
        /* 无线程，无需 join */
        pthread_mutex_unlock(&engine->mutex);
    }

    /* 清理资源 */
    if (engine->default_headers) curl_slist_free_all(engine->default_headers);
    curl_multi_cleanup(engine->multi);
    pthread_mutex_destroy(&engine->mutex);
    pthread_cond_destroy(&engine->cond);
    free(engine);
}

int curlrq_add(curlrq_engine_t *engine, const curlrq_request_t *req, curlrq_callback_t cb)
{
    request_node_t *node;

    if (!engine || !req || !cb) return -1;
    if (!req->url || req->url[0] == '\0') return -1;

    /* 分配队列节点 */
    node = (request_node_t *)calloc(1, sizeof(*node));
    if (!node) return -1;

    /* 深层拷贝请求数据，未被用户显式设置的字段继承引擎默认值 */
    node->req.url               = strdup_safe(req->url);
    node->req.method            = strdup_safe(req->method);
    node->req.body              = strdup_safe(req->body);
    node->req.body_len          = (req->body && req->body_len == 0) ? strlen(req->body)
                                : (req->body ? req->body_len : 0);
    node->req.headers           = NULL;
    node->req.timeout_ms        = req->timeout_ms > 0 ? req->timeout_ms : engine->default_timeout_ms;
    node->req.connect_timeout_ms= req->connect_timeout_ms > 0 ? req->connect_timeout_ms
                                : engine->default_connect_timeout_ms;
    node->req.max_response_size = req->max_response_size > 0 ? req->max_response_size
                                : engine->default_max_response_size;
    node->req.verify_ssl        = (req->verify_ssl || !engine->default_verify_ssl)
                                ? req->verify_ssl : engine->default_verify_ssl;
    node->req.user_data         = req->user_data;

    /* 将请求头转为 curl_slist（不含引擎默认头，在 start_request 中合并） */
    if (req->headers) {
        node->headers = build_slist(req->headers);
    }

    node->callback = cb;
    node->next = NULL;

    /* 加入队列尾部 */
    pthread_mutex_lock(&engine->mutex);

    /*
     * 引擎正在清理中，拒绝新请求。
     * 避免 curlrq_cleanup 与 curlrq_add 并发时请求丢失。
     */
    if (engine->shutdown) {
        pthread_mutex_unlock(&engine->mutex);
        if (node->headers) curl_slist_free_all(node->headers);
        free((void *)node->req.url);
        free((void *)node->req.method);
        free((void *)node->req.body);
        free(node);
        return -1;
    }

    /*
     * 队列满检查。max_queue_len=0 表示无限制。
     */
    if (engine->max_queue_len > 0 && engine->queue_len >= engine->max_queue_len) {
        pthread_mutex_unlock(&engine->mutex);
        if (node->headers) curl_slist_free_all(node->headers);
        free((void *)node->req.url);
        free((void *)node->req.method);
        free((void *)node->req.body);
        free(node);
        return -1;
    }

    if (engine->queue_tail) {
        engine->queue_tail->next = node;
    } else {
        engine->queue_head = node;
    }
    engine->queue_tail = node;
    engine->queue_len++;

    /*
     * 惰性启动：无线程时创建新线程，已有线程则 signal 唤醒。
     * thread_running 在 mutex 保护下读写，避免竞态。
     */
    if (!engine->thread_running) {
        engine->thread_running = 1;
        if (pthread_create(&engine->thread, NULL, worker_thread, engine) != 0) {
            engine->thread_running = 0;
            pthread_mutex_unlock(&engine->mutex);
            /* 释放节点 */
            if (node->headers) curl_slist_free_all(node->headers);
            free((void *)node->req.url);
            free((void *)node->req.method);
            free((void *)node->req.body);
            free(node);
            return -1;
        }
    } else {
        pthread_cond_broadcast(&engine->cond);
    }
    pthread_mutex_unlock(&engine->mutex);

    return 0;
}

void curlrq_wait(curlrq_engine_t *engine)
{
    if (!engine) return;

    pthread_mutex_lock(&engine->mutex);
    while (engine->queue_head != NULL || engine->active_count > 0) {
        pthread_cond_wait(&engine->cond, &engine->mutex);
    }
    pthread_mutex_unlock(&engine->mutex);
}

int curlrq_pending(curlrq_engine_t *engine)
{
    int count = 0;
    if (!engine) return 0;
    pthread_mutex_lock(&engine->mutex);
    for (request_node_t *n = engine->queue_head; n; n = n->next) count++;
    pthread_mutex_unlock(&engine->mutex);
    return count;
}

int curlrq_active(curlrq_engine_t *engine)
{
    int count = 0;
    if (!engine) return 0;
    pthread_mutex_lock(&engine->mutex);
    count = engine->active_count;
    pthread_mutex_unlock(&engine->mutex);
    return count;
}

void curlrq_response_free(curlrq_response_t *resp)
{
    if (!resp) return;
    free(resp->response_body);
    free(resp->response_headers);
    free(resp->effective_url);
    free(resp->error_msg);
}

/* ------------------------------------------------------------------ */
/*  Worker 线程主循环                                                  */
/* ------------------------------------------------------------------ */

static void *worker_thread(void *arg)
{
    curlrq_engine_t *engine = (curlrq_engine_t *)arg;

    while (1) {
        pthread_mutex_lock(&engine->mutex);

        /*
         * 如果队列空且无活跃请求，等待新任务或关闭信号。
         * 使用 pthread_cond_timedwait 带超时等待，空闲超时后线程自行退出。
         */
        while (engine->queue_head == NULL && engine->active_count == 0 && !engine->shutdown) {
            struct timespec ts;
            clock_gettime(CLOCK_REALTIME, &ts);
            ts.tv_sec += CURLRQ_IDLE_TIMEOUT_SEC;
            int rc = pthread_cond_timedwait(&engine->cond, &engine->mutex, &ts);
            if (rc == ETIMEDOUT) {
                /*
                 * 超时返回，需二次确认条件（超时期间可能有 curlrq_add 加入请求）。
                 * while 条件不满足（即有请求或 shutdown）则继续，否则在此退出。
                 */
                if (engine->queue_head == NULL && engine->active_count == 0 && !engine->shutdown) {
                    /* 真正空闲，退出线程 */
                    engine->thread_running = 0;
                    pthread_mutex_unlock(&engine->mutex);
                    return NULL;
                }
            }
        }

        /* 关闭处理：先等待所有活跃请求完成，再清理队列 */
        if (engine->shutdown) {
            if (engine->active_count > 0) {
                /* 还有活跃请求，继续处理 */
                pthread_mutex_unlock(&engine->mutex);
                goto do_multi;
            }
            /* 无活跃请求，清理队列中剩余请求 */
            drain_queue(engine);
            engine->thread_running = 0;
            pthread_mutex_unlock(&engine->mutex);
            break;
        }

        /*
         * 从队列取出请求，启动新的 HTTP 请求，
         * 直到达到最大并发数或队列为空。
         */
        while (engine->active_count < engine->max_concurrent && engine->queue_head != NULL) {
            request_node_t *node = engine->queue_head;
            engine->queue_head = node->next;
            if (engine->queue_tail == node) engine->queue_tail = NULL;
            node->next = NULL;
            engine->queue_len--;

            if (start_request(engine, node) != 0) {
                /* 启动失败，立即回调返回错误 */
                node->next = NULL;
                pthread_mutex_unlock(&engine->mutex);

                curlrq_response_t resp;
                memset(&resp, 0, sizeof(resp));
                resp.curl_code  = CURLE_FAILED_INIT;
                resp.error_msg  = strdup_safe("failed to initialize easy handle");
                resp.http_code  = 0;

                /* 回调负责调用 curlrq_response_free 释放响应数据 */
                node->callback(&resp, node->req.user_data);

                /* 释放节点 */
                if (node->headers) curl_slist_free_all(node->headers);
                free((void *)node->req.url);
                free((void *)node->req.method);
                free((void *)node->req.body);
                free(node);

                pthread_mutex_lock(&engine->mutex);
            }
        }

        pthread_mutex_unlock(&engine->mutex);

do_multi:
        /*
         * 执行 curl_multi_perform 驱动数据传输。
         * 非活跃时跳过，避免 busy-loop。
         */
        if (engine->active_count == 0) {
            /* 无活跃请求，回到循环顶部等待 */
            continue;
        }

        {
            int running_handles;
            CURLMcode mc;

            /* 驱动 libcurl 数据传输 */
            mc = curl_multi_perform(engine->multi, &running_handles);
            if (mc != CURLM_OK) {
                /* multi 接口错误，尝试继续 */
            }

            /*
             * 检查已完成的请求（传输结束，不论成功或失败）。
             * curl_multi_info_read 返回所有完成的 easy 句柄。
             */
            CURLMsg *msg;
            int msgs_left;
            while ((msg = curl_multi_info_read(engine->multi, &msgs_left)) != NULL) {
                if (msg->msg == CURLMSG_DONE) {
                    complete_request(engine, msg->easy_handle, msg->data.result);
                }
            }

            /* 等待 socket 活动，有超时防止永久阻塞 */
            if (running_handles > 0) {
                curl_multi_wait(engine->multi, NULL, 0, CURLRQ_MULTI_WAIT_MS, NULL);
            }
        }
    }

    return NULL;
}

/* ------------------------------------------------------------------ */
/*  启动单个请求                                                       */
/* ------------------------------------------------------------------ */

/**
 * start_request - 将一个队列节点转为活跃请求
 * 调用时必须持有 engine->mutex
 */
static int start_request(curlrq_engine_t *engine, request_node_t *node)
{
    CURL *easy;
    active_request_t *ar;
    const char *method;
    long verify_ssl;

    easy = curl_easy_init();
    if (!easy) return -1;

    ar = (active_request_t *)calloc(1, sizeof(*ar));
    if (!ar) {
        curl_easy_cleanup(easy);
        return -1;
    }

    ar->easy   = easy;
    ar->node   = node;
    ar->url    = strdup_safe(node->req.url);
    ar->body   = strdup_safe(node->req.body);
    ar->body_len = node->req.body_len;
    /*
     * 构建最终头链表：引擎默认头在前，请求头在后。
     * 后添加的同名头会覆盖前者，实现请求头 > 引擎默认头 的优先级。
     */
    {
        struct curl_slist *merged = NULL;
        /* 先拷贝引擎默认头 */
        if (engine->default_headers) {
            for (struct curl_slist *cur = engine->default_headers; cur; cur = cur->next) {
                struct curl_slist *tmp = curl_slist_append(merged, cur->data);
                if (tmp) merged = tmp;
            }
        }
        /* 再追加请求头 */
        if (node->headers) {
            for (struct curl_slist *cur = node->headers; cur; cur = cur->next) {
                struct curl_slist *tmp = curl_slist_append(merged, cur->data);
                if (tmp) merged = tmp;
            }
            curl_slist_free_all(node->headers);
        }
        ar->headers = merged;
        node->headers = NULL;
    }

    /* 设置 URL */
    curl_easy_setopt(easy, CURLOPT_URL, ar->url);

    /* 设置 HTTP 方法 */
    method = node->req.method;
    if (method == NULL || method[0] == '\0' || strcmp(method, "GET") == 0) {
        curl_easy_setopt(easy, CURLOPT_HTTPGET, 1L);
    } else if (strcmp(method, "POST") == 0) {
        curl_easy_setopt(easy, CURLOPT_POST, 1L);
    } else if (strcmp(method, "HEAD") == 0) {
        curl_easy_setopt(easy, CURLOPT_NOBODY, 1L);
    } else {
        curl_easy_setopt(easy, CURLOPT_CUSTOMREQUEST, method);
    }

    /* 设置请求体（非 GET/HEAD 且提供了 body） */
    if (ar->body && method && strcmp(method, "GET") != 0 && strcmp(method, "HEAD") != 0) {
        curl_easy_setopt(easy, CURLOPT_POSTFIELDS, ar->body);
        curl_easy_setopt(easy, CURLOPT_POSTFIELDSIZE, (long)ar->body_len);
    }

    /* 设置请求头 */
    if (ar->headers) {
        curl_easy_setopt(easy, CURLOPT_HTTPHEADER, ar->headers);
    }

    /* 超时设置 */
    if (node->req.timeout_ms > 0) {
        curl_easy_setopt(easy, CURLOPT_TIMEOUT_MS, (long)node->req.timeout_ms);
    }
    if (node->req.connect_timeout_ms > 0) {
        curl_easy_setopt(easy, CURLOPT_CONNECTTIMEOUT_MS, (long)node->req.connect_timeout_ms);
    }

    /* SSL 验证 */
    verify_ssl = node->req.verify_ssl;
    if (verify_ssl == 0) {
        curl_easy_setopt(easy, CURLOPT_SSL_VERIFYPEER, 0L);
        curl_easy_setopt(easy, CURLOPT_SSL_VERIFYHOST, 0L);
    } else {
        curl_easy_setopt(easy, CURLOPT_SSL_VERIFYPEER, 1L);
        curl_easy_setopt(easy, CURLOPT_SSL_VERIFYHOST, 2L);
    }

    /* 自动跟随重定向 */
    curl_easy_setopt(easy, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(easy, CURLOPT_MAXREDIRS, 10L);

    /* 设置写入回调 */
    curl_easy_setopt(easy, CURLOPT_WRITEFUNCTION, write_body_cb);
    curl_easy_setopt(easy, CURLOPT_WRITEDATA, ar);

    /* 设置响应头收集回调 */
    curl_easy_setopt(easy, CURLOPT_HEADERFUNCTION, write_header_cb);
    curl_easy_setopt(easy, CURLOPT_HEADERDATA, ar);

    /* 关联 easy 句柄到活跃请求，便于 completion 时查找 */
    curl_easy_setopt(easy, CURLOPT_PRIVATE, ar);

    /* 加入 multi 句柄 */
    curl_multi_add_handle(engine->multi, easy);

    /* 加入活跃列表 */
    ar->next = engine->active_list;
    engine->active_list = ar;
    engine->active_count++;

    return 0;
}

/* ------------------------------------------------------------------ */
/*  完成请求处理                                                       */
/* ------------------------------------------------------------------ */

/**
 * complete_request - 处理一个完成的请求
 * 从活跃列表中查找对应的 easy_handle，提取响应数据，调用回调。
 *
 * 注意：完成处理分两步:
 *   1. cleanup_active (持锁) — 从活跃列表移除，提取信息
 *   2. callback (释锁后) — 调用用户回调
 * 这样避免回调中调用 curlrq_add 导致死锁。
 */
static void complete_request(curlrq_engine_t *engine, CURL *easy, CURLcode cr)
{
    active_request_t *ar = NULL;
    curlrq_response_t resp;
    request_node_t *node;

    memset(&resp, 0, sizeof(resp));

    /* 查找对应的活跃请求控制块（通过 CURLOPT_PRIVATE） */
    curl_easy_getinfo(easy, CURLINFO_PRIVATE, &ar);
    if (!ar) return;

    node = ar->node;

    /*
     * 在 cleanup_active 销毁 easy 句柄之前提取所有需要的信息。
     * 避免在已释放的 easy 句柄上调用 curl_easy_getinfo。
     */
    {
        double total_time = 0.0;
        curl_easy_getinfo(easy, CURLINFO_TOTAL_TIME, &total_time);
        resp.total_time_ms = (long)(total_time * 1000.0 + 0.5);
    }
    curl_easy_getinfo(easy, CURLINFO_RESPONSE_CODE, &resp.http_code);
    {
        char *eff_url = NULL;
        curl_easy_getinfo(easy, CURLINFO_EFFECTIVE_URL, &eff_url);
        if (eff_url) resp.effective_url = strdup_safe(eff_url);
    }

    /* 从引擎的活跃列表中移除（此函数会销毁 easy 句柄） */
    pthread_mutex_lock(&engine->mutex);
    cleanup_active(engine, ar, cr);
    pthread_mutex_unlock(&engine->mutex);

    /* --- 以下不再持有互斥锁 --- */

    /* 响应 body — 转移所有权 */
    resp.response_body     = ar->write_buf;
    resp.response_body_len = ar->write_len;
    ar->write_buf = NULL;  /* 防止 cleanup 时二次释放 */

    /* 响应 headers — 转移所有权 */
    resp.response_headers     = ar->header_buf;
    resp.response_headers_len = ar->header_len;
    ar->header_buf = NULL;

    /* 错误信息 */
    resp.curl_code = (int)cr;
    if (cr != CURLE_OK) {
        resp.error_msg = strdup_safe(curl_easy_strerror(cr));
    }

    /*
     * 调用用户回调。
     * 回调函数负责调用 curlrq_response_free() 释放响应数据，
     * 引擎不再重复释放。
     */
    if (node && node->callback) {
        node->callback(&resp, node->req.user_data);
    }

    /* 释放资源 */
    if (ar->headers) curl_slist_free_all(ar->headers);
    if (ar->body) free(ar->body);
    free(ar->url);
    free(ar);

    /* 释放请求节点 */
    if (node) {
        free((void *)node->req.url);
        free((void *)node->req.method);
        free((void *)node->req.body);
        if (node->headers) curl_slist_free_all(node->headers);
        free(node);
    }
}

/**
 * cleanup_active - 从活跃列表移除指定 easy_handle
 * 同时从 multi 句柄移除并销毁 easy 句柄。
 * 调用时必须持有 engine->mutex。
 */
static void cleanup_active(curlrq_engine_t *engine, active_request_t *target, CURLcode cr)
{
    (void)cr;  /* 暂未使用，保留参数供后续扩展 */
    active_request_t **pp = &engine->active_list;

    while (*pp) {
        if (*pp == target) {
            *pp = target->next;
            break;
        }
        pp = &(*pp)->next;
    }

    /* 从 multi 句柄移除 */
    if (target->easy) {
        curl_multi_remove_handle(engine->multi, target->easy);
        curl_easy_cleanup(target->easy);
        target->easy = NULL;
    }

    if (engine->active_count > 0) engine->active_count--;

    /* 唤醒可能正在 curlrq_wait 中等待的线程 */
    pthread_cond_broadcast(&engine->cond);
}

/**
 * drain_queue - 清理队列中所有剩余请求
 * 对每个请求调用回调并标记为失败。
 * 调用时必须持有 engine->mutex。
 */
static void drain_queue(curlrq_engine_t *engine)
{
    request_node_t *node = engine->queue_head;
    engine->queue_head = NULL;
    engine->queue_tail = NULL;
    engine->queue_len = 0;

    /* 解锁，在回调前释放锁 */
    pthread_mutex_unlock(&engine->mutex);

    while (node) {
        request_node_t *next = node->next;

        /* 构造失败响应 */
        curlrq_response_t resp;
        memset(&resp, 0, sizeof(resp));
        resp.curl_code = CURLE_OPERATION_TIMEDOUT;  /* 近似表示取消 */
        resp.error_msg = strdup_safe("request cancelled during engine shutdown");

        /* 回调负责调用 curlrq_response_free 释放响应数据 */
        if (node->callback) {
            node->callback(&resp, node->req.user_data);
        }

        /* 释放节点 */
        free((void *)node->req.url);
        free((void *)node->req.method);
        free((void *)node->req.body);
        if (node->headers) curl_slist_free_all(node->headers);
        free(node);

        node = next;
    }

    /* 重新加锁，保持调用者预期 */
    pthread_mutex_lock(&engine->mutex);
}

/* ------------------------------------------------------------------ */
/*  libcurl 写入回调                                                   */
/* ------------------------------------------------------------------ */

/**
 * write_body_cb - CURLOPT_WRITEFUNCTION
 * 将响应 body 写入动态缓存。
 * 支持 max_response_size 限制：超过限制时返回 0 中断传输。
 */
static size_t write_body_cb(void *data, size_t size, size_t nmemb, void *userp)
{
    active_request_t *ar = (active_request_t *)userp;
    size_t total = size * nmemb;
    size_t new_len = ar->write_len + total;

    /* 检查响应大小限制 */
    if (ar->node->req.max_response_size > 0 &&
        (long)new_len > ar->node->req.max_response_size) {
        return 0;  /* 返回 0 告诉 libcurl 中断传输 */
    }

    /* 扩展缓存 */
    if (new_len >= ar->write_cap) {
        size_t new_cap = ar->write_cap ? ar->write_cap * 2 : 4096;
        while (new_cap < new_len + 1) new_cap *= 2;

        char *new_buf = (char *)realloc(ar->write_buf, new_cap);
        if (!new_buf) return 0;
        ar->write_buf = new_buf;
        ar->write_cap = new_cap;
    }

    memcpy(ar->write_buf + ar->write_len, data, total);
    ar->write_len = new_len;
    ar->write_buf[ar->write_len] = '\0';  /* 保持字符串结尾 */

    return total;
}

/**
 * write_header_cb - CURLOPT_HEADERFUNCTION
 * 将响应头写入动态缓存。
 */
static size_t write_header_cb(void *data, size_t size, size_t nmemb, void *userp)
{
    active_request_t *ar = (active_request_t *)userp;
    size_t total = size * nmemb;
    size_t new_len = ar->header_len + total;

    /* 扩展缓存 */
    if (new_len >= ar->header_cap) {
        size_t new_cap = ar->header_cap ? ar->header_cap * 2 : 2048;
        while (new_cap < new_len + 1) new_cap *= 2;

        char *new_buf = (char *)realloc(ar->header_buf, new_cap);
        if (!new_buf) return 0;
        ar->header_buf = new_buf;
        ar->header_cap = new_cap;
    }

    memcpy(ar->header_buf + ar->header_len, data, total);
    ar->header_len = new_len;
    ar->header_buf[ar->header_len] = '\0';

    return total;
}

/* ------------------------------------------------------------------ */
/*  工具函数                                                           */
/* ------------------------------------------------------------------ */

/**
 * strdup_safe - 安全的 strdup，对 NULL 返回 NULL
 */
static char *strdup_safe(const char *s)
{
    if (!s) return NULL;
    size_t len = strlen(s);
    char *d = (char *)malloc(len + 1);
    if (!d) return NULL;
    memcpy(d, s, len + 1);
    return d;
}

/**
 * build_slist - 将 NULL-terminated 字符串数组转为 curl_slist
 */
static struct curl_slist *build_slist(const char * const *headers)
{
    struct curl_slist *list = NULL;
    if (!headers) return NULL;

    for (int i = 0; headers[i] != NULL; i++) {
        struct curl_slist *new_list = curl_slist_append(list, headers[i]);
        if (!new_list) {
            /* 追加失败，清理已添加的部分 */
            curl_slist_free_all(list);
            return NULL;
        }
        list = new_list;
    }
    return list;
}
