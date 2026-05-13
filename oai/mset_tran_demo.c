//go:build ignore

#include "mset_tran.h"
#include <curl/curl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static size_t test_write_callback(void *contents, size_t size, size_t nmemb, void *userp) {
    size_t total = size * nmemb;
    char **buf = (char**)userp;
    size_t old_len = *buf ? strlen(*buf) : 0;
    char *newbuf = realloc(*buf, old_len + total + 1);
    if (!newbuf) return 0;
    *buf = newbuf;
    memcpy(*buf + old_len, contents, total);
    (*buf)[old_len + total] = '\0';
    return total;
}

static void test_token_endpoint(void) {
    printf("\n=== Diagnostic: Fetch token directly with libcurl ===\n");
    CURL *curl = curl_easy_init();
    if (!curl) {
        printf("Failed to initialize curl\n");
        return;
    }
    char *body = NULL;
    long http_code = 0;
    curl_easy_setopt(curl, CURLOPT_URL, "https://edge.microsoft.com/translate/auth");
    curl_easy_setopt(curl, CURLOPT_USERAGENT, "msie 6");
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, test_write_callback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &body);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 30L);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 1L);
    CURLcode res = curl_easy_perform(curl);
    if (res != CURLE_OK) {
        printf("curl_easy_perform error: %s\n", curl_easy_strerror(res));
    } else {
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);
        printf("HTTP status: %ld\n", http_code);
        if (body && http_code == 200) {
            printf("Token received (first 80 chars): %.80s\n", body);
            printf("Token length: %zu\n", strlen(body));
        } else {
            printf("No valid token (body=%s)\n", body ? body : "(null)");
        }
    }
    free(body);
    curl_easy_cleanup(curl);
    printf("=== End diagnostic ===\n\n");
}

int main(void) {
    curl_global_init(CURL_GLOBAL_DEFAULT);
    test_token_endpoint();
    
    char *result = NULL;
    int ret = oai_mset_tran("Hello, world!", "zh-Hans", &result);
    if (ret == 0 && result) {
        printf("Translation: %s\n", result);
        free(result);
    } else {
        printf("Error: %d\n", ret);
        const char* err = oai_mset_get_last_error();
        if (err && err[0]) {
            printf("Detailed error: %s\n", err);
        } else {
            switch (ret) {
                case -2: printf("Hint: Failed to obtain authentication token (check network or %s)\n", "https://edge.microsoft.com/translate/auth"); break;
                case -3: printf("Hint: Failed to build translation request URL\n"); break;
                case -4: printf("Hint: Failed to build JSON request body\n"); break;
                case -5: printf("Hint: HTTP POST to translation API failed\n"); break;
                case -6: printf("Hint: Retry token fetch failed after 401001 error\n"); break;
                case -7: printf("Hint: Retry POST failed after token refresh\n"); break;
                default: printf("Hint: Unknown error code\n");
            }
        }
    }
    
    if (ret == -1) {
        printf("Note: Error -1 indicates invalid parameters (check target language code)\n");
    }
    
    const char *texts[] = {"Good morning", "How are you?"};
    oai_mset_string_arr arr = {0};
    ret = oai_mset_tran_full("zh-Hans", "en", texts, 2, &arr);
    if (ret == 0) {
        for (size_t i = 0; i < arr.count; i++)
            printf("%zu: %s\n", i, arr.items[i]);
        oai_mset_free_string_arr(&arr);
    }
    
    oai_mset_global_cleanup();
    return 0;
}
