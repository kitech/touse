#ifndef MISSKEY_CLIENT_H
#define MISSKEY_CLIENT_H

#include <stddef.h>

typedef struct MisskeyClient MisskeyClient;

typedef struct MisskeyAllocator {
    void* (*malloc_fn)(size_t size);
    void* (*realloc_fn)(void* ptr, size_t size);
    void (*free_fn)(void* ptr);
    void* user_data;
} MisskeyAllocator;

typedef enum {
    MISSKEY_OK = 0,
    MISSKEY_ERROR_INVALID_PARAM,
    MISSKEY_ERROR_NETWORK,
    MISSKEY_ERROR_HTTP,
    MISSKEY_ERROR_JSON,
    MISSKEY_ERROR_AUTH,
    MISSKEY_ERROR_ALLOC,
    MISSKEY_ERROR_UNKNOWN
} MisskeyError;

const char* misskey_error_str(MisskeyError err);

MisskeyClient* misskey_client_new(const char* host);
MisskeyClient* misskey_client_new_with_allocator(const char* host, const MisskeyAllocator* allocator);
void misskey_client_free(MisskeyClient* client);

void misskey_client_set_token(MisskeyClient* client, const char* token);
void misskey_client_set_timeout(MisskeyClient* client, long timeout_secs);
const MisskeyAllocator* misskey_client_get_allocator(const MisskeyClient* client);

MisskeyError misskey_request(MisskeyClient* client, const char* endpoint,
                             const char* request_body, char** response_out);
void misskey_request_set_debug(MisskeyClient* client, int enable);
void misskey_request_print_curl(MisskeyClient* client, const char* endpoint,
                                const char* request_body);
MisskeyError misskey_meta(MisskeyClient* client, char** response_out);
MisskeyError misskey_notes_timeline(MisskeyClient* client, int limit,
                                     int local, char** response_out);
MisskeyError misskey_notes_create(MisskeyClient* client, const char* text,
                                   const char* reply_id, const char* renote_id,
                                   char** response_out);
MisskeyError misskey_i_notifications(MisskeyClient* client, int limit,
                                       char** response_out);

MisskeyError misskey_drive(MisskeyClient* client, char** response_out);

MisskeyError misskey_drive_files(MisskeyClient* client, int limit, int folder_id,
                                  char** response_out);
MisskeyError misskey_drive_files_create(MisskeyClient* client, const char* file_path,
                                         const char* folder_id, const char* name,
                                         char** response_out);
MisskeyError misskey_drive_files_delete(MisskeyClient* client, const char* file_id,
                                         char** response_out);
MisskeyError misskey_drive_files_update(MisskeyClient* client, const char* file_id,
                                         const char* folder_id, const char* name,
                                         char** response_out);
MisskeyError misskey_drive_files_find(MisskeyClient* client, const char* hash,
                                        char** response_out);
MisskeyError misskey_drive_files_show(MisskeyClient* client, const char* file_id,
                                       const char* url, char** response_out);
MisskeyError misskey_drive_files_upload_from_url(MisskeyClient* client, const char* url,
                                                   const char* folder_id, int is_sensitive,
                                                   const char* comment, char** response_out);

typedef size_t (*misskey_write_callback)(void* contents, size_t size, size_t nmemb, void* userp);
typedef struct {
    void* data;
    size_t size;
    size_t capacity;
} MisskeyBuffer;

typedef struct {
    const char* url;
    const char* output_path;
    misskey_write_callback write_cb;
    void* write_userdata;
    long resume_from;
    int follow_redirects;
} MisskeyDownloadOptions;

MisskeyError misskey_drive_files_download(MisskeyClient* client, const char* file_id,
                                          const MisskeyDownloadOptions* options,
                                          long* http_code_out, long* content_length_out);
MisskeyError misskey_drive_folders(MisskeyClient* client, int limit, const char* folder_id,
                                   char** response_out);
MisskeyError misskey_drive_folders_create(MisskeyClient* client, const char* name,
                                           const char* parent_id, char** response_out);
MisskeyError misskey_drive_folders_delete(MisskeyClient* client, const char* folder_id,
                                           char** response_out);
MisskeyError misskey_drive_folders_update(MisskeyClient* client, const char* folder_id,
                                           const char* name, const char* parent_id,
                                           char** response_out);

MisskeyError misskey_translate(MisskeyClient* client, const char* text,
                                const char* source_lang, const char* target_lang,
                                char** response_out);

void misskey_free_string(MisskeyClient* client, char* str);

void misskey_set_global_allocator(const MisskeyAllocator* allocator);
const MisskeyAllocator* misskey_get_default_allocator(void);

#endif
