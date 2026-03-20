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
void misskey_client_get_last_error(MisskeyClient* client, long* http_code, char** error_detail);

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
MisskeyError misskey_notes(MisskeyClient* client, const char* text,
                           const char* reply_id, const char* renote_id,
                           const char* channel_id, int limit, int offset,
                           const char* user_id, int local_only,
                           int reply, int renote, int with_files,
                           const char* since_id, const char* until_id,
                           char** response_out);
MisskeyError misskey_notes_show(MisskeyClient* client, const char* note_id,
                                char** response_out);
MisskeyError misskey_notes_delete(MisskeyClient* client, const char* note_id,
                                  char** response_out);
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

MisskeyError misskey_translate(MisskeyClient* client, const char* note_id,
                                const char* target_lang, char** response_out);

MisskeyError misskey_clips_list(MisskeyClient* client, char** response_out);
MisskeyError misskey_clips_show(MisskeyClient* client, const char* clip_id,
                                char** response_out);
MisskeyError misskey_clips_create(MisskeyClient* client, const char* name,
                                 const char* description, int is_public,
                                 char** response_out);
MisskeyError misskey_clips_update(MisskeyClient* client, const char* clip_id,
                                  const char* name, const char* description,
                                  int is_public, char** response_out);
MisskeyError misskey_clips_delete(MisskeyClient* client, const char* clip_id,
                                  char** response_out);
MisskeyError misskey_clips_add_note(MisskeyClient* client, const char* clip_id,
                                   const char* note_id, char** response_out);
MisskeyError misskey_clips_remove_note(MisskeyClient* client, const char* clip_id,
                                      const char* note_id, char** response_out);
MisskeyError misskey_clips_notes(MisskeyClient* client, const char* clip_id,
                                 int limit, char** response_out);

void misskey_free_string(MisskeyClient* client, char* str);

void misskey_set_global_allocator(const MisskeyAllocator* allocator);
const MisskeyAllocator* misskey_get_default_allocator(void);

typedef struct MisskeyUser {
    char id[32];
    char name[128];
    char username[64];
    char host[128];
    char avatar_url[512];
    char avatar_blurhash[64];
    int is_bot;
    int is_cat;
} MisskeyUser;

typedef struct MisskeyNote {
    char id[32];
    char created_at[32];
    char text[4096];
    char cw[512];
    char app_id[32];
    char user_id[32];
    char reply_id[32];
    char renote_id[32];
    char channel_id[32];
    char uri[256];
    char url[512];
    int visibility;
    int local_only;
    int visible_user_ids_count;
    int reactions_count;
    int replies_count;
    int renote_count;
    char reaction_emojis[512];
    MisskeyUser user;
} MisskeyNote;

typedef struct MisskeyNotification {
    char id[32];
    char created_at[32];
    char type[32];
    char user_id[32];
    char user_name[128];
    char note_id[32];
    char reaction[64];
    char message[512];
    MisskeyUser user;
} MisskeyNotification;

typedef struct MisskeyDriveFile {
    char id[32];
    char created_at[32];
    char name[256];
    char type[64];
    char md5[64];
    size_t size;
    char url[512];
    char thumbnail_url[512];
    char folder_id[32];
    char user_id[32];
    int is_sensitive;
} MisskeyDriveFile;

typedef struct MisskeyDriveFolder {
    char id[32];
    char created_at[32];
    char name[128];
    char parent_id[32];
    int folders_count;
    int files_count;
} MisskeyDriveFolder;

typedef struct MisskeyDriveInfo {
    int capacity;
    int usage;
    int drive_usage_over_quota;
    int inc_capacity;
} MisskeyDriveInfo;

typedef struct MisskeyTranslateResult {
    char text[4096];
    char source_lang[16];
    char target_lang[16];
} MisskeyTranslateResult;

typedef struct MisskeyClip {
    char id[32];
    char created_at[32];
    char name[128];
    char description[512];
    int is_public;
    int notes_count;
} MisskeyClip;

typedef struct MisskeyMeta {
    char name[128];
    char version[32];
    char uri[256];
    char description[1024];
    char maintainer_name[128];
    char maintainer_email[256];
    char langs[256];
    char banned_mask[32];
    char features[512];
    char mascot_image_url[512];
    char banner_url[512];
    char error_image_url[512];
    char icon_url[512];
    char background_image_url[512];
    char logo_image_url[512];
    char max_note_text_length;
    int enable_emoji_reactions;
    int enable_recursive_reaction;
    int drive_capacity;
    int enable_email;
    int enable_twitter;
    int enable_github;
    int enable_discord;
    int enable_external_nickname_repository;
    int manifest_json;
    int sw;
    int theme_color;
    int federation;
    int enable_hcaptcha;
    int enable_recaptcha;
    int enableturnstile;
    int max_noted_per_w;
    int max_noted_per_a_d;
    int update_since;
} MisskeyMeta;

void misskey_note_init(MisskeyNote* note);
void misskey_user_init(MisskeyUser* user);
void misskey_notification_init(MisskeyNotification* n);
void misskey_drive_file_init(MisskeyDriveFile* f);
void misskey_drive_folder_init(MisskeyDriveFolder* f);
void misskey_drive_info_init(MisskeyDriveInfo* info);
void misskey_translate_result_init(MisskeyTranslateResult* r);
void misskey_clip_init(MisskeyClip* c);
void misskey_meta_init(MisskeyMeta* m);

MisskeyError misskey_meta_struct(MisskeyClient* client, MisskeyMeta* meta);
MisskeyError misskey_notes_timeline_struct(MisskeyClient* client, int limit, int local, MisskeyNote** notes_out, int* count_out);
MisskeyError misskey_notes_create_struct(MisskeyClient* client, const char* text, const char* reply_id, const char* renote_id, MisskeyNote* note_out);
MisskeyError misskey_notes_show_struct(MisskeyClient* client, const char* note_id, MisskeyNote* note_out);
MisskeyError misskey_notes_delete_struct(MisskeyClient* client, const char* note_id, char note_id_out[32]);
MisskeyError misskey_notes_struct(MisskeyClient* client, const char* text, const char* reply_id, const char* renote_id, const char* channel_id, int limit, int offset, const char* user_id, int local_only, int reply, int renote, int with_files, const char* since_id, const char* until_id, MisskeyNote** notes_out, int* count_out);
MisskeyError misskey_i_notifications_struct(MisskeyClient* client, int limit, MisskeyNotification** notifications_out, int* count_out);
MisskeyError misskey_drive_struct(MisskeyClient* client, MisskeyDriveInfo* info);
MisskeyError misskey_drive_files_struct(MisskeyClient* client, int limit, const char* folder_id, MisskeyDriveFile** files_out, int* count_out);
MisskeyError misskey_drive_files_create_struct(MisskeyClient* client, const char* file_path, const char* folder_id, const char* name, MisskeyDriveFile* file_out);
MisskeyError misskey_drive_files_delete_struct(MisskeyClient* client, const char* file_id, char file_id_out[32]);
MisskeyError misskey_drive_files_update_struct(MisskeyClient* client, const char* file_id, const char* folder_id, const char* name, MisskeyDriveFile* file_out);
MisskeyError misskey_drive_files_find_struct(MisskeyClient* client, const char* hash, MisskeyDriveFile** files_out, int* count_out);
MisskeyError misskey_drive_files_show_struct(MisskeyClient* client, const char* file_id, const char* url, MisskeyDriveFile* file_out);
MisskeyError misskey_drive_files_upload_from_url_struct(MisskeyClient* client, const char* url, const char* folder_id, int is_sensitive, const char* comment, MisskeyDriveFile* file_out);
MisskeyError misskey_drive_folders_struct(MisskeyClient* client, int limit, const char* folder_id, MisskeyDriveFolder** folders_out, int* count_out);
MisskeyError misskey_drive_folders_create_struct(MisskeyClient* client, const char* name, const char* parent_id, MisskeyDriveFolder* folder_out);
MisskeyError misskey_drive_folders_delete_struct(MisskeyClient* client, const char* folder_id, char folder_id_out[32]);
MisskeyError misskey_drive_folders_update_struct(MisskeyClient* client, const char* folder_id, const char* name, const char* parent_id, MisskeyDriveFolder* folder_out);
MisskeyError misskey_translate_struct(MisskeyClient* client, const char* note_id, const char* target_lang, MisskeyTranslateResult* result_out);
MisskeyError misskey_clips_list_struct(MisskeyClient* client, MisskeyClip** clips_out, int* count_out);
MisskeyError misskey_clips_show_struct(MisskeyClient* client, const char* clip_id, MisskeyClip* clip_out);
MisskeyError misskey_clips_create_struct(MisskeyClient* client, const char* name, const char* description, int is_public, MisskeyClip* clip_out);
MisskeyError misskey_clips_update_struct(MisskeyClient* client, const char* clip_id, const char* name, const char* description, int is_public, MisskeyClip* clip_out);
MisskeyError misskey_clips_delete_struct(MisskeyClient* client, const char* clip_id, char clip_id_out[32]);
MisskeyError misskey_clips_notes_struct(MisskeyClient* client, const char* clip_id, int limit, MisskeyNote** notes_out, int* count_out);

void misskey_free_notes(MisskeyClient* client, MisskeyNote* notes, int count);
void misskey_free_notifications(MisskeyClient* client, MisskeyNotification* notifications, int count);
void misskey_free_drive_files(MisskeyClient* client, MisskeyDriveFile* files, int count);
void misskey_free_drive_folders(MisskeyClient* client, MisskeyDriveFolder* folders, int count);
void misskey_free_clips(MisskeyClient* client, MisskeyClip* clips, int count);

#endif
