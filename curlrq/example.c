/**
 * example.c - curlrq 使用示例
 *
 * 演示:
 *   1. GET 请求
 *   2. POST 请求（带 body 和自定义头）
 *   3. 多个请求并发
 *   4. 错误处理
 *   5. SSL 验证配置
 *
 * 编译:
 *   cc -std=c99 -Wall -Wextra -o example example.c curlrq.c -lcurl -lpthread
 */

#include "curlrq.h"

#include <curl/curl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * 请求完成回调函数
 * 处理每个请求的响应结果。
 *
 * 注意：回调负责调用 curlrq_response_free() 释放响应数据，
 * 引擎不会在回调返回后再次释放。
 */
static void on_request_done(curlrq_response_t *resp, void *user_data)
{
    int id = (int)(long)user_data;

    printf("=== [req-%d] ===\n", id);
    printf("  HTTP 状态码:    %d\n", resp->http_code);
    printf("  请求耗时:       %ld ms\n", resp->total_time_ms);
    printf("  最终 URL:       %s\n", resp->effective_url ? resp->effective_url : "N/A");

    if (resp->curl_code != CURLE_OK) {
        printf("  libcurl 错误:   %d - %s\n", resp->curl_code,
               resp->error_msg ? resp->error_msg : "unknown");
    }

    printf("  响应头 (%zu bytes):\n%s\n", resp->response_headers_len,
           resp->response_headers ? resp->response_headers : "(empty)");

    printf("  响应体 (%zu bytes):\n%.200s%s\n\n", resp->response_body_len,
           resp->response_body ? resp->response_body : "(empty)",
           resp->response_body_len > 200 ? "..." : "");

    /* 释放响应数据（必须调用） */
    curlrq_response_free(resp);
}

int main(void)
{
    /* 全局初始化 libcurl */
    curl_global_init(CURL_GLOBAL_ALL);

    /* 创建引擎，最大 3 并发 */
    curlrq_engine_t *eng = curlrq_init(3);
    if (!eng) {
        fprintf(stderr, "引擎创建失败\n");
        curl_global_cleanup();
        return 1;
    }

    printf("curlrq 引擎已启动 (最大并发: 3)\n\n");

    /* -------------------------------------------------------------- */
    /*  GET 请求                                                       */
    /* -------------------------------------------------------------- */
    {
        curlrq_request_t req = {
            .url                = "http://httpbin.org/get?q=hello",
            .method             = "GET",
            .timeout_ms         = 10000,      /* 10s 总超时 */
            .connect_timeout_ms = 5000,       /* 5s 连接超时 */
            .max_response_size  = 1048576,    /* 最大 1MB */
            .verify_ssl         = 0,          /* 跳过 SSL 验证 */
            .user_data          = (void *)(long)1,
        };
        curlrq_add(eng, &req, on_request_done);
    }

    /* -------------------------------------------------------------- */
    /*  POST 请求（JSON body + 自定义头）                                */
    /* -------------------------------------------------------------- */
    {
        const char *post_headers[] = {
            "Content-Type: application/json",
            "Accept: application/json",
            NULL  /* NULL-terminated */
        };

        curlrq_request_t req = {
            .url                = "http://httpbin.org/post",
            .method             = "POST",
            .body               = "{\"key\":\"value\",\"num\":42}",
            .body_len           = 0,          /* 0 = 自动 strlen */
            .headers            = post_headers,
            .timeout_ms         = 10000,
            .verify_ssl         = 0,
            .user_data          = (void *)(long)2,
        };
        curlrq_add(eng, &req, on_request_done);
    }

    /* -------------------------------------------------------------- */
    /*  PUT 请求（使用 CUSTOMREQUEST）                                  */
    /* -------------------------------------------------------------- */
    {
        const char *put_headers[] = {
            "Content-Type: text/plain",
            NULL
        };

        curlrq_request_t req = {
            .url        = "http://httpbin.org/put",
            .method     = "PUT",
            .body       = "Hello PUT body",
            .body_len   = 0,
            .headers    = put_headers,
            .timeout_ms = 10000,
            .verify_ssl = 0,
            .user_data  = (void *)(long)3,
        };
        curlrq_add(eng, &req, on_request_done);
    }

    /* -------------------------------------------------------------- */
    /*  DELETE 请求                                                    */
    /* -------------------------------------------------------------- */
    {
        curlrq_request_t req = {
            .url        = "http://httpbin.org/delete",
            .method     = "DELETE",
            .timeout_ms = 10000,
            .verify_ssl = 0,
            .user_data  = (void *)(long)4,
        };
        curlrq_add(eng, &req, on_request_done);
    }

    /*
     * 等待所有请求完成。
     * 由于最大并发为 3，上面 4 个请求会分两批执行：
     *   第一批: GET, POST, PUT 同时执行
     *   第二批: DELETE 在前三个中任意一个完成后立即启动
     */
    printf("正在等待 4 个请求完成...\n");
    curlrq_wait(eng);
    printf("所有请求已完成\n\n");

    /* 清理引擎 */
    curlrq_cleanup(eng);

    /* 全局清理 */
    curl_global_cleanup();
    return 0;
}
