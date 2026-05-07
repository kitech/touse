#include "mset_tran.h"
#include <curl/curl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <stdarg.h>

static char last_error[512] = {0};

static void set_error(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vsnprintf(last_error, sizeof(last_error), fmt, args);
    va_end(args);
}

#define MSET_AUTH_URL "https://edge.microsoft.com/translate/auth"
#define MSET_API_BASE "https://api.cognitive.microsofttranslator.com/translate"
#define MSET_UA "msie 6"
#define TOKEN_CACHE_FILE "mset_apikey.txt"

static const char *get_temp_dir(void) {
    const char *tmp = getenv("TMPDIR");
    if (tmp && *tmp) return tmp;
    tmp = getenv("TEMP");
    if (tmp && *tmp) return tmp;
    tmp = getenv("TMP");
    if (tmp && *tmp) return tmp;
    return "/tmp";
}

static char *get_token_cache_path(void) {
    const char *tmpdir = get_temp_dir();
    size_t len = strlen(tmpdir) + strlen(TOKEN_CACHE_FILE) + 2;
    char *path = malloc(len);
    if (!path) return NULL;
    snprintf(path, len, "%s/%s", tmpdir, TOKEN_CACHE_FILE);
    return path;
}

static size_t write_callback(void *contents, size_t size, size_t nmemb, void *userp) {
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

static int curl_get(const char *url, char **out_body, long *http_code) {
    CURL *curl = curl_easy_init();
    if (!curl) return -1;
    char *body = NULL;
    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_USERAGENT, MSET_UA);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &body);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 30L);
    CURLcode res = curl_easy_perform(curl);
    if (res != CURLE_OK) {
        fprintf(stderr, "curl_get: %s (url=%s)\n", curl_easy_strerror(res), url);
        set_error("curl_get: %s", curl_easy_strerror(res));
        curl_easy_cleanup(curl);
        free(body);
        return -2;
    }
    if (http_code)
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, http_code);
    curl_easy_cleanup(curl);
    *out_body = body;
    return 0;
}

static int curl_post(const char *url, const char *bearer, const char *json_body,
                     char **out_body, long *http_code) {
    CURL *curl = curl_easy_init();
    if (!curl) return -1;
    struct curl_slist *headers = NULL;
    char *auth_header_str = NULL;
    int auth_len = asprintf(&auth_header_str, "Authorization: Bearer %s", bearer);
    if (auth_len < 0) {
        fprintf(stderr, "curl_post: asprintf failed for auth header\n");
        curl_easy_cleanup(curl);
        return -1;
    }
    fprintf(stderr, "Auth header: %s\n", auth_header_str);
    headers = curl_slist_append(headers, auth_header_str);
    free(auth_header_str);
    headers = curl_slist_append(headers, "Content-Type: application/json");
    char *body = NULL;
    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_USERAGENT, MSET_UA);
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, json_body);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &body);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 30L);
    curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);
    CURLcode res = curl_easy_perform(curl);
    curl_slist_free_all(headers);
    if (res != CURLE_OK) {
        fprintf(stderr, "curl_get: %s (url=%s)\n", curl_easy_strerror(res), url);
        set_error("curl_get: %s", curl_easy_strerror(res));
        curl_easy_cleanup(curl);
        free(body);
        return -2;
    }
    if (http_code)
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, http_code);
    curl_easy_cleanup(curl);
    *out_body = body;
    return 0;
}

static char *fetch_token(void) {
    char *body = NULL;
    long http_code = 0;
    int ret = curl_get(MSET_AUTH_URL, &body, &http_code);
    if (ret != 0) {
        fprintf(stderr, "fetch_token: curl_get failed with code %d\n", ret);
        set_error("fetch_token: curl_get failed with code %d", ret);
        free(body);
        return NULL;
    }
    if (http_code != 200) {
        fprintf(stderr, "fetch_token: auth endpoint returned HTTP %ld\n", http_code);
        set_error("fetch_token: auth endpoint returned HTTP %ld", http_code);
        free(body);
        return NULL;
    }
    if (!body || !*body) {
        fprintf(stderr, "fetch_token: auth returned empty body\n");
        set_error("fetch_token: auth returned empty body");
        free(body);
        return NULL;
    }
    fprintf(stderr, "fetch_token: received token length %zu\n", strlen(body));
    char *token = strdup(body);
    free(body);
    return token;
}

static char *get_token(int renew) {
    char *cache_path = get_token_cache_path();
    if (!cache_path) return NULL;
    char *token = NULL;
    if (!renew) {
        FILE *f = fopen(cache_path, "r");
        if (f) {
            char buf[1024];
            if (fgets(buf, sizeof(buf), f)) {
                size_t len = strlen(buf);
                if (len > 0 && buf[len-1] == '\n') buf[len-1] = '\0';
                token = strdup(buf);
            }
            fclose(f);
        }
    }
    if (token && !*token) {
        fprintf(stderr, "get_token: cached token is empty, discarding\n");
        free(token);
        token = NULL;
    }
    if (!token || renew) {
        fprintf(stderr, "get_token: fetching new token (renew=%d)\n", renew);
        char *new_token = fetch_token();
        if (new_token) {
            fprintf(stderr, "get_token: fetched token length %zu\n", strlen(new_token));
            free(token);
            token = new_token;
            FILE *f = fopen(cache_path, "w");
            if (f) {
                fprintf(f, "%s", token);
                fclose(f);
            }
        } else {
            fprintf(stderr, "get_token: fetch_token returned NULL\n");
        }
    }
    free(cache_path);
    return token;
}

static char *json_escape(const char *s) {
    size_t len = strlen(s);
    char *out = malloc(len * 2 + 3);
    if (!out) return NULL;
    char *p = out;
    *p++ = '"';
    while (*s) {
        if (*s == '"' || *s == '\\') *p++ = '\\';
        *p++ = *s++;
    }
    *p++ = '"';
    *p = '\0';
    return out;
}

static char *build_request_json(const char **texts, size_t n) {
    size_t total = 3;
    for (size_t i = 0; i < n; i++) {
        char *esc = json_escape(texts[i]);
        if (!esc) return NULL;
        total += strlen(esc) + 15; // {"text":}
        free(esc);
    }
    total += 2 * n; // comma and newline
    char *buf = malloc(total);
    if (!buf) return NULL;
    char *p = buf;
    *p++ = '[';
    for (size_t i = 0; i < n; i++) {
        if (i > 0) *p++ = ',';
        char *esc = json_escape(texts[i]);
        if (!esc) { free(buf); return NULL; }
        p += sprintf(p, "{\"text\":%s}", esc);
        free(esc);
    }
    *p++ = ']';
    *p = '\0';
    return buf;
}

static int parse_response(const char *json, oai_mset_string_arr *out, int *error_code) {
    out->items = NULL;
    out->count = 0;
    *error_code = 0;
    
    // Look for "error":{"code":401001}
    const char *err_code = strstr(json, "\"error\"");
    if (err_code) {
        const char *code = strstr(err_code, "\"code\"");
        if (code) {
            const char *num = strchr(code, ':');
            if (num && sscanf(num, ":%d", error_code) == 1) {
                return -1; // error found
            }
        }
    }
    
    // Find "translations" array
    const char *trans = strstr(json, "\"translations\"");
    if (!trans) return -2;
    const char *arr_start = strchr(trans, '[');
    if (!arr_start) return -3;
    const char *arr_end = strchr(arr_start, ']');
    if (!arr_end) return -4;
    
    // Count objects inside array
    int count = 0;
    const char *ptr = arr_start;
    while ((ptr = strstr(ptr, "\"text\"")) != NULL && ptr < arr_end) {
        count++;
        ptr += 6;
    }
    if (count == 0) return -5;
    
    out->items = malloc(count * sizeof(char*));
    if (!out->items) return -6;
    out->count = 0;
    ptr = arr_start;
    for (int i = 0; i < count; i++) {
        const char *text_key = strstr(ptr, "\"text\"");
        if (!text_key || text_key >= arr_end) break;
        const char *colon = strchr(text_key, ':');
        if (!colon) break;
        colon++;
        while (*colon == ' ') colon++;
        if (*colon != '"') break;
        colon++;
        const char *end_quote = strchr(colon, '"');
        if (!end_quote) break;
        size_t len = end_quote - colon;
        out->items[i] = malloc(len + 1);
        if (out->items[i]) {
            memcpy(out->items[i], colon, len);
            out->items[i][len] = '\0';
            out->count++;
        }
        ptr = end_quote;
    }
    return out->count > 0 ? 0 : -7;
}

int oai_mset_tran_full(const char *to_lang, const char *from_lang,
                       const char **texts, size_t text_count,
                       oai_mset_string_arr *out) {
    if (!to_lang || !*to_lang || !texts || text_count == 0 || !out) return -1;
    char *token = get_token(0);
    if (!token) {
        set_error("oai_mset_tran_full: failed to obtain authentication token");
        return -2;
    }
    char *url = NULL;
    int as_ret = 0;
    if (from_lang && *from_lang)
        as_ret = asprintf(&url, "%s?from=%s&to=%s&api-version=3.0&includeSentenceLength=true",
                          MSET_API_BASE, from_lang, to_lang);
    else
        as_ret = asprintf(&url, "%s?to=%s&api-version=3.0&includeSentenceLength=true",
                          MSET_API_BASE, to_lang);
    if (as_ret < 0 || !url) {
        set_error("oai_mset_tran_full: asprintf failed to allocate URL");
        free(token);
        return -3;
    }
    char *json_body = build_request_json(texts, text_count);
    if (!json_body) {
        set_error("oai_mset_tran_full: build_request_json failed");
        free(url); free(token);
        return -4;
    }
    char *resp_body = NULL;
    long http_code = 0;
    int ret = curl_post(url, token, json_body, &resp_body, &http_code);
    if (ret != 0) {
        set_error("oai_mset_tran_full: curl_post failed (ret=%d)", ret);
        free(json_body); free(url); free(token); free(resp_body);
        return -5;
    }
    int error_code = 0;
    fprintf(stderr, "Response body: %s\n", resp_body);
    int parse_ret = parse_response(resp_body, out, &error_code);
    if (parse_ret == -1 && error_code == 401001) {
        free(resp_body);
        free(token);
        token = get_token(1);
        if (!token) {
            set_error("oai_mset_tran_full: retry token fetch failed");
            free(json_body); free(url);
            return -6;
        }
        resp_body = NULL;
        ret = curl_post(url, token, json_body, &resp_body, &http_code);
        if (ret != 0) {
            set_error("oai_mset_tran_full: retry curl_post failed (ret=%d)", ret);
            free(json_body); free(url); free(token); free(resp_body);
            return -7;
        }
        parse_ret = parse_response(resp_body, out, &error_code);
    }
    free(json_body);
    free(url);
    free(token);
    free(resp_body);
    if (parse_ret < 0) return parse_ret;
    return 0;
}

int oai_mset_tran(const char *text, const char *to_lang, char **result) {
    if (!text || !to_lang || !result) return -1;
    const char *texts[1] = { text };
    oai_mset_string_arr arr = {0};
    int ret = oai_mset_tran_full(to_lang, "", texts, 1, &arr);
    if (ret != 0) return ret;
    if (arr.count == 0 || !arr.items || !arr.items[0]) {
        oai_mset_free_string_arr(&arr);
        return -2;
    }
    *result = strdup(arr.items[0]);
    oai_mset_free_string_arr(&arr);
    return 0;
}

int oai_mset_tran_en(const char *text, char **result) {
    return oai_mset_tran(text, "en", result);
}

void oai_mset_free_string_arr(oai_mset_string_arr *arr) {
    if (!arr) return;
    for (size_t i = 0; i < arr->count; i++)
        free(arr->items[i]);
    free(arr->items);
    arr->items = NULL;
    arr->count = 0;
}

const char* oai_mset_get_last_error(void) {
    return last_error;
}

void oai_mset_global_cleanup(void) {
    curl_global_cleanup();
}