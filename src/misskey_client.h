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
MisskeyError misskey_meta(MisskeyClient* client, char** response_out);
MisskeyError misskey_notes_timeline(MisskeyClient* client, int limit,
                                     int local, char** response_out);
MisskeyError misskey_notes_create(MisskeyClient* client, const char* text,
                                   const char* reply_id, const char* renote_id,
                                   char** response_out);
MisskeyError misskey_i_notifications(MisskeyClient* client, int limit,
                                      char** response_out);

void misskey_free_string(MisskeyClient* client, char* str);

void misskey_set_global_allocator(const MisskeyAllocator* allocator);
const MisskeyAllocator* misskey_get_default_allocator(void);

#endif
