#include "misskey_client.h"
#include "cJSON/cJSON.h"
#include <curl/curl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MISSKEY_CURL_VERSION_7_55_0 (LIBCURL_VERSION_NUM >= 0x073700)

static MisskeyAllocator g_global_allocator = {
    .malloc_fn = malloc,
    .realloc_fn = realloc,
    .free_fn = free,
    .user_data = NULL
};

static int g_curl_initialized = 0;

static void curl_ensure_init(void) {
    if (!g_curl_initialized) {
        curl_global_init(CURL_GLOBAL_DEFAULT);
        g_curl_initialized = 1;
    }
}

const MisskeyAllocator* misskey_get_default_allocator(void) {
    return &g_global_allocator;
}

void misskey_set_global_allocator(const MisskeyAllocator* allocator) {
    if (allocator && allocator->malloc_fn && allocator->realloc_fn && allocator->free_fn) {
        memcpy(&g_global_allocator, allocator, sizeof(MisskeyAllocator));
    }
}

static void* alloc_allocator(const MisskeyAllocator* alloc, size_t size) {
    if (!alloc || !alloc->malloc_fn) return NULL;
    return alloc->malloc_fn(size);
}

static void* realloc_allocator(const MisskeyAllocator* alloc, void* ptr, size_t size) {
    if (!alloc || !alloc->realloc_fn) return NULL;
    return alloc->realloc_fn(ptr, size);
}

static void free_allocator(const MisskeyAllocator* alloc, void* ptr) {
    if (!alloc || !alloc->free_fn || !ptr) return;
    alloc->free_fn(ptr);
}

typedef struct {
    char* data;
    size_t size;
    MisskeyAllocator alloc;
} WriteData;

static size_t write_callback(void* contents, size_t size, size_t nmemb, void* userp) {
    size_t realsize = size * nmemb;
    WriteData* wd = (WriteData*)userp;
    char* ptr = realloc_allocator(&wd->alloc, wd->data, wd->size + realsize + 1);
    if (!ptr) return 0;
    wd->data = ptr;
    memcpy(wd->data + wd->size, contents, realsize);
    wd->size += realsize;
    wd->data[wd->size] = 0;
    return realsize;
};

struct MisskeyClient {
    char host[256];
    char token[256];
    long timeout;
    CURL* curl;
    MisskeyAllocator allocator;
    int debug_curl;
    long last_http_code;
    char* last_error_detail;
};

const char* misskey_error_str(MisskeyError err) {
    // Note: This function is kept for backwards compatibility
    // For detailed error messages, use misskey_client_get_last_error instead
    switch (err) {
        case MISSKEY_OK: return "Success";
        case MISSKEY_ERROR_INVALID_PARAM: return "Invalid parameter";
        case MISSKEY_ERROR_NETWORK: return "Network error";
        case MISSKEY_ERROR_HTTP: return "HTTP error";
        case MISSKEY_ERROR_JSON: return "JSON error";
        case MISSKEY_ERROR_AUTH: return "Authentication error";
        case MISSKEY_ERROR_ALLOC: return "Allocation error";
        default: return "Unknown error";
    }
}

// Returns detailed error string including HTTP code and response body
// The returned string is stored in a static buffer, not allocated
// Caller should copy the result if needed
const char* misskey_error_str_detail(MisskeyClient* client, MisskeyError err) {
    static char err_buf[2048];
    
    if (!client) {
        switch (err) {
            case MISSKEY_OK: return "Success";
            case MISSKEY_ERROR_INVALID_PARAM: return "Invalid parameter";
            case MISSKEY_ERROR_NETWORK: return "Network error";
            case MISSKEY_ERROR_HTTP: return "HTTP error";
            case MISSKEY_ERROR_JSON: return "JSON error";
            case MISSKEY_ERROR_AUTH: return "Authentication error";
            case MISSKEY_ERROR_ALLOC: return "Allocation error";
            default: return "Unknown error";
        }
    }
    
    long http_code = client->last_http_code;
    const char* detail = client->last_error_detail ? client->last_error_detail : "";
    
    if (http_code > 0 && detail[0] != '\0') {
        snprintf(err_buf, sizeof(err_buf), "HTTP %ld: %s", http_code, detail);
    } else if (http_code > 0) {
        snprintf(err_buf, sizeof(err_buf), "HTTP %ld", http_code);
    } else if (detail[0] != '\0') {
        snprintf(err_buf, sizeof(err_buf), "%s", detail);
    } else {
        switch (err) {
            case MISSKEY_OK: return "Success";
            case MISSKEY_ERROR_INVALID_PARAM: return "Invalid parameter";
            case MISSKEY_ERROR_NETWORK: return "Network error";
            case MISSKEY_ERROR_HTTP: return "HTTP error";
            case MISSKEY_ERROR_JSON: return "JSON error";
            case MISSKEY_ERROR_AUTH: return "Authentication error";
            case MISSKEY_ERROR_ALLOC: return "Allocation error";
            default: return "Unknown error";
        }
    }
    
    return err_buf;
}

static MisskeyClient* client_new_internal(const char* host, const MisskeyAllocator* allocator) {
    curl_ensure_init();
    
    MisskeyClient* client = alloc_allocator(allocator ? allocator : &g_global_allocator, sizeof(MisskeyClient));
    if (!client) return NULL;
    
    memset(client, 0, sizeof(MisskeyClient));
    
    if (allocator && allocator->malloc_fn) {
        memcpy(&client->allocator, allocator, sizeof(MisskeyAllocator));
    } else {
        memcpy(&client->allocator, &g_global_allocator, sizeof(MisskeyAllocator));
    }
    
    strncpy(client->host, host ? host : "misskey.io", sizeof(client->host) - 1);
    client->timeout = 30;
    client->curl = curl_easy_init();
    
    return client;
}

MisskeyClient* misskey_client_new(const char* host) {
    return client_new_internal(host, NULL);
}

MisskeyClient* misskey_client_new_with_allocator(const char* host, const MisskeyAllocator* allocator) {
    return client_new_internal(host, allocator);
}

void misskey_client_free(MisskeyClient* client) {
    if (!client) return;
    if (client->last_error_detail) {
        free_allocator(&client->allocator, client->last_error_detail);
    }
    if (client->curl) curl_easy_cleanup(client->curl);
    free_allocator(&client->allocator, client);
}

void misskey_client_set_token(MisskeyClient* client, const char* token) {
    if (client && token) {
        strncpy(client->token, token, sizeof(client->token) - 1);
    }
}

void misskey_client_set_timeout(MisskeyClient* client, long timeout_secs) {
    if (client) client->timeout = timeout_secs;
}

const MisskeyAllocator* misskey_client_get_allocator(const MisskeyClient* client) {
    if (!client) return NULL;
    return &client->allocator;
}

MisskeyError misskey_request(MisskeyClient* client, const char* endpoint,
                              const char* request_body, char** response_out) {
    if (!client || !endpoint || !request_body || !response_out) {
        return MISSKEY_ERROR_INVALID_PARAM;
    }
    
    client->last_http_code = 0;
    if (client->last_error_detail) {
        free_allocator(&client->allocator, client->last_error_detail);
        client->last_error_detail = NULL;
    }
    
    if (client->debug_curl) {
        misskey_request_print_curl(client, endpoint, request_body);
    }
    
    *response_out = NULL;
    
    WriteData wd = {
        .data = alloc_allocator(&client->allocator, 1),
        .size = 0,
        .alloc = client->allocator
    };
    if (!wd.data) {
        return MISSKEY_ERROR_ALLOC;
    }
    
    char url[512];
    int use_https = 1;
    if (strncmp(client->host, "localhost", 9) == 0 || 
        strncmp(client->host, "127.0.0.1", 9) == 0 ||
        strstr(client->host, "localhost:") != NULL) {
        use_https = 0;
    }
    snprintf(url, sizeof(url), "%s://%s/api/%s", 
             use_https ? "https" : "http", client->host, endpoint);
    
    struct curl_slist* headers = NULL;
    headers = curl_slist_append(headers, "Content-Type: application/json");
    if (!headers) {
        free_allocator(&client->allocator, wd.data);
        return MISSKEY_ERROR_ALLOC;
    }
    
    if (client->token[0] && client->token[0] != '\0') {
        char auth_header[320];
        snprintf(auth_header, sizeof(auth_header), "Authorization: Bearer %s", client->token);
        headers = curl_slist_append(headers, auth_header);
        if (!headers) {
            free_allocator(&client->allocator, wd.data);
            return MISSKEY_ERROR_ALLOC;
        }
    }
    
    curl_easy_reset(client->curl);
    curl_easy_setopt(client->curl, CURLOPT_URL, url);
    curl_easy_setopt(client->curl, CURLOPT_POSTFIELDS, request_body);
    curl_easy_setopt(client->curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(client->curl, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(client->curl, CURLOPT_WRITEDATA, &wd);
    curl_easy_setopt(client->curl, CURLOPT_TIMEOUT, client->timeout);
    if (use_https) {
        curl_easy_setopt(client->curl, CURLOPT_SSL_VERIFYPEER, 1L);
    } else {
        curl_easy_setopt(client->curl, CURLOPT_SSL_VERIFYPEER, 0L);
    }
    
    CURLcode res = curl_easy_perform(client->curl);
    
    curl_slist_free_all(headers);
    
    if (res != CURLE_OK) {
        free_allocator(&client->allocator, wd.data);
        client->last_http_code = 0;
        const char* err_str = curl_easy_strerror(res);
        if (err_str) {
            size_t err_len = strlen(err_str) + 1;
            client->last_error_detail = alloc_allocator(&client->allocator, err_len);
            if (client->last_error_detail) {
                memcpy(client->last_error_detail, err_str, err_len);
            }
        }
        return MISSKEY_ERROR_NETWORK;
    }
    
    long http_code = 0;
    curl_easy_getinfo(client->curl, CURLINFO_RESPONSE_CODE, &http_code);
    client->last_http_code = http_code;
    
    if (http_code >= 400) {
        wd.data[wd.size] = '\0';
        char err_buf[1024];
        if (wd.size > 0) {
            snprintf(err_buf, sizeof(err_buf), "HTTP %ld: %.*s", http_code, (int)(wd.size > 900 ? 900 : wd.size), wd.data);
        } else {
            snprintf(err_buf, sizeof(err_buf), "HTTP %ld", http_code);
        }
        size_t err_len = strlen(err_buf) + 1;
        client->last_error_detail = alloc_allocator(&client->allocator, err_len);
        if (client->last_error_detail) {
            memcpy(client->last_error_detail, err_buf, err_len);
        }
        free_allocator(&client->allocator, wd.data);
        wd.data = NULL;
        return MISSKEY_ERROR_HTTP;
    }
    
    *response_out = wd.data;
    return MISSKEY_OK;
}

void misskey_client_get_last_error(MisskeyClient* client, long* http_code, char** error_detail) {
    if (!client) return;
    if (http_code) *http_code = client->last_http_code;
    if (error_detail) *error_detail = client->last_error_detail;
}

void misskey_request_set_debug(MisskeyClient* client, int enable) {
    if (client) client->debug_curl = enable;
}

void misskey_request_print_curl(MisskeyClient* client, const char* endpoint,
                                 const char* request_body) {
    if (!client || !endpoint || !request_body) return;
    
    char url[512];
    snprintf(url, sizeof(url), "https://%s/api/%s", client->host, endpoint);
    
    printf("\n### curl command for '%s' ###\n", endpoint);
    printf("curl -X POST '%s' \\\n", url);
    printf("  -H 'Content-Type: application/json' \\\n");
    
    if (client->token[0] && client->token[0] != '\0') {
        printf("  -H 'Authorization: Bearer %s' \\\n", client->token);
    }
    
    printf("  -d '%s'\n", request_body);
    printf("##################################\n");
}

MisskeyError misskey_meta_raw(MisskeyClient* client, char** response_out) {
    return misskey_request(client, "meta", "{\"detail\":false}", response_out);
}

MisskeyError misskey_notes_timeline_raw(MisskeyClient* client, int limit,
                                     int local, char** response_out) {
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddNumberToObject(root, "limit", limit);
    if (local) {
        cJSON_AddStringToObject(root, "channel", "local");
    }
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "notes/timeline", json_str, response_out);
    
    free(json_str);  // cJSON uses standard malloc
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_notes_raw(MisskeyClient* client, const char* text,
                           const char* reply_id, const char* renote_id,
                           const char* channel_id, int limit, int offset,
                           const char* user_id, int local_only,
                           int reply, int renote, int with_files,
                           const char* since_id, const char* until_id,
                           char** response_out) {
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    
    if (text) cJSON_AddStringToObject(root, "text", text);
    if (reply_id) cJSON_AddStringToObject(root, "replyId", reply_id);
    if (renote_id) cJSON_AddStringToObject(root, "renoteId", renote_id);
    if (channel_id) cJSON_AddStringToObject(root, "channelId", channel_id);
    if (limit > 0) cJSON_AddNumberToObject(root, "limit", limit);
    if (offset > 0) cJSON_AddNumberToObject(root, "offset", offset);
    if (user_id) cJSON_AddStringToObject(root, "userId", user_id);
    if (local_only) cJSON_AddBoolToObject(root, "localOnly", 1);
    if (reply) cJSON_AddBoolToObject(root, "reply", 1);
    if (renote) cJSON_AddBoolToObject(root, "renote", 1);
    if (with_files) cJSON_AddBoolToObject(root, "withFiles", 1);
    if (since_id) cJSON_AddStringToObject(root, "sinceId", since_id);
    if (until_id) cJSON_AddStringToObject(root, "untilId", until_id);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "notes", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_notes_show_raw(MisskeyClient* client, const char* note_id,
                                char** response_out) {
    if (!note_id) return MISSKEY_ERROR_INVALID_PARAM;
    
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddStringToObject(root, "noteId", note_id);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "notes/show", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_notes_delete_raw(MisskeyClient* client, const char* note_id,
                                  char** response_out) {
    if (!note_id) return MISSKEY_ERROR_INVALID_PARAM;
    
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddStringToObject(root, "noteId", note_id);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "notes/delete", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_notes_create_raw(MisskeyClient* client, const char* text,
                                   const char* reply_id, const char* renote_id,
                                   char** response_out) {
    if (!text) return MISSKEY_ERROR_INVALID_PARAM;
    
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddStringToObject(root, "text", text);
    
    if (reply_id) cJSON_AddStringToObject(root, "replyId", reply_id);
    if (renote_id) cJSON_AddStringToObject(root, "renoteId", renote_id);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "notes/create", json_str, response_out);
    
    free(json_str);  // cJSON uses standard malloc
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_i_notifications_raw(MisskeyClient* client, int limit,
                                      char** response_out) {
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddNumberToObject(root, "limit", limit);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "i/notifications", json_str, response_out);
    
    free(json_str);  // cJSON uses standard malloc
    cJSON_Delete(root);
    return err;
}

void misskey_free_string(MisskeyClient* client, char* str) {
    if (!client || !str) return;
    free_allocator(&client->allocator, str);
}

MisskeyError misskey_drive_raw(MisskeyClient* client, char** response_out) {
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "drive", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_drive_files_raw(MisskeyClient* client, int limit, int folder_id,
                                  char** response_out) {
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddNumberToObject(root, "limit", limit);
    if (folder_id > 0) {
        cJSON_AddNumberToObject(root, "folderId", folder_id);
    }
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "drive/files", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_drive_files_create_raw(MisskeyClient* client, const char* file_path,
                                         const char* folder_id, const char* name,
                                         char** response_out) {
    if (!file_path) return MISSKEY_ERROR_INVALID_PARAM;
    if (!response_out) return MISSKEY_ERROR_INVALID_PARAM;
    
    FILE* fp = fopen(file_path, "rb");
    if (!fp) return MISSKEY_ERROR_INVALID_PARAM;
    
    fseek(fp, 0, SEEK_END);
    long file_size = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    
    char* file_data = malloc(file_size);
    if (!file_data) {
        fclose(fp);
        return MISSKEY_ERROR_ALLOC;
    }
    fread(file_data, 1, file_size, fp);
    fclose(fp);
    
    const char* basename = strrchr(file_path, '/');
    if (!basename) basename = file_path;
    else basename++;
    if (name) basename = name;
    
    char url[512];
    snprintf(url, sizeof(url), "https://%s/api/drive/files/create", client->host);
    
    WriteData wd = {
        .data = alloc_allocator(&client->allocator, 1),
        .size = 0,
        .alloc = client->allocator
    };
    if (!wd.data) {
        free(file_data);
        return MISSKEY_ERROR_ALLOC;
    }
    
    struct curl_slist* headers = NULL;
    if (client->token[0] && client->token[0] != '\0') {
        char auth_header[320];
        snprintf(auth_header, sizeof(auth_header), "Authorization: Bearer %s", client->token);
        headers = curl_slist_append(headers, auth_header);
    }
    
    curl_mime* mime = curl_mime_init(client->curl);
    if (!mime) {
        free(file_data);
        free_allocator(&client->allocator, wd.data);
        curl_slist_free_all(headers);
        return MISSKEY_ERROR_ALLOC;
    }
    
    curl_mimepart* part = curl_mime_addpart(mime);
    curl_mime_name(part, "i");
    curl_mime_data(part, client->token, CURL_ZERO_TERMINATED);
    
    part = curl_mime_addpart(mime);
    curl_mime_name(part, "file");
    curl_mime_filedata(part, file_path);
    
    if (folder_id) {
        part = curl_mime_addpart(mime);
        curl_mime_name(part, "folderId");
        curl_mime_data(part, folder_id, CURL_ZERO_TERMINATED);
    }
    
    if (name) {
        part = curl_mime_addpart(mime);
        curl_mime_name(part, "name");
        curl_mime_data(part, name, CURL_ZERO_TERMINATED);
    }
    
    curl_easy_reset(client->curl);
    curl_easy_setopt(client->curl, CURLOPT_URL, url);
    curl_easy_setopt(client->curl, CURLOPT_MIMEPOST, mime);
    curl_easy_setopt(client->curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(client->curl, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(client->curl, CURLOPT_WRITEDATA, &wd);
    curl_easy_setopt(client->curl, CURLOPT_TIMEOUT, client->timeout);
    curl_easy_setopt(client->curl, CURLOPT_SSL_VERIFYPEER, 1L);
    
    CURLcode res = curl_easy_perform(client->curl);
    
    curl_mime_free(mime);
    free(file_data);
    curl_slist_free_all(headers);
    
    if (res != CURLE_OK) {
        free_allocator(&client->allocator, wd.data);
        return MISSKEY_ERROR_NETWORK;
    }
    
    long http_code = 0;
    curl_easy_getinfo(client->curl, CURLINFO_RESPONSE_CODE, &http_code);
    
    if (http_code >= 400) {
        free_allocator(&client->allocator, wd.data);
        return MISSKEY_ERROR_HTTP;
    }
    
    *response_out = wd.data;
    return MISSKEY_OK;
}

MisskeyError misskey_drive_files_delete_raw(MisskeyClient* client, const char* file_id,
                                         char** response_out) {
    if (!file_id) return MISSKEY_ERROR_INVALID_PARAM;
    
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddStringToObject(root, "fileId", file_id);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "drive/files/delete", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_drive_files_update_raw(MisskeyClient* client, const char* file_id,
                                         const char* folder_id, const char* name,
                                         char** response_out) {
    if (!file_id) return MISSKEY_ERROR_INVALID_PARAM;
    
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddStringToObject(root, "fileId", file_id);
    
    if (folder_id) cJSON_AddStringToObject(root, "folderId", folder_id);
    if (name) cJSON_AddStringToObject(root, "name", name);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "drive/files/update", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_drive_files_find_raw(MisskeyClient* client, const char* hash,
                                       char** response_out) {
    if (!hash) return MISSKEY_ERROR_INVALID_PARAM;
    
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddStringToObject(root, "hash", hash);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "drive/files/find", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_drive_files_show_raw(MisskeyClient* client, const char* file_id,
                                      const char* url, char** response_out) {
    if (!file_id && !url) return MISSKEY_ERROR_INVALID_PARAM;
    
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    if (file_id) cJSON_AddStringToObject(root, "fileId", file_id);
    if (url) cJSON_AddStringToObject(root, "url", url);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "drive/files/show", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_drive_files_upload_from_url_raw(MisskeyClient* client, const char* url,
                                                  const char* folder_id, int is_sensitive,
                                                  const char* comment, char** response_out) {
    if (!url) return MISSKEY_ERROR_INVALID_PARAM;
    
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddStringToObject(root, "url", url);
    if (folder_id) cJSON_AddStringToObject(root, "folderId", folder_id);
    if (is_sensitive) cJSON_AddTrueToObject(root, "isSensitive");
    if (comment) cJSON_AddStringToObject(root, "comment", comment);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "drive/files/upload-from-url", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_drive_folders_raw(MisskeyClient* client, int limit, const char* folder_id,
                                   char** response_out) {
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddNumberToObject(root, "limit", limit);
    if (folder_id) {
        cJSON_AddStringToObject(root, "folderId", folder_id);
    }
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "drive/folders", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_drive_folders_create_raw(MisskeyClient* client, const char* name,
                                           const char* parent_id, char** response_out) {
    if (!name) return MISSKEY_ERROR_INVALID_PARAM;
    
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddStringToObject(root, "name", name);
    if (parent_id) {
        cJSON_AddStringToObject(root, "parentId", parent_id);
    }
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "drive/folders/create", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_drive_folders_delete_raw(MisskeyClient* client, const char* folder_id,
                                           char** response_out) {
    if (!folder_id) return MISSKEY_ERROR_INVALID_PARAM;
    
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddStringToObject(root, "folderId", folder_id);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "drive/folders/delete", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_drive_folders_update_raw(MisskeyClient* client, const char* folder_id,
                                           const char* name, const char* parent_id,
                                           char** response_out) {
    if (!folder_id) return MISSKEY_ERROR_INVALID_PARAM;
    
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddStringToObject(root, "folderId", folder_id);
    if (name) cJSON_AddStringToObject(root, "name", name);
    if (parent_id) cJSON_AddStringToObject(root, "parentId", parent_id);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "drive/folders/update", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_translate_raw(MisskeyClient* client, const char* note_id,
                                const char* target_lang, char** response_out) {
    if (!note_id || !target_lang) return MISSKEY_ERROR_INVALID_PARAM;
    
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddStringToObject(root, "noteId", note_id);
    cJSON_AddStringToObject(root, "targetLang", target_lang);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "notes/translate", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_clips_list_raw(MisskeyClient* client, char** response_out) {
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "clips/list", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_clips_show_raw(MisskeyClient* client, const char* clip_id,
                                char** response_out) {
    if (!clip_id) return MISSKEY_ERROR_INVALID_PARAM;
    
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddStringToObject(root, "clipId", clip_id);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "clips/show", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_clips_create_raw(MisskeyClient* client, const char* name,
                                 const char* description, int is_public,
                                 char** response_out) {
    if (!name) return MISSKEY_ERROR_INVALID_PARAM;
    
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddStringToObject(root, "name", name);
    if (description) cJSON_AddStringToObject(root, "description", description);
    if (is_public) cJSON_AddBoolToObject(root, "isPublic", 1);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "clips/create", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_clips_update_raw(MisskeyClient* client, const char* clip_id,
                                  const char* name, const char* description,
                                  int is_public, char** response_out) {
    if (!clip_id) return MISSKEY_ERROR_INVALID_PARAM;
    
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddStringToObject(root, "clipId", clip_id);
    if (name) cJSON_AddStringToObject(root, "name", name);
    if (description) cJSON_AddStringToObject(root, "description", description);
    cJSON_AddBoolToObject(root, "isPublic", is_public ? 1 : 0);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "clips/update", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_clips_delete_raw(MisskeyClient* client, const char* clip_id,
                                  char** response_out) {
    if (!clip_id) return MISSKEY_ERROR_INVALID_PARAM;
    
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddStringToObject(root, "clipId", clip_id);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "clips/delete", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_clips_add_note(MisskeyClient* client, const char* clip_id,
                                   const char* note_id) {
    if (!clip_id || !note_id) return MISSKEY_ERROR_INVALID_PARAM;
    
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddStringToObject(root, "clipId", clip_id);
    cJSON_AddStringToObject(root, "noteId", note_id);
    
    char* json_str = cJSON_PrintUnformatted(root);
    char* resp = NULL;
    MisskeyError err = misskey_request(client, "clips/add-note", json_str, &resp);
    
    free(json_str);
    cJSON_Delete(root);
    if (resp) misskey_free_string(client, resp);
    return err;
}

MisskeyError misskey_clips_add_note_raw(MisskeyClient* client, const char* clip_id,
                                   const char* note_id, char** response_out) {
    if (!clip_id || !note_id) return MISSKEY_ERROR_INVALID_PARAM;
    
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddStringToObject(root, "clipId", clip_id);
    cJSON_AddStringToObject(root, "noteId", note_id);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "clips/add-note", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_clips_remove_note(MisskeyClient* client, const char* clip_id,
                                      const char* note_id) {
    if (!clip_id || !note_id) return MISSKEY_ERROR_INVALID_PARAM;
    
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddStringToObject(root, "clipId", clip_id);
    cJSON_AddStringToObject(root, "noteId", note_id);
    
    char* json_str = cJSON_PrintUnformatted(root);
    char* resp = NULL;
    MisskeyError err = misskey_request(client, "clips/remove-note", json_str, &resp);
    
    free(json_str);
    cJSON_Delete(root);
    if (resp) misskey_free_string(client, resp);
    return err;
}

MisskeyError misskey_clips_remove_note_raw(MisskeyClient* client, const char* clip_id,
                                      const char* note_id, char** response_out) {
    if (!clip_id || !note_id) return MISSKEY_ERROR_INVALID_PARAM;
    
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddStringToObject(root, "clipId", clip_id);
    cJSON_AddStringToObject(root, "noteId", note_id);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "clips/remove-note", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_clips_notes_raw(MisskeyClient* client, const char* clip_id,
                                 int limit, char** response_out) {
    if (!clip_id) return MISSKEY_ERROR_INVALID_PARAM;
    
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddStringToObject(root, "clipId", clip_id);
    if (limit > 0) cJSON_AddNumberToObject(root, "limit", limit);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "clips/notes", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

static size_t write_to_file_cb(void* contents, size_t size, size_t nmemb, void* userp) {
    size_t realsize = size * nmemb;
    FILE* fp = (FILE*)userp;
    if (fp) {
        return fwrite(contents, size, nmemb, fp);
    }
    return realsize;
}

static size_t write_to_buffer_cb(void* contents, size_t size, size_t nmemb, void* userp) {
    size_t realsize = size * nmemb;
    MisskeyBuffer* buf = (MisskeyBuffer*)userp;
    if (!buf) return 0;
    
    if (buf->data == NULL) {
        buf->capacity = realsize > 4096 ? realsize : 4096;
        buf->data = malloc(buf->capacity);
        if (!buf->data) return 0;
        buf->size = 0;
    }
    
    while (buf->size + realsize > buf->capacity) {
        buf->capacity *= 2;
        void* new_data = realloc(buf->data, buf->capacity);
        if (!new_data) return 0;
        buf->data = new_data;
    }
    
    memcpy((char*)buf->data + buf->size, contents, realsize);
    buf->size += realsize;
    return realsize;
}

static size_t write_to_callback_cb(void* contents, size_t size, size_t nmemb, void* userp) {
    size_t realsize = size * nmemb;
    MisskeyDownloadOptions* opts = (MisskeyDownloadOptions*)userp;
    if (opts && opts->write_cb) {
        return opts->write_cb(contents, size, nmemb, opts->write_userdata);
    }
    return realsize;
}

MisskeyError misskey_drive_files_download(MisskeyClient* client, const char* file_id,
                                          const MisskeyDownloadOptions* options,
                                          long* http_code_out, long* content_length_out) {
    if (!options || !options->url) {
        if (!file_id) return MISSKEY_ERROR_INVALID_PARAM;
        
        char* file_info = NULL;
        MisskeyError err = misskey_drive_files_show_raw(client, file_id, NULL, &file_info);
        if (err != MISSKEY_OK) return err;
        
        cJSON* json = cJSON_Parse(file_info);
        misskey_free_string(client, file_info);
        
        if (!json) return MISSKEY_ERROR_JSON;
        
        cJSON* url_item = cJSON_GetObjectItem(json, "url");
        if (!cJSON_IsString(url_item) || !url_item->valuestring) {
            cJSON_Delete(json);
            return MISSKEY_ERROR_INVALID_PARAM;
        }
        
        MisskeyDownloadOptions opts_copy = *options;
        opts_copy.url = url_item->valuestring;
        MisskeyError result = misskey_drive_files_download(client, NULL, &opts_copy, http_code_out, content_length_out);
        cJSON_Delete(json);
        return result;
    }
    
    curl_ensure_init();
    CURL* curl = curl_easy_init();
    if (!curl) return MISSKEY_ERROR_NETWORK;
    
    FILE* fp = NULL;
    if (options->output_path) {
        const char* mode = options->resume_from > 0 ? "ab" : "wb";
        fp = fopen(options->output_path, mode);
        if (!fp) {
            curl_easy_cleanup(curl);
            return MISSKEY_ERROR_INVALID_PARAM;
        }
    }
    
    MisskeyBuffer buffer = {0};
    MisskeyBuffer* buf_ptr = NULL;
    if (!fp && !options->write_cb) {
        buf_ptr = &buffer;
    }
    
    curl_easy_setopt(curl, CURLOPT_URL, options->url);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, options->follow_redirects ? 1L : 0L);
    curl_easy_setopt(curl, CURLOPT_NOPROGRESS, 1L);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, client->timeout > 0 ? client->timeout : 300L);
    
    if (options->resume_from > 0) {
        curl_easy_setopt(curl, CURLOPT_RESUME_FROM_LARGE, (curl_off_t)options->resume_from);
    }
    
    if (fp) {
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_to_file_cb);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, fp);
    } else if (buf_ptr) {
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_to_buffer_cb);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, buf_ptr);
    } else if (options->write_cb) {
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_to_callback_cb);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void*)options);
    }
    
    CURLcode res = curl_easy_perform(curl);
    
    long http_code = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);
    
    if (http_code_out) *http_code_out = http_code;
    
    curl_off_t content_length = 0;
#if MISSKEY_CURL_VERSION_7_55_0
    curl_easy_getinfo(curl, CURLINFO_CONTENT_LENGTH_DOWNLOAD_T, &content_length);
#else
    double content_length_old = 0;
    curl_easy_getinfo(curl, CURLINFO_CONTENT_LENGTH_DOWNLOAD, &content_length_old);
    content_length = (curl_off_t)content_length_old;
#endif
    if (content_length_out) *content_length_out = (long)content_length;
    
    if (fp) fclose(fp);
    
    if (buffer.data) {
        if (options && (void*)options != (void*)&buffer) {
            void* user_data = ((MisskeyDownloadOptions*)options)->write_userdata;
            MisskeyDownloadOptions* opts = (MisskeyDownloadOptions*)options;
            if (opts->write_cb) {
                opts->write_cb(buffer.data, 1, buffer.size, user_data);
            }
        }
        free(buffer.data);
    }
    
    curl_easy_cleanup(curl);
    
    if (res != CURLE_OK) {
        if (res == CURLE_HTTP_RETURNED_ERROR) {
            return MISSKEY_ERROR_HTTP;
        }
        return MISSKEY_ERROR_NETWORK;
    }
    
    if (http_code >= 400) {
        return MISSKEY_ERROR_HTTP;
    }
    
    return MISSKEY_OK;
}

static void parse_user(cJSON* obj, MisskeyUser* user) {
    if (!obj || !user) return;
    misskey_user_init(user);
    
    cJSON* item;
    if ((item = cJSON_GetObjectItem(obj, "id")) && item->type == cJSON_String)
        strncpy(user->id, item->valuestring, sizeof(user->id) - 1);
    if ((item = cJSON_GetObjectItem(obj, "name")) && item->type == cJSON_String)
        strncpy(user->name, item->valuestring, sizeof(user->name) - 1);
    if ((item = cJSON_GetObjectItem(obj, "username")) && item->type == cJSON_String)
        strncpy(user->username, item->valuestring, sizeof(user->username) - 1);
    if ((item = cJSON_GetObjectItem(obj, "host")) && item->type == cJSON_String)
        strncpy(user->host, item->valuestring, sizeof(user->host) - 1);
    if ((item = cJSON_GetObjectItem(obj, "avatarUrl")) && item->type == cJSON_String)
        strncpy(user->avatar_url, item->valuestring, sizeof(user->avatar_url) - 1);
    if ((item = cJSON_GetObjectItem(obj, "avatarBlurhash")) && item->type == cJSON_String)
        strncpy(user->avatar_blurhash, item->valuestring, sizeof(user->avatar_blurhash) - 1);
    if ((item = cJSON_GetObjectItem(obj, "isBot")) && item->type == cJSON_Number)
        user->is_bot = item->valueint;
    if ((item = cJSON_GetObjectItem(obj, "isCat")) && item->type == cJSON_Number)
        user->is_cat = item->valueint;
}

static void parse_note(cJSON* obj, MisskeyNote* note) {
    if (!obj || !note) return;
    misskey_note_init(note);
    
    cJSON* item;
    if ((item = cJSON_GetObjectItem(obj, "id")) && item->type == cJSON_String)
        strncpy(note->id, item->valuestring, sizeof(note->id) - 1);
    if ((item = cJSON_GetObjectItem(obj, "createdAt")) && item->type == cJSON_String)
        strncpy(note->created_at, item->valuestring, sizeof(note->created_at) - 1);
    if ((item = cJSON_GetObjectItem(obj, "text")) && item->type == cJSON_String)
        strncpy(note->text, item->valuestring, sizeof(note->text) - 1);
    if ((item = cJSON_GetObjectItem(obj, "cw")) && item->type == cJSON_String)
        strncpy(note->cw, item->valuestring, sizeof(note->cw) - 1);
    if ((item = cJSON_GetObjectItem(obj, "appId")) && item->type == cJSON_String)
        strncpy(note->app_id, item->valuestring, sizeof(note->app_id) - 1);
    if ((item = cJSON_GetObjectItem(obj, "userId")) && item->type == cJSON_String)
        strncpy(note->user_id, item->valuestring, sizeof(note->user_id) - 1);
    if ((item = cJSON_GetObjectItem(obj, "replyId")) && item->type == cJSON_String)
        strncpy(note->reply_id, item->valuestring, sizeof(note->reply_id) - 1);
    if ((item = cJSON_GetObjectItem(obj, "renoteId")) && item->type == cJSON_String)
        strncpy(note->renote_id, item->valuestring, sizeof(note->renote_id) - 1);
    if ((item = cJSON_GetObjectItem(obj, "channelId")) && item->type == cJSON_String)
        strncpy(note->channel_id, item->valuestring, sizeof(note->channel_id) - 1);
    if ((item = cJSON_GetObjectItem(obj, "uri")) && item->type == cJSON_String)
        strncpy(note->uri, item->valuestring, sizeof(note->uri) - 1);
    if ((item = cJSON_GetObjectItem(obj, "url")) && item->type == cJSON_String)
        strncpy(note->url, item->valuestring, sizeof(note->url) - 1);
    if ((item = cJSON_GetObjectItem(obj, "visibility")) && item->type == cJSON_String)
        strncpy((char*)&note->visibility, item->valuestring, sizeof(int) - 1);
    if ((item = cJSON_GetObjectItem(obj, "localOnly")) && item->type == cJSON_Number)
        note->local_only = item->valueint;
    if ((item = cJSON_GetObjectItem(obj, "visibleUserIdsCount")) && item->type == cJSON_Number)
        note->visible_user_ids_count = item->valueint;
    if ((item = cJSON_GetObjectItem(obj, "reactionsCount")) && item->type == cJSON_Number)
        note->reactions_count = item->valueint;
    if ((item = cJSON_GetObjectItem(obj, "repliesCount")) && item->type == cJSON_Number)
        note->replies_count = item->valueint;
    if ((item = cJSON_GetObjectItem(obj, "renoteCount")) && item->type == cJSON_Number)
        note->renote_count = item->valueint;
    if ((item = cJSON_GetObjectItem(obj, "reactionEmojis")) && item->type == cJSON_Object) {
        char* emojis = cJSON_Print(item);
        if (emojis) {
            strncpy(note->reaction_emojis, emojis, sizeof(note->reaction_emojis) - 1);
            free(emojis);
        }
    }
    
    cJSON* user = cJSON_GetObjectItem(obj, "user");
    if (user) parse_user(user, &note->user);
}

void misskey_note_init(MisskeyNote* note) {
    if (!note) return;
    memset(note, 0, sizeof(MisskeyNote));
}

void misskey_user_init(MisskeyUser* user) {
    if (!user) return;
    memset(user, 0, sizeof(MisskeyUser));
}

void misskey_notification_init(MisskeyNotification* n) {
    if (!n) return;
    memset(n, 0, sizeof(MisskeyNotification));
}

void misskey_drive_file_init(MisskeyDriveFile* f) {
    if (!f) return;
    memset(f, 0, sizeof(MisskeyDriveFile));
}

void misskey_drive_folder_init(MisskeyDriveFolder* f) {
    if (!f) return;
    memset(f, 0, sizeof(MisskeyDriveFolder));
}

void misskey_drive_info_init(MisskeyDriveInfo* info) {
    if (!info) return;
    memset(info, 0, sizeof(MisskeyDriveInfo));
}

void misskey_translate_result_init(MisskeyTranslateResult* r) {
    if (!r) return;
    memset(r, 0, sizeof(MisskeyTranslateResult));
}

void misskey_clip_init(MisskeyClip* c) {
    if (!c) return;
    memset(c, 0, sizeof(MisskeyClip));
}

void misskey_meta_init(MisskeyMeta* m) {
    if (!m) return;
    memset(m, 0, sizeof(MisskeyMeta));
}

MisskeyError misskey_meta(MisskeyClient* client, MisskeyMeta* meta) {
    if (!client || !meta) return MISSKEY_ERROR_INVALID_PARAM;
    misskey_meta_init(meta);
    
    char* resp = NULL;
    MisskeyError err = misskey_meta_raw(client, &resp);
    if (err != MISSKEY_OK) return err;
    
    cJSON* root = cJSON_Parse(resp);
    if (!root) {
        misskey_free_string(client, resp);
        return MISSKEY_ERROR_JSON;
    }
    
    cJSON* item;
    if ((item = cJSON_GetObjectItem(root, "name")) && item->type == cJSON_String)
        strncpy(meta->name, item->valuestring, sizeof(meta->name) - 1);
    if ((item = cJSON_GetObjectItem(root, "version")) && item->type == cJSON_String)
        strncpy(meta->version, item->valuestring, sizeof(meta->version) - 1);
    if ((item = cJSON_GetObjectItem(root, "uri")) && item->type == cJSON_String)
        strncpy(meta->uri, item->valuestring, sizeof(meta->uri) - 1);
    if ((item = cJSON_GetObjectItem(root, "description")) && item->type == cJSON_String)
        strncpy(meta->description, item->valuestring, sizeof(meta->description) - 1);
    if ((item = cJSON_GetObjectItem(root, "maintainerName")) && item->type == cJSON_String)
        strncpy(meta->maintainer_name, item->valuestring, sizeof(meta->maintainer_name) - 1);
    if ((item = cJSON_GetObjectItem(root, "maintainerEmail")) && item->type == cJSON_String)
        strncpy(meta->maintainer_email, item->valuestring, sizeof(meta->maintainer_email) - 1);
    if ((item = cJSON_GetObjectItem(root, "langs")) && item->type == cJSON_Array) {
        char* langs = cJSON_Print(item);
        if (langs) {
            strncpy(meta->langs, langs, sizeof(meta->langs) - 1);
            free(langs);
        }
    }
    if ((item = cJSON_GetObjectItem(root, "features")) && item->type == cJSON_Object) {
        char* feats = cJSON_Print(item);
        if (feats) {
            strncpy(meta->features, feats, sizeof(meta->features) - 1);
            free(feats);
        }
    }
    if ((item = cJSON_GetObjectItem(root, "mascotImageUrl")) && item->type == cJSON_String)
        strncpy(meta->mascot_image_url, item->valuestring, sizeof(meta->mascot_image_url) - 1);
    if ((item = cJSON_GetObjectItem(root, "bannerUrl")) && item->type == cJSON_String)
        strncpy(meta->banner_url, item->valuestring, sizeof(meta->banner_url) - 1);
    if ((item = cJSON_GetObjectItem(root, "errorImageUrl")) && item->type == cJSON_String)
        strncpy(meta->error_image_url, item->valuestring, sizeof(meta->error_image_url) - 1);
    if ((item = cJSON_GetObjectItem(root, "iconUrl")) && item->type == cJSON_String)
        strncpy(meta->icon_url, item->valuestring, sizeof(meta->icon_url) - 1);
    if ((item = cJSON_GetObjectItem(root, "backgroundImageUrl")) && item->type == cJSON_String)
        strncpy(meta->background_image_url, item->valuestring, sizeof(meta->background_image_url) - 1);
    if ((item = cJSON_GetObjectItem(root, "logoImageUrl")) && item->type == cJSON_String)
        strncpy(meta->logo_image_url, item->valuestring, sizeof(meta->logo_image_url) - 1);
    if ((item = cJSON_GetObjectItem(root, "maxNoteTextLength")) && item->type == cJSON_Number)
        meta->max_note_text_length = item->valueint;
    if ((item = cJSON_GetObjectItem(root, "enableEmojiReactions")) && item->type == cJSON_True)
        meta->enable_emoji_reactions = 1;
    if ((item = cJSON_GetObjectItem(root, "enableRecursiveReaction")) && item->type == cJSON_True)
        meta->enable_recursive_reaction = 1;
    if ((item = cJSON_GetObjectItem(root, "driveCapacity")) && item->type == cJSON_Number)
        meta->drive_capacity = item->valueint;
    if ((item = cJSON_GetObjectItem(root, "enableEmail")) && item->type == cJSON_True)
        meta->enable_email = 1;
    if ((item = cJSON_GetObjectItem(root, "enableTwitter")) && item->type == cJSON_True)
        meta->enable_twitter = 1;
    if ((item = cJSON_GetObjectItem(root, "enableGithub")) && item->type == cJSON_True)
        meta->enable_github = 1;
    if ((item = cJSON_GetObjectItem(root, "enableDiscord")) && item->type == cJSON_True)
        meta->enable_discord = 1;
    
    cJSON_Delete(root);
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

MisskeyError misskey_notes_timeline(MisskeyClient* client, int limit, int local, MisskeyNote** notes_out, int* count_out) {
    if (!client || !notes_out || !count_out) return MISSKEY_ERROR_INVALID_PARAM;
    *notes_out = NULL;
    *count_out = 0;
    
    char* resp = NULL;
    MisskeyError err = misskey_notes_timeline_raw(client, limit, local, &resp);
    if (err != MISSKEY_OK) return err;
    
    cJSON* root = cJSON_Parse(resp);
    if (!root || root->type != cJSON_Array) {
        misskey_free_string(client, resp);
        return MISSKEY_ERROR_JSON;
    }
    
    int count = cJSON_GetArraySize(root);
    if (count == 0) {
        cJSON_Delete(root);
        misskey_free_string(client, resp);
        return MISSKEY_OK;
    }
    
    MisskeyNote* notes = alloc_allocator(&client->allocator, count * sizeof(MisskeyNote));
    if (!notes) {
        cJSON_Delete(root);
        misskey_free_string(client, resp);
        return MISSKEY_ERROR_ALLOC;
    }
    
    for (int i = 0; i < count; i++) {
        cJSON* item = cJSON_GetArrayItem(root, i);
        parse_note(item, &notes[i]);
    }
    
    *notes_out = notes;
    *count_out = count;
    
    cJSON_Delete(root);
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

MisskeyError misskey_notes_create(MisskeyClient* client, const char* text, const char* reply_id, const char* renote_id, MisskeyNote* note_out) {
    if (!client || !note_out) return MISSKEY_ERROR_INVALID_PARAM;
    misskey_note_init(note_out);
    
    char* resp = NULL;
    MisskeyError err = misskey_notes_create_raw(client, text, reply_id, renote_id, &resp);
    if (err != MISSKEY_OK) return err;
    
    cJSON* root = cJSON_Parse(resp);
    if (!root) {
        misskey_free_string(client, resp);
        return MISSKEY_ERROR_JSON;
    }
    
    cJSON* created_note = cJSON_GetObjectItem(root, "createdNote");
    if (created_note) {
        parse_note(created_note, note_out);
    }
    
    cJSON_Delete(root);
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

MisskeyError misskey_notes_show(MisskeyClient* client, const char* note_id, MisskeyNote* note_out) {
    if (!client || !note_id || !note_out) return MISSKEY_ERROR_INVALID_PARAM;
    misskey_note_init(note_out);
    
    char* resp = NULL;
    MisskeyError err = misskey_notes_show_raw(client, note_id, &resp);
    if (err != MISSKEY_OK) return err;
    
    cJSON* root = cJSON_Parse(resp);
    if (!root) {
        misskey_free_string(client, resp);
        return MISSKEY_ERROR_JSON;
    }
    
    parse_note(root, note_out);
    
    cJSON_Delete(root);
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

MisskeyError misskey_notes_delete(MisskeyClient* client, const char* note_id, char note_id_out[32]) {
    if (!client || !note_id || !note_id_out) return MISSKEY_ERROR_INVALID_PARAM;
    note_id_out[0] = '\0';
    
    char* resp = NULL;
    MisskeyError err = misskey_notes_delete_raw(client, note_id, &resp);
    if (err != MISSKEY_OK) return err;
    
    strncpy(note_id_out, note_id, 31);
    
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

MisskeyError misskey_notes(MisskeyClient* client, const char* text, const char* reply_id, const char* renote_id, const char* channel_id, int limit, int offset, const char* user_id, int local_only, int reply, int renote, int with_files, const char* since_id, const char* until_id, MisskeyNote** notes_out, int* count_out) {
    if (!client || !notes_out || !count_out) return MISSKEY_ERROR_INVALID_PARAM;
    *notes_out = NULL;
    *count_out = 0;
    
    char* resp = NULL;
    MisskeyError err = misskey_notes_raw(client, text, reply_id, renote_id, channel_id, limit, offset, user_id, local_only, reply, renote, with_files, since_id, until_id, &resp);
    if (err != MISSKEY_OK) return err;
    
    cJSON* root = cJSON_Parse(resp);
    if (!root || root->type != cJSON_Array) {
        misskey_free_string(client, resp);
        return MISSKEY_ERROR_JSON;
    }
    
    int count = cJSON_GetArraySize(root);
    if (count == 0) {
        cJSON_Delete(root);
        misskey_free_string(client, resp);
        return MISSKEY_OK;
    }
    
    MisskeyNote* notes = alloc_allocator(&client->allocator, count * sizeof(MisskeyNote));
    if (!notes) {
        cJSON_Delete(root);
        misskey_free_string(client, resp);
        return MISSKEY_ERROR_ALLOC;
    }
    
    for (int i = 0; i < count; i++) {
        cJSON* item = cJSON_GetArrayItem(root, i);
        parse_note(item, &notes[i]);
    }
    
    *notes_out = notes;
    *count_out = count;
    
    cJSON_Delete(root);
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

MisskeyError misskey_i_notifications(MisskeyClient* client, int limit, MisskeyNotification** notifications_out, int* count_out) {
    if (!client || !notifications_out || !count_out) return MISSKEY_ERROR_INVALID_PARAM;
    *notifications_out = NULL;
    *count_out = 0;
    
    char* resp = NULL;
    MisskeyError err = misskey_i_notifications_raw(client, limit, &resp);
    if (err != MISSKEY_OK) return err;
    
    cJSON* root = cJSON_Parse(resp);
    if (!root || root->type != cJSON_Array) {
        misskey_free_string(client, resp);
        return MISSKEY_ERROR_JSON;
    }
    
    int count = cJSON_GetArraySize(root);
    if (count == 0) {
        cJSON_Delete(root);
        misskey_free_string(client, resp);
        return MISSKEY_OK;
    }
    
    MisskeyNotification* notifications = alloc_allocator(&client->allocator, count * sizeof(MisskeyNotification));
    if (!notifications) {
        cJSON_Delete(root);
        misskey_free_string(client, resp);
        return MISSKEY_ERROR_ALLOC;
    }
    
    for (int i = 0; i < count; i++) {
        cJSON* item = cJSON_GetArrayItem(root, i);
        misskey_notification_init(&notifications[i]);
        
        cJSON* nitem;
        if ((nitem = cJSON_GetObjectItem(item, "id")) && nitem->type == cJSON_String)
            strncpy(notifications[i].id, nitem->valuestring, sizeof(notifications[i].id) - 1);
        if ((nitem = cJSON_GetObjectItem(item, "createdAt")) && nitem->type == cJSON_String)
            strncpy(notifications[i].created_at, nitem->valuestring, sizeof(notifications[i].created_at) - 1);
        if ((nitem = cJSON_GetObjectItem(item, "type")) && nitem->type == cJSON_String)
            strncpy(notifications[i].type, nitem->valuestring, sizeof(notifications[i].type) - 1);
        if ((nitem = cJSON_GetObjectItem(item, "userId")) && nitem->type == cJSON_String)
            strncpy(notifications[i].user_id, nitem->valuestring, sizeof(notifications[i].user_id) - 1);
        if ((nitem = cJSON_GetObjectItem(item, "userName")) && nitem->type == cJSON_String)
            strncpy(notifications[i].user_name, nitem->valuestring, sizeof(notifications[i].user_name) - 1);
        if ((nitem = cJSON_GetObjectItem(item, "noteId")) && nitem->type == cJSON_String)
            strncpy(notifications[i].note_id, nitem->valuestring, sizeof(notifications[i].note_id) - 1);
        if ((nitem = cJSON_GetObjectItem(item, "reaction")) && nitem->type == cJSON_String)
            strncpy(notifications[i].reaction, nitem->valuestring, sizeof(notifications[i].reaction) - 1);
        if ((nitem = cJSON_GetObjectItem(item, "message")) && nitem->type == cJSON_String)
            strncpy(notifications[i].message, nitem->valuestring, sizeof(notifications[i].message) - 1);
        
        cJSON* user = cJSON_GetObjectItem(item, "user");
        if (user) parse_user(user, &notifications[i].user);
    }
    
    *notifications_out = notifications;
    *count_out = count;
    
    cJSON_Delete(root);
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

MisskeyError misskey_drive(MisskeyClient* client, MisskeyDriveInfo* info) {
    if (!client || !info) return MISSKEY_ERROR_INVALID_PARAM;
    misskey_drive_info_init(info);
    
    char* resp = NULL;
    MisskeyError err = misskey_drive_raw(client, &resp);
    if (err != MISSKEY_OK) return err;
    
    cJSON* root = cJSON_Parse(resp);
    if (!root) {
        misskey_free_string(client, resp);
        return MISSKEY_ERROR_JSON;
    }
    
    cJSON* item;
    if ((item = cJSON_GetObjectItem(root, "capacity")) && item->type == cJSON_Number)
        info->capacity = (int)item->valueint;
    if ((item = cJSON_GetObjectItem(root, "usage")) && item->type == cJSON_Number)
        info->usage = (int)item->valueint;
    if ((item = cJSON_GetObjectItem(root, "isOverQuotaCapacity")) && item->type == cJSON_True)
        info->drive_usage_over_quota = 1;
    if ((item = cJSON_GetObjectItem(root, "incCapacity")) && item->type == cJSON_Number)
        info->inc_capacity = (int)item->valueint;
    
    cJSON_Delete(root);
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

static MisskeyError parse_drive_files(MisskeyClient* client, char* resp, MisskeyDriveFile** files_out, int* count_out) {
    if (!resp || !files_out || !count_out) return MISSKEY_ERROR_INVALID_PARAM;
    *files_out = NULL;
    *count_out = 0;
    
    cJSON* root = cJSON_Parse(resp);
    if (!root || root->type != cJSON_Array) {
        return MISSKEY_ERROR_JSON;
    }
    
    int count = cJSON_GetArraySize(root);
    if (count == 0) {
        cJSON_Delete(root);
        return MISSKEY_OK;
    }
    
    MisskeyDriveFile* files = alloc_allocator(&client->allocator, count * sizeof(MisskeyDriveFile));
    if (!files) {
        cJSON_Delete(root);
        return MISSKEY_ERROR_ALLOC;
    }
    
    for (int i = 0; i < count; i++) {
        cJSON* item = cJSON_GetArrayItem(root, i);
        misskey_drive_file_init(&files[i]);
        
        cJSON* fitem;
        if ((fitem = cJSON_GetObjectItem(item, "id")) && fitem->type == cJSON_String)
            strncpy(files[i].id, fitem->valuestring, sizeof(files[i].id) - 1);
        if ((fitem = cJSON_GetObjectItem(item, "createdAt")) && fitem->type == cJSON_String)
            strncpy(files[i].created_at, fitem->valuestring, sizeof(files[i].created_at) - 1);
        if ((fitem = cJSON_GetObjectItem(item, "name")) && fitem->type == cJSON_String)
            strncpy(files[i].name, fitem->valuestring, sizeof(files[i].name) - 1);
        if ((fitem = cJSON_GetObjectItem(item, "type")) && fitem->type == cJSON_String)
            strncpy(files[i].type, fitem->valuestring, sizeof(files[i].type) - 1);
        if ((fitem = cJSON_GetObjectItem(item, "md5")) && fitem->type == cJSON_String)
            strncpy(files[i].md5, fitem->valuestring, sizeof(files[i].md5) - 1);
        if ((fitem = cJSON_GetObjectItem(item, "size")) && fitem->type == cJSON_Number)
            files[i].size = (size_t)item->valueint;
        if ((fitem = cJSON_GetObjectItem(item, "url")) && fitem->type == cJSON_String)
            strncpy(files[i].url, fitem->valuestring, sizeof(files[i].url) - 1);
        if ((fitem = cJSON_GetObjectItem(item, "thumbnailUrl")) && fitem->type == cJSON_String)
            strncpy(files[i].thumbnail_url, fitem->valuestring, sizeof(files[i].thumbnail_url) - 1);
        if ((fitem = cJSON_GetObjectItem(item, "folderId")) && fitem->type == cJSON_String)
            strncpy(files[i].folder_id, fitem->valuestring, sizeof(files[i].folder_id) - 1);
        if ((fitem = cJSON_GetObjectItem(item, "userId")) && fitem->type == cJSON_String)
            strncpy(files[i].user_id, fitem->valuestring, sizeof(files[i].user_id) - 1);
        if ((fitem = cJSON_GetObjectItem(item, "isSensitive")) && fitem->type == cJSON_True)
            files[i].is_sensitive = 1;
    }
    
    *files_out = files;
    *count_out = count;
    
    cJSON_Delete(root);
    return MISSKEY_OK;
}

MisskeyError misskey_drive_files(MisskeyClient* client, int limit, const char* folder_id, MisskeyDriveFile** files_out, int* count_out) {
    if (!client || !files_out || !count_out) return MISSKEY_ERROR_INVALID_PARAM;
    
    char* resp = NULL;
    MisskeyError err = misskey_drive_files_raw(client, limit, folder_id ? 1 : 0, &resp);
    if (err != MISSKEY_OK) return err;
    
    err = parse_drive_files(client, resp, files_out, count_out);
    misskey_free_string(client, resp);
    return err;
}

MisskeyError misskey_drive_files_create(MisskeyClient* client, const char* file_path, const char* folder_id, const char* name, MisskeyDriveFile* file_out) {
    if (!client || !file_out) return MISSKEY_ERROR_INVALID_PARAM;
    misskey_drive_file_init(file_out);
    
    char* resp = NULL;
    MisskeyError err = misskey_drive_files_create_raw(client, file_path, folder_id, name, &resp);
    if (err != MISSKEY_OK) return err;
    
    cJSON* root = cJSON_Parse(resp);
    if (root) {
        cJSON* item;
        if ((item = cJSON_GetObjectItem(root, "id")) && item->type == cJSON_String)
            strncpy(file_out->id, item->valuestring, sizeof(file_out->id) - 1);
        if ((item = cJSON_GetObjectItem(root, "name")) && item->type == cJSON_String)
            strncpy(file_out->name, item->valuestring, sizeof(file_out->name) - 1);
        if ((item = cJSON_GetObjectItem(root, "type")) && item->type == cJSON_String)
            strncpy(file_out->type, item->valuestring, sizeof(file_out->type) - 1);
        if ((item = cJSON_GetObjectItem(root, "url")) && item->type == cJSON_String)
            strncpy(file_out->url, item->valuestring, sizeof(file_out->url) - 1);
        cJSON_Delete(root);
    }
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

MisskeyError misskey_drive_files_delete(MisskeyClient* client, const char* file_id, char file_id_out[32]) {
    if (!client || !file_id || !file_id_out) return MISSKEY_ERROR_INVALID_PARAM;
    file_id_out[0] = '\0';
    
    char* resp = NULL;
    MisskeyError err = misskey_drive_files_delete_raw(client, file_id, &resp);
    if (err != MISSKEY_OK) return err;
    
    strncpy(file_id_out, file_id, 31);
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

MisskeyError misskey_drive_files_update(MisskeyClient* client, const char* file_id, const char* folder_id, const char* name, MisskeyDriveFile* file_out) {
    if (!client || !file_out) return MISSKEY_ERROR_INVALID_PARAM;
    misskey_drive_file_init(file_out);
    
    char* resp = NULL;
    MisskeyError err = misskey_drive_files_update_raw(client, file_id, folder_id, name, &resp);
    if (err != MISSKEY_OK) return err;
    
    cJSON* root = cJSON_Parse(resp);
    if (root) {
        cJSON* item;
        if ((item = cJSON_GetObjectItem(root, "id")) && item->type == cJSON_String)
            strncpy(file_out->id, item->valuestring, sizeof(file_out->id) - 1);
        if ((item = cJSON_GetObjectItem(root, "name")) && item->type == cJSON_String)
            strncpy(file_out->name, item->valuestring, sizeof(file_out->name) - 1);
        cJSON_Delete(root);
    }
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

MisskeyError misskey_drive_files_find(MisskeyClient* client, const char* hash, MisskeyDriveFile** files_out, int* count_out) {
    if (!client || !files_out || !count_out) return MISSKEY_ERROR_INVALID_PARAM;
    
    char* resp = NULL;
    MisskeyError err = misskey_drive_files_find_raw(client, hash, &resp);
    if (err != MISSKEY_OK) return err;
    
    err = parse_drive_files(client, resp, files_out, count_out);
    misskey_free_string(client, resp);
    return err;
}

MisskeyError misskey_drive_files_show(MisskeyClient* client, const char* file_id, const char* url, MisskeyDriveFile* file_out) {
    if (!client || !file_out) return MISSKEY_ERROR_INVALID_PARAM;
    misskey_drive_file_init(file_out);
    
    char* resp = NULL;
    MisskeyError err = misskey_drive_files_show_raw(client, file_id, url, &resp);
    if (err != MISSKEY_OK) return err;
    
    cJSON* root = cJSON_Parse(resp);
    if (root) {
        cJSON* item;
        if ((item = cJSON_GetObjectItem(root, "id")) && item->type == cJSON_String)
            strncpy(file_out->id, item->valuestring, sizeof(file_out->id) - 1);
        if ((item = cJSON_GetObjectItem(root, "name")) && item->type == cJSON_String)
            strncpy(file_out->name, item->valuestring, sizeof(file_out->name) - 1);
        if ((item = cJSON_GetObjectItem(root, "url")) && item->type == cJSON_String)
            strncpy(file_out->url, item->valuestring, sizeof(file_out->url) - 1);
        cJSON_Delete(root);
    }
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

MisskeyError misskey_drive_files_upload_from_url(MisskeyClient* client, const char* url, const char* folder_id, int is_sensitive, const char* comment, MisskeyDriveFile* file_out) {
    if (!client || !file_out) return MISSKEY_ERROR_INVALID_PARAM;
    misskey_drive_file_init(file_out);
    
    char* resp = NULL;
    MisskeyError err = misskey_drive_files_upload_from_url_raw(client, url, folder_id, is_sensitive, comment, &resp);
    if (err != MISSKEY_OK) return err;
    
    cJSON* root = cJSON_Parse(resp);
    if (root) {
        cJSON* item;
        if ((item = cJSON_GetObjectItem(root, "id")) && item->type == cJSON_String)
            strncpy(file_out->id, item->valuestring, sizeof(file_out->id) - 1);
        if ((item = cJSON_GetObjectItem(root, "name")) && item->type == cJSON_String)
            strncpy(file_out->name, item->valuestring, sizeof(file_out->name) - 1);
        cJSON_Delete(root);
    }
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

MisskeyError misskey_drive_folders(MisskeyClient* client, int limit, const char* folder_id, MisskeyDriveFolder** folders_out, int* count_out) {
    if (!client || !folders_out || !count_out) return MISSKEY_ERROR_INVALID_PARAM;
    *folders_out = NULL;
    *count_out = 0;
    
    char* resp = NULL;
    MisskeyError err = misskey_drive_folders_raw(client, limit, folder_id, &resp);
    if (err != MISSKEY_OK) return err;
    
    cJSON* root = cJSON_Parse(resp);
    if (!root || root->type != cJSON_Array) {
        misskey_free_string(client, resp);
        return MISSKEY_ERROR_JSON;
    }
    
    int count = cJSON_GetArraySize(root);
    if (count == 0) {
        cJSON_Delete(root);
        misskey_free_string(client, resp);
        return MISSKEY_OK;
    }
    
    MisskeyDriveFolder* folders = alloc_allocator(&client->allocator, count * sizeof(MisskeyDriveFolder));
    if (!folders) {
        cJSON_Delete(root);
        misskey_free_string(client, resp);
        return MISSKEY_ERROR_ALLOC;
    }
    
    for (int i = 0; i < count; i++) {
        cJSON* item = cJSON_GetArrayItem(root, i);
        misskey_drive_folder_init(&folders[i]);
        
        cJSON* fitem;
        if ((fitem = cJSON_GetObjectItem(item, "id")) && fitem->type == cJSON_String)
            strncpy(folders[i].id, fitem->valuestring, sizeof(folders[i].id) - 1);
        if ((fitem = cJSON_GetObjectItem(item, "createdAt")) && fitem->type == cJSON_String)
            strncpy(folders[i].created_at, fitem->valuestring, sizeof(folders[i].created_at) - 1);
        if ((fitem = cJSON_GetObjectItem(item, "name")) && fitem->type == cJSON_String)
            strncpy(folders[i].name, fitem->valuestring, sizeof(folders[i].name) - 1);
        if ((fitem = cJSON_GetObjectItem(item, "parentId")) && fitem->type == cJSON_String)
            strncpy(folders[i].parent_id, fitem->valuestring, sizeof(folders[i].parent_id) - 1);
        if ((fitem = cJSON_GetObjectItem(item, "foldersCount")) && fitem->type == cJSON_Number)
            folders[i].folders_count = fitem->valueint;
        if ((fitem = cJSON_GetObjectItem(item, "filesCount")) && fitem->type == cJSON_Number)
            folders[i].files_count = fitem->valueint;
    }
    
    *folders_out = folders;
    *count_out = count;
    
    cJSON_Delete(root);
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

MisskeyError misskey_drive_folders_create(MisskeyClient* client, const char* name, const char* parent_id, MisskeyDriveFolder* folder_out) {
    if (!client || !folder_out) return MISSKEY_ERROR_INVALID_PARAM;
    misskey_drive_folder_init(folder_out);
    
    char* resp = NULL;
    MisskeyError err = misskey_drive_folders_create_raw(client, name, parent_id, &resp);
    if (err != MISSKEY_OK) return err;
    
    cJSON* root = cJSON_Parse(resp);
    if (root) {
        cJSON* item;
        if ((item = cJSON_GetObjectItem(root, "id")) && item->type == cJSON_String)
            strncpy(folder_out->id, item->valuestring, sizeof(folder_out->id) - 1);
        if ((item = cJSON_GetObjectItem(root, "name")) && item->type == cJSON_String)
            strncpy(folder_out->name, item->valuestring, sizeof(folder_out->name) - 1);
        cJSON_Delete(root);
    }
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

MisskeyError misskey_drive_folders_delete(MisskeyClient* client, const char* folder_id, char folder_id_out[32]) {
    if (!client || !folder_id || !folder_id_out) return MISSKEY_ERROR_INVALID_PARAM;
    folder_id_out[0] = '\0';
    
    char* resp = NULL;
    MisskeyError err = misskey_drive_folders_delete_raw(client, folder_id, &resp);
    if (err != MISSKEY_OK) return err;
    
    strncpy(folder_id_out, folder_id, 31);
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

MisskeyError misskey_drive_folders_update(MisskeyClient* client, const char* folder_id, const char* name, const char* parent_id, MisskeyDriveFolder* folder_out) {
    if (!client || !folder_out) return MISSKEY_ERROR_INVALID_PARAM;
    misskey_drive_folder_init(folder_out);
    
    char* resp = NULL;
    MisskeyError err = misskey_drive_folders_update_raw(client, folder_id, name, parent_id, &resp);
    if (err != MISSKEY_OK) return err;
    
    cJSON* root = cJSON_Parse(resp);
    if (root) {
        cJSON* item;
        if ((item = cJSON_GetObjectItem(root, "id")) && item->type == cJSON_String)
            strncpy(folder_out->id, item->valuestring, sizeof(folder_out->id) - 1);
        if ((item = cJSON_GetObjectItem(root, "name")) && item->type == cJSON_String)
            strncpy(folder_out->name, item->valuestring, sizeof(folder_out->name) - 1);
        cJSON_Delete(root);
    }
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

MisskeyError misskey_translate(MisskeyClient* client, const char* note_id, const char* target_lang, MisskeyTranslateResult* result_out) {
    if (!client || !note_id || !target_lang || !result_out) return MISSKEY_ERROR_INVALID_PARAM;
    misskey_translate_result_init(result_out);
    
    char* resp = NULL;
    MisskeyError err = misskey_translate_raw(client, note_id, target_lang, &resp);
    if (err != MISSKEY_OK) return err;
    
    cJSON* root = cJSON_Parse(resp);
    if (!root) {
        misskey_free_string(client, resp);
        return MISSKEY_ERROR_JSON;
    }
    
    cJSON* item;
    if ((item = cJSON_GetObjectItem(root, "text")) && item->type == cJSON_String)
        strncpy(result_out->text, item->valuestring, sizeof(result_out->text) - 1);
    if ((item = cJSON_GetObjectItem(root, "sourceLang")) && item->type == cJSON_String)
        strncpy(result_out->source_lang, item->valuestring, sizeof(result_out->source_lang) - 1);
    if ((item = cJSON_GetObjectItem(root, "targetLang")) && item->type == cJSON_String)
        strncpy(result_out->target_lang, item->valuestring, sizeof(result_out->target_lang) - 1);
    
    cJSON_Delete(root);
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

MisskeyError misskey_clips_list(MisskeyClient* client, MisskeyClip** clips_out, int* count_out) {
    if (!client || !clips_out || !count_out) return MISSKEY_ERROR_INVALID_PARAM;
    *clips_out = NULL;
    *count_out = 0;
    
    char* resp = NULL;
    MisskeyError err = misskey_clips_list_raw(client, &resp);
    if (err != MISSKEY_OK) return err;
    
    cJSON* root = cJSON_Parse(resp);
    if (!root || root->type != cJSON_Array) {
        misskey_free_string(client, resp);
        return MISSKEY_ERROR_JSON;
    }
    
    int count = cJSON_GetArraySize(root);
    if (count == 0) {
        cJSON_Delete(root);
        misskey_free_string(client, resp);
        return MISSKEY_OK;
    }
    
    MisskeyClip* clips = alloc_allocator(&client->allocator, count * sizeof(MisskeyClip));
    if (!clips) {
        cJSON_Delete(root);
        misskey_free_string(client, resp);
        return MISSKEY_ERROR_ALLOC;
    }
    
    for (int i = 0; i < count; i++) {
        cJSON* item = cJSON_GetArrayItem(root, i);
        misskey_clip_init(&clips[i]);
        
        cJSON* citem;
        if ((citem = cJSON_GetObjectItem(item, "id")) && citem->type == cJSON_String)
            strncpy(clips[i].id, citem->valuestring, sizeof(clips[i].id) - 1);
        if ((citem = cJSON_GetObjectItem(item, "createdAt")) && citem->type == cJSON_String)
            strncpy(clips[i].created_at, citem->valuestring, sizeof(clips[i].created_at) - 1);
        if ((citem = cJSON_GetObjectItem(item, "name")) && citem->type == cJSON_String)
            strncpy(clips[i].name, citem->valuestring, sizeof(clips[i].name) - 1);
        if ((citem = cJSON_GetObjectItem(item, "description")) && citem->type == cJSON_String)
            strncpy(clips[i].description, citem->valuestring, sizeof(clips[i].description) - 1);
        if ((citem = cJSON_GetObjectItem(item, "isPublic")) && citem->type == cJSON_True)
            clips[i].is_public = 1;
        if ((citem = cJSON_GetObjectItem(item, "notesCount")) && citem->type == cJSON_Number)
            clips[i].notes_count = citem->valueint;
    }
    
    *clips_out = clips;
    *count_out = count;
    
    cJSON_Delete(root);
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

MisskeyError misskey_clips_show(MisskeyClient* client, const char* clip_id, MisskeyClip* clip_out) {
    if (!client || !clip_id || !clip_out) return MISSKEY_ERROR_INVALID_PARAM;
    misskey_clip_init(clip_out);
    
    char* resp = NULL;
    MisskeyError err = misskey_clips_show_raw(client, clip_id, &resp);
    if (err != MISSKEY_OK) return err;
    
    cJSON* root = cJSON_Parse(resp);
    if (root) {
        cJSON* item;
        if ((item = cJSON_GetObjectItem(root, "id")) && item->type == cJSON_String)
            strncpy(clip_out->id, item->valuestring, sizeof(clip_out->id) - 1);
        if ((item = cJSON_GetObjectItem(root, "name")) && item->type == cJSON_String)
            strncpy(clip_out->name, item->valuestring, sizeof(clip_out->name) - 1);
        if ((item = cJSON_GetObjectItem(root, "description")) && item->type == cJSON_String)
            strncpy(clip_out->description, item->valuestring, sizeof(clip_out->description) - 1);
        if ((item = cJSON_GetObjectItem(root, "isPublic")) && item->type == cJSON_True)
            clip_out->is_public = 1;
        if ((item = cJSON_GetObjectItem(root, "notesCount")) && item->type == cJSON_Number)
            clip_out->notes_count = item->valueint;
        cJSON_Delete(root);
    }
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

MisskeyError misskey_clips_create(MisskeyClient* client, const char* name, const char* description, int is_public, MisskeyClip* clip_out) {
    if (!client || !clip_out) return MISSKEY_ERROR_INVALID_PARAM;
    misskey_clip_init(clip_out);
    
    char* resp = NULL;
    MisskeyError err = misskey_clips_create_raw(client, name, description, is_public, &resp);
    if (err != MISSKEY_OK) return err;
    
    cJSON* root = cJSON_Parse(resp);
    if (root) {
        cJSON* item;
        if ((item = cJSON_GetObjectItem(root, "id")) && item->type == cJSON_String)
            strncpy(clip_out->id, item->valuestring, sizeof(clip_out->id) - 1);
        if ((item = cJSON_GetObjectItem(root, "name")) && item->type == cJSON_String)
            strncpy(clip_out->name, item->valuestring, sizeof(clip_out->name) - 1);
        if ((item = cJSON_GetObjectItem(root, "description")) && item->type == cJSON_String)
            strncpy(clip_out->description, item->valuestring, sizeof(clip_out->description) - 1);
        clip_out->is_public = is_public;
        cJSON_Delete(root);
    }
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

MisskeyError misskey_clips_update(MisskeyClient* client, const char* clip_id, const char* name, const char* description, int is_public, MisskeyClip* clip_out) {
    if (!client || !clip_out) return MISSKEY_ERROR_INVALID_PARAM;
    misskey_clip_init(clip_out);
    
    char* resp = NULL;
    MisskeyError err = misskey_clips_update_raw(client, clip_id, name, description, is_public, &resp);
    if (err != MISSKEY_OK) return err;
    
    cJSON* root = cJSON_Parse(resp);
    if (root) {
        cJSON* item;
        if ((item = cJSON_GetObjectItem(root, "id")) && item->type == cJSON_String)
            strncpy(clip_out->id, item->valuestring, sizeof(clip_out->id) - 1);
        if ((item = cJSON_GetObjectItem(root, "name")) && item->type == cJSON_String)
            strncpy(clip_out->name, item->valuestring, sizeof(clip_out->name) - 1);
        cJSON_Delete(root);
    }
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

MisskeyError misskey_clips_delete(MisskeyClient* client, const char* clip_id, char clip_id_out[32]) {
    if (!client || !clip_id || !clip_id_out) return MISSKEY_ERROR_INVALID_PARAM;
    clip_id_out[0] = '\0';
    
    char* resp = NULL;
    MisskeyError err = misskey_clips_delete_raw(client, clip_id, &resp);
    if (err != MISSKEY_OK) return err;
    
    strncpy(clip_id_out, clip_id, 31);
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

MisskeyError misskey_clips_notes(MisskeyClient* client, const char* clip_id, int limit, MisskeyNote** notes_out, int* count_out) {
    if (!client || !notes_out || !count_out) return MISSKEY_ERROR_INVALID_PARAM;
    *notes_out = NULL;
    *count_out = 0;
    
    char* resp = NULL;
    MisskeyError err = misskey_clips_notes_raw(client, clip_id, limit, &resp);
    if (err != MISSKEY_OK) return err;
    
    cJSON* root = cJSON_Parse(resp);
    if (!root || root->type != cJSON_Array) {
        misskey_free_string(client, resp);
        return MISSKEY_ERROR_JSON;
    }
    
    int count = cJSON_GetArraySize(root);
    if (count == 0) {
        cJSON_Delete(root);
        misskey_free_string(client, resp);
        return MISSKEY_OK;
    }
    
    MisskeyNote* notes = alloc_allocator(&client->allocator, count * sizeof(MisskeyNote));
    if (!notes) {
        cJSON_Delete(root);
        misskey_free_string(client, resp);
        return MISSKEY_ERROR_ALLOC;
    }
    
    for (int i = 0; i < count; i++) {
        cJSON* item = cJSON_GetArrayItem(root, i);
        parse_note(item, &notes[i]);
    }
    
    *notes_out = notes;
    *count_out = count;
    
    cJSON_Delete(root);
    misskey_free_string(client, resp);
    return MISSKEY_OK;
}

void misskey_free_notes(MisskeyClient* client, MisskeyNote* notes, int count) {
    if (notes) free_allocator(&client->allocator, notes);
}

void misskey_free_notifications(MisskeyClient* client, MisskeyNotification* notifications, int count) {
    if (notifications) free_allocator(&client->allocator, notifications);
}

void misskey_free_drive_files(MisskeyClient* client, MisskeyDriveFile* files, int count) {
    if (files) free_allocator(&client->allocator, files);
}

void misskey_free_drive_folders(MisskeyClient* client, MisskeyDriveFolder* folders, int count) {
    if (folders) free_allocator(&client->allocator, folders);
}

void misskey_free_clips(MisskeyClient* client, MisskeyClip* clips, int count) {
    if (clips) free_allocator(&client->allocator, clips);
}
