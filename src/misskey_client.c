#include "misskey_client.h"
#include "cJSON/cJSON.h"
#include <curl/curl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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
};

const char* misskey_error_str(MisskeyError err) {
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

MisskeyError misskey_meta(MisskeyClient* client, char** response_out) {
    return misskey_request(client, "meta", "{\"detail\":false}", response_out);
}

MisskeyError misskey_notes_timeline(MisskeyClient* client, int limit,
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

MisskeyError misskey_notes_create(MisskeyClient* client, const char* text,
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

MisskeyError misskey_i_notifications(MisskeyClient* client, int limit,
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

MisskeyError misskey_drive(MisskeyClient* client, char** response_out) {
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "drive", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}

MisskeyError misskey_drive_files(MisskeyClient* client, int limit, int folder_id,
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

MisskeyError misskey_drive_files_create(MisskeyClient* client, const char* file_path,
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

MisskeyError misskey_drive_files_delete(MisskeyClient* client, const char* file_id,
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

MisskeyError misskey_drive_files_update(MisskeyClient* client, const char* file_id,
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

MisskeyError misskey_drive_files_find(MisskeyClient* client, const char* hash,
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

MisskeyError misskey_drive_files_show(MisskeyClient* client, const char* file_id,
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

MisskeyError misskey_drive_files_upload_from_url(MisskeyClient* client, const char* url,
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

MisskeyError misskey_drive_folders(MisskeyClient* client, int limit, const char* folder_id,
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

MisskeyError misskey_drive_folders_create(MisskeyClient* client, const char* name,
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

MisskeyError misskey_drive_folders_delete(MisskeyClient* client, const char* folder_id,
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

MisskeyError misskey_drive_folders_update(MisskeyClient* client, const char* folder_id,
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

MisskeyError misskey_translate(MisskeyClient* client, const char* text,
                                const char* source_lang, const char* target_lang,
                                char** response_out) {
    if (!text) return MISSKEY_ERROR_INVALID_PARAM;
    
    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "i", client->token);
    cJSON_AddStringToObject(root, "text", text);
    
    if (source_lang) cJSON_AddStringToObject(root, "sourceLang", source_lang);
    if (target_lang) cJSON_AddStringToObject(root, "targetLang", target_lang);
    
    char* json_str = cJSON_PrintUnformatted(root);
    MisskeyError err = misskey_request(client, "notes/translate", json_str, response_out);
    
    free(json_str);
    cJSON_Delete(root);
    return err;
}
