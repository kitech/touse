#include "misskey_client.h"
#include "cJSON/cJSON.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static size_t g_alloc_count = 0;
static size_t g_free_count = 0;
static size_t g_total_allocated = 0;

static void* tracking_malloc(size_t size) {
    void* ptr = malloc(size + sizeof(size_t));
    if (!ptr) return NULL;
    *((size_t*)ptr) = size;
    g_alloc_count++;
    g_total_allocated += size;
    return (char*)ptr + sizeof(size_t);
}

static void* tracking_realloc(void* ptr, size_t size) {
    if (!ptr) return tracking_malloc(size);
    void* real_ptr = (char*)ptr - sizeof(size_t);
    size_t old_size = *((size_t*)real_ptr);
    void* new_ptr = realloc(real_ptr, size + sizeof(size_t));
    if (!new_ptr) return NULL;
    *((size_t*)new_ptr) = size;
    g_total_allocated = g_total_allocated - old_size + size;
    return (char*)new_ptr + sizeof(size_t);
}

static void tracking_free(void* ptr) {
    if (!ptr) return;
    void* real_ptr = (char*)ptr - sizeof(size_t);
    size_t size = *((size_t*)real_ptr);
    g_free_count++;
    g_total_allocated -= size;
    free(real_ptr);
}

static void print_json_parsed(const char* json_str) {
    cJSON* root = cJSON_Parse(json_str);
    if (!root) {
        printf("Failed to parse JSON\n");
        return;
    }
    char* pretty = cJSON_Print(root);
    printf("%s\n", pretty);
    free(pretty);
    cJSON_Delete(root);
}

static void print_alloc_stats(void) {
    printf("\n=== Memory Stats ===\n");
    printf("Alloc calls: %zu\n", g_alloc_count);
    printf("Free calls:  %zu\n", g_free_count);
    printf("Outstanding: %zu\n", g_alloc_count - g_free_count);
    printf("Total allocated: %zu bytes\n", g_total_allocated);
}

static void print_error_details(MisskeyClient* client, MisskeyError err) {
    printf("Error: %s", misskey_error_str(err));
    long http_code = 0;
    char* error_detail = NULL;
    misskey_client_get_last_error(client, &http_code, &error_detail);
    if (http_code > 0) {
        printf(" (HTTP %ld)", http_code);
    }
    printf("\n");
    if (error_detail && error_detail[0]) {
        printf("Detail: %s\n", error_detail);
    }
}

#define MAX_API_COUNT 20
static const char* g_api_names[MAX_API_COUNT];
static int g_api_results[MAX_API_COUNT];
static int g_api_count = 0;

static void api_call_start(const char* name) {
    if (g_api_count < MAX_API_COUNT) {
        g_api_names[g_api_count] = name;
        g_api_results[g_api_count] = 0;
    }
}

static void api_call_end(int success) {
    if (g_api_count < MAX_API_COUNT) {
        g_api_results[g_api_count] = success ? 1 : 0;
        g_api_count++;
    }
}

static void print_api_summary(void) {
    int success = 0, failed = 0;
    for (int i = 0; i < g_api_count; i++) {
        if (g_api_results[i]) success++;
        else failed++;
    }
    
    printf("\n=== API Summary ===\n");
    printf("Total:  %d\n", g_api_count);
    printf("Success: %d\n", success);
    printf("Failed:  %d\n", failed);
    
    if (failed > 0) {
        printf("\nFailed APIs:");
        for (int i = 0; i < g_api_count; i++) {
            if (!g_api_results[i]) {
                printf(" %s", g_api_names[i]);
            }
        }
        printf("\n");
    }
}

int example_meta(MisskeyClient* client) {
    printf("\n=== Get Server Meta ===\n");
    char* resp = NULL;
    MisskeyError err = misskey_meta(client, &resp);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    print_json_parsed(resp);
    misskey_free_string(client, resp);
    return 0;
}

int example_timeline(MisskeyClient* client, int limit, int local) {
    printf("\n=== Get %sTimeline (limit %d) ===\n", local ? "Local " : "Home ", limit);
    char* resp = NULL;
    MisskeyError err = misskey_notes_timeline(client, limit, local, &resp);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    print_json_parsed(resp);
    misskey_free_string(client, resp);
    return 0;
}

int example_post_note(MisskeyClient* client, const char* text) {
    printf("\n=== Post Note ===\n");
    printf("Text: %s\n", text);
    char* resp = NULL;
    MisskeyError err = misskey_notes_create(client, text, NULL, NULL, &resp);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    print_json_parsed(resp);
    misskey_free_string(client, resp);
    return 0;
}

int example_notifications(MisskeyClient* client, int limit) {
    printf("\n=== Get Notifications (limit %d) ===\n", limit);
    char* resp = NULL;
    MisskeyError err = misskey_i_notifications(client, limit, &resp);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    print_json_parsed(resp);
    misskey_free_string(client, resp);
    return 0;
}

int example_drive_files(MisskeyClient* client, int limit) {
    printf("\n=== Get Drive Files (limit %d) ===\n", limit);
    char* resp = NULL;
    MisskeyError err = misskey_drive_files(client, limit, 0, &resp);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    print_json_parsed(resp);
    misskey_free_string(client, resp);
    return 0;
}

int example_translate(MisskeyClient* client, const char* target_lang) {
    printf("\n=== Translate Note (create -> translate -> delete) ===\n");
    
    char* create_resp = NULL;
    MisskeyError err = misskey_notes_create(client, "Hello from Misskey C Client!", NULL, NULL, &create_resp);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    
    cJSON* create_root = cJSON_Parse(create_resp);
    cJSON* created_note = cJSON_GetObjectItem(create_root, "createdNote");
    cJSON* note_id_item = cJSON_GetObjectItem(created_note, "id");
    if (!note_id_item || !note_id_item->valuestring) {
        printf("Failed to get note ID from create response\n");
        cJSON_Delete(create_root);
        misskey_free_string(client, create_resp);
        return 1;
    }
    const char* note_id = strdup(note_id_item->valuestring);
    printf("Created note ID: %s\n", note_id);
    cJSON_Delete(create_root);
    misskey_free_string(client, create_resp);
    
    printf("Target: %s\n", target_lang);
    char* resp = NULL;
    err = misskey_translate(client, note_id, target_lang, &resp);
    
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        char* del_resp = NULL;
        misskey_notes_delete(client, note_id, &del_resp);
        if (del_resp) misskey_free_string(client, del_resp);
        free((void*)note_id);
        return 1;
    }
    
    printf("Translated result:\n");
    print_json_parsed(resp);
    misskey_free_string(client, resp);
    
    char* delete_resp = NULL;
    err = misskey_notes_delete(client, note_id, &delete_resp);
    if (err == MISSKEY_OK) {
        printf("Note deleted: %s\n", note_id);
        if (delete_resp) misskey_free_string(client, delete_resp);
    } else {
        printf("Warning: Failed to delete note %s\n", note_id);
        print_error_details(client, err);
    }
    free((void*)note_id);
    
    return 0;
}

int example_drive_folders(MisskeyClient* client, int limit) {
    printf("\n=== Get Drive Folders (limit %d) ===\n", limit);
    char* resp = NULL;
    MisskeyError err = misskey_drive_folders(client, limit, NULL, &resp);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    print_json_parsed(resp);
    misskey_free_string(client, resp);
    return 0;
}

int example_notes(MisskeyClient* client) {
    printf("\n=== Search Notes ===\n");
    char* resp = NULL;
    MisskeyError err = misskey_notes(client, NULL, NULL, NULL, NULL, 5, 0, NULL, 0, 0, 0, 0, NULL, NULL, &resp);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    print_json_parsed(resp);
    misskey_free_string(client, resp);
    return 0;
}

int example_notes_show(MisskeyClient* client) {
    printf("\n=== Get Notes (create 3 -> show -> delete) ===\n");
    const char* note_ids[3] = {NULL, NULL, NULL};
    
    for (int i = 0; i < 3; i++) {
        char text[32];
        snprintf(text, sizeof(text), "Note for show test #%d", i + 1);
        char* create_resp = NULL;
        MisskeyError err = misskey_notes_create(client, text, NULL, NULL, &create_resp);
        if (err != MISSKEY_OK) {
            print_error_details(client, err);
            for (int j = 0; j < i; j++) {
                if (note_ids[j]) {
                    char* del_resp = NULL;
                    misskey_notes_delete(client, note_ids[j], &del_resp);
                    if (del_resp) misskey_free_string(client, del_resp);
                }
            }
            return 1;
        }
        
        cJSON* root = cJSON_Parse(create_resp);
        cJSON* created_note = cJSON_GetObjectItem(root, "createdNote");
        cJSON* note_id_item = cJSON_GetObjectItem(created_note, "id");
        if (note_id_item && note_id_item->valuestring) {
            note_ids[i] = strdup(note_id_item->valuestring);
            printf("Created note %d: %s\n", i + 1, note_ids[i]);
        }
        cJSON_Delete(root);
        misskey_free_string(client, create_resp);
    }
    
    for (int i = 0; i < 3; i++) {
        printf("\n--- Get Note %d ---", i + 1);
        char* resp = NULL;
        MisskeyError err = misskey_notes_show(client, note_ids[i], &resp);
        if (err != MISSKEY_OK) {
            printf(" (failed)\n");
            print_error_details(client, err);
        } else {
            printf("\n");
            print_json_parsed(resp);
            misskey_free_string(client, resp);
        }
    }
    
    for (int i = 0; i < 3; i++) {
        if (note_ids[i]) {
            char* del_resp = NULL;
            misskey_notes_delete(client, note_ids[i], &del_resp);
            if (del_resp) misskey_free_string(client, del_resp);
            printf("Deleted note %d: %s\n", i + 1, note_ids[i]);
            free((void*)note_ids[i]);
        }
    }
    return 0;
}

int example_clips_list(MisskeyClient* client) {
    printf("\n=== List Clips ===\n");
    char* resp = NULL;
    MisskeyError err = misskey_clips_list(client, &resp);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    print_json_parsed(resp);
    misskey_free_string(client, resp);
    return 0;
}

int example_clips_show(MisskeyClient* client) {
    printf("\n=== Get Clip (create -> show -> delete) ===\n");
    
    char* create_resp = NULL;
    MisskeyError err = misskey_clips_create(client, "Test Clip for Show", "Auto-generated test clip", 1, &create_resp);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    
    cJSON* root = cJSON_Parse(create_resp);
    cJSON* clip_id_item = cJSON_GetObjectItem(root, "id");
    if (!clip_id_item || !clip_id_item->valuestring) {
        printf("Failed to get clip ID from create response\n");
        cJSON_Delete(root);
        misskey_free_string(client, create_resp);
        return 1;
    }
    const char* clip_id = strdup(clip_id_item->valuestring);
    printf("Created clip: %s\n", clip_id);
    cJSON_Delete(root);
    misskey_free_string(client, create_resp);
    
    char* resp = NULL;
    err = misskey_clips_show(client, clip_id, &resp);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        free((void*)clip_id);
        return 1;
    }
    
    printf("Clip details:\n");
    print_json_parsed(resp);
    misskey_free_string(client, resp);
    
    char* del_resp = NULL;
    err = misskey_clips_delete(client, clip_id, &del_resp);
    if (err == MISSKEY_OK) {
        printf("Clip deleted: %s\n", clip_id);
        if (del_resp) misskey_free_string(client, del_resp);
    } else {
        printf("Warning: Failed to delete clip %s\n", clip_id);
        print_error_details(client, err);
    }
    free((void*)clip_id);
    
    return 0;
}

int example_clips_create(MisskeyClient* client, const char* name) {
    printf("\n=== Create Clip (name: %s) ===\n", name);
    char* resp = NULL;
    MisskeyError err = misskey_clips_create(client, name, "Test clip description", 1, &resp);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    print_json_parsed(resp);
    misskey_free_string(client, resp);
    return 0;
}

int example_clips_notes(MisskeyClient* client) {
    printf("\n=== Get Clip Notes (create clip -> add 5 notes -> get notes -> delete) ===\n");
    
    char* create_resp = NULL;
    MisskeyError err = misskey_clips_create(client, "Notes Test Clip", "Clip for testing notes API", 1, &create_resp);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    
    cJSON* root = cJSON_Parse(create_resp);
    cJSON* clip_id_item = cJSON_GetObjectItem(root, "id");
    if (!clip_id_item || !clip_id_item->valuestring) {
        printf("Failed to get clip ID\n");
        cJSON_Delete(root);
        misskey_free_string(client, create_resp);
        return 1;
    }
    const char* clip_id = strdup(clip_id_item->valuestring);
    printf("Created clip: %s\n", clip_id);
    cJSON_Delete(root);
    misskey_free_string(client, create_resp);
    
    const char* note_ids[5] = {NULL};
    for (int i = 0; i < 5; i++) {
        char text[32];
        snprintf(text, sizeof(text), "Note for clip test #%d", i + 1);
        char* note_resp = NULL;
        err = misskey_notes_create(client, text, NULL, NULL, &note_resp);
        if (err == MISSKEY_OK) {
            cJSON* note_root = cJSON_Parse(note_resp);
            cJSON* created_note = cJSON_GetObjectItem(note_root, "createdNote");
            cJSON* note_id_item = cJSON_GetObjectItem(created_note, "id");
            if (note_id_item && note_id_item->valuestring) {
                note_ids[i] = strdup(note_id_item->valuestring);
                printf("Created note %d: %s\n", i + 1, note_ids[i]);
                
                char* add_resp = NULL;
                misskey_clips_add_note(client, clip_id, note_ids[i], &add_resp);
                if (add_resp) misskey_free_string(client, add_resp);
            }
            cJSON_Delete(note_root);
            misskey_free_string(client, note_resp);
        }
    }
    
    printf("\n--- Get Clip Notes ---\n");
    char* resp = NULL;
    err = misskey_clips_notes(client, clip_id, 10, &resp);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
    } else {
        print_json_parsed(resp);
        misskey_free_string(client, resp);
    }
    
    for (int i = 0; i < 5; i++) {
        if (note_ids[i]) {
            char* del_note_resp = NULL;
            misskey_notes_delete(client, note_ids[i], &del_note_resp);
            if (del_note_resp) misskey_free_string(client, del_note_resp);
            printf("Deleted note %d: %s\n", i + 1, note_ids[i]);
            free((void*)note_ids[i]);
        }
    }
    
    char* del_resp = NULL;
    err = misskey_clips_delete(client, clip_id, &del_resp);
    if (err == MISSKEY_OK) {
        printf("Clip deleted: %s\n", clip_id);
        if (del_resp) misskey_free_string(client, del_resp);
    }
    free((void*)clip_id);
    
    return 0;
}

int main(int argc, char* argv[]) {
    const char* host = argc > 1 ? argv[1] : "misskey.io";
    const char* token = argc > 2 ? argv[2] : NULL;
    int use_custom_allocator = argc > 3 && strcmp(argv[3], "--track-alloc") == 0;
    
    printf("===========================================\n");
    printf("  Misskey C Client Example (libcurl)\n");
    printf("===========================================\n");
    printf("Host: %s\n", host);
    printf("Allocator: %s\n", use_custom_allocator ? "Tracking (custom)" : "Default");
    
    MisskeyClient* client = NULL;
    
    if (use_custom_allocator) {
        MisskeyAllocator custom_alloc = {
            .malloc_fn = tracking_malloc,
            .realloc_fn = tracking_realloc,
            .free_fn = tracking_free,
            .user_data = NULL
        };
        client = misskey_client_new_with_allocator(host, &custom_alloc);
    } else {
        client = misskey_client_new(host);
    }
    
    if (!client) {
        fprintf(stderr, "Failed to create client\n");
        return 1;
    }
    
    if (token) {
        misskey_client_set_token(client, token);
        printf("Token: [set - %zu chars]\n", strlen(token));
        
        misskey_request_set_debug(client, 1);
        printf("\n--- Debug mode enabled ---\n");
        
        api_call_start("notes/timeline");  api_call_end(example_timeline(client, 3, 1) == 0);
        api_call_start("i/notifications");  api_call_end(example_notifications(client, 5) == 0);
        api_call_start("drive/files");  api_call_end(example_drive_files(client, 5) == 0);
        api_call_start("drive/folders");  api_call_end(example_drive_folders(client, 5) == 0);
        api_call_start("notes/translate");  api_call_end(example_translate(client, "ja") == 0);
        api_call_start("notes");  api_call_end(example_notes(client) == 0);
        api_call_start("notes/show");  api_call_end(example_notes_show(client) == 0);
        api_call_start("clips/list");  api_call_end(example_clips_list(client) == 0);
        api_call_start("clips/show");  api_call_end(example_clips_show(client) == 0);
        api_call_start("clips/create");  api_call_end(example_clips_create(client, "Test Clip") == 0);
        api_call_start("clips/notes");  api_call_end(example_clips_notes(client) == 0);
    } else {
        printf("Token: [not set - some APIs will fail]\n");
    }
    
    printf("\n--- Starting API calls ---\n");
    
    api_call_start("meta");  api_call_end(example_meta(client) == 0);
    
    misskey_client_free(client);
    
    print_api_summary();
    
    if (use_custom_allocator) {
        print_alloc_stats();
    }
    
    printf("\n=== Done ===\n");
    return 0;
}
