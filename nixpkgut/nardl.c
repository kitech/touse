#include "nardl.h"
#include "nixse.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <curl/curl.h>

#define DEFAULT_CACHE_URL "https://cache.nixos.org"

typedef struct {
    char *data;
    size_t size;
    FILE *fp;
} DownloadContext;

static size_t write_file_callback(void *contents, size_t size, size_t nmemb, void *userp) {
    size_t realsize = size * nmemb;
    DownloadContext *ctx = (DownloadContext *)userp;
    
    if (ctx->fp) {
        return fwrite(contents, size, nmemb, ctx->fp);
    }
    
    char *ptr = realloc(ctx->data, ctx->size + realsize + 1);
    if (!ptr) return 0;
    
    ctx->data = ptr;
    memcpy(ctx->data + ctx->size, contents, realsize);
    ctx->size += realsize;
    ctx->data[ctx->size] = '\0';
    
    return realsize;
}

static void get_hash_from_store_path(const char *store_path, char *hash_out, size_t hash_size) {
    const char *prefix = "/nix/store/";
    if (strncmp(store_path, prefix, strlen(prefix)) == 0) {
        const char *hash_start = store_path + strlen(prefix);
        const char *dash = strchr(hash_start, '-');
        if (dash && (size_t)(dash - hash_start) < hash_size) {
            strncpy(hash_out, hash_start, dash - hash_start);
            hash_out[dash - hash_start] = '\0';
            return;
        }
    }
    hash_out[0] = '\0';
}

int download_nar(const DownloadOptions *opts) {
    const char *cache_url = opts->cache_url ? opts->cache_url : DEFAULT_CACHE_URL;
    const char *store_path = opts->store_path;
    const char *output = opts->output;
    
    if (!store_path) {
        fprintf(stderr, "Error: store path required\n");
        return 1;
    }
    
    char hash[64];
    get_hash_from_store_path(store_path, hash, sizeof(hash));
    
    if (strlen(hash) == 0) {
        fprintf(stderr, "Error: invalid store path\n");
        return 1;
    }
    
    char nar_url[512];
    snprintf(nar_url, sizeof(nar_url), "%s/nar/%s.nar.xz", cache_url, hash);
    
    CURL *curl = curl_easy_init();
    if (!curl) {
        fprintf(stderr, "Error: curl init failed\n");
        return 1;
    }
    
    DownloadContext ctx = {0};
    
    if (output && strcmp(output, "-") != 0) {
        ctx.fp = fopen(output, "wb");
        if (!ctx.fp) {
            fprintf(stderr, "Error: cannot open output file: %s\n", output);
            curl_easy_cleanup(curl);
            return 1;
        }
    }
    
    curl_easy_setopt(curl, CURLOPT_URL, nar_url);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_file_callback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &ctx);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 60L);
    
    CURLcode res = curl_easy_perform(curl);
    
    long http_code = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);
    
    if (ctx.fp) fclose(ctx.fp);
    free(ctx.data);
    curl_easy_cleanup(curl);
    
    if (res != CURLE_OK) {
        fprintf(stderr, "Error: download failed: %s\n", curl_easy_strerror(res));
        return 1;
    }
    
    if (http_code != 200) {
        fprintf(stderr, "Error: HTTP %ld\n", http_code);
        return 1;
    }
    
    if (output && strcmp(output, "-") != 0) {
        printf("Saved to %s\n", output);
    }
    
    return 0;
}