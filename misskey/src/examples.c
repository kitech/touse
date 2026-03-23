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

static void print_struct_note(const MisskeyNote* note) {
    printf("Note[id=%s, text=%.50s, user=@%s]\n", 
           note->id, note->text, note->user.username);
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
    MisskeyMeta meta;
    misskey_meta_init(&meta);
    MisskeyError err = misskey_meta(client, &meta);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    printf("Server name: %s\n", meta.name);
    printf("Version: %s\n", meta.version);
    printf("Max note length: %d\n", (int)meta.max_note_text_length);
    return 0;
}

int example_meta_raw(MisskeyClient* client) {
    printf("\n=== Get Server Meta (raw JSON) ===\n");
    char* resp = NULL;
    MisskeyError err = misskey_meta_raw(client, &resp);
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
    MisskeyNote* notes = NULL;
    int note_count = 0;
    MisskeyError err = misskey_notes_timeline(client, limit, local, &notes, &note_count);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    printf("Got %d notes:\n", note_count);
    for (int i = 0; i < note_count; i++) {
        print_struct_note(&notes[i]);
    }
    misskey_free_notes(client, notes, note_count);
    return 0;
}

int example_timeline_raw(MisskeyClient* client, int limit, int local) {
    printf("\n=== Get %sTimeline (limit %d, raw JSON) ===\n", local ? "Local " : "Home ", limit);
    char* resp = NULL;
    MisskeyError err = misskey_notes_timeline_raw(client, limit, local, &resp);
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
    MisskeyNote note;
    misskey_note_init(&note);
    MisskeyError err = misskey_notes_create(client, text, NULL, NULL, &note);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    printf("Created note ID: %s\n", note.id);
    printf("User: @%s\n", note.user.username);
    return 0;
}

int example_notifications(MisskeyClient* client, int limit) {
    printf("\n=== Get Notifications (limit %d) ===\n", limit);
    MisskeyNotification* notifications = NULL;
    int notif_count = 0;
    MisskeyError err = misskey_i_notifications(client, limit, &notifications, &notif_count);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    printf("Got %d notifications:\n", notif_count);
    for (int i = 0; i < notif_count; i++) {
        printf("  [%d] type=%s, from=%s\n", i + 1, 
               notifications[i].type, notifications[i].user_name);
    }
    misskey_free_notifications(client, notifications, notif_count);
    return 0;
}

int example_drive_files(MisskeyClient* client, int limit) {
    printf("\n=== Get Drive Files (limit %d) ===\n", limit);
    MisskeyDriveFile* files = NULL;
    int file_count = 0;
    MisskeyError err = misskey_drive_files(client, limit, NULL, &files, &file_count);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    printf("Got %d files:\n", file_count);
    for (int i = 0; i < file_count; i++) {
        printf("  [%d] %s - %s (%zu bytes)\n", i + 1, 
               files[i].id, files[i].name, files[i].size);
    }
    misskey_free_drive_files(client, files, file_count);
    return 0;
}

int example_translate(MisskeyClient* client, const char* target_lang) {
    printf("\n=== Translate Note (create -> translate -> delete) ===\n");
    
    MisskeyNote note;
    misskey_note_init(&note);
    MisskeyError err = misskey_notes_create(client, "Hello from Misskey C Client!", NULL, NULL, &note);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    printf("Created note ID: %s\n", note.id);
    
    printf("Translating to: %s\n", target_lang);
    MisskeyTranslateResult result;
    misskey_translate_result_init(&result);
    err = misskey_translate(client, note.id, target_lang, &result);
    
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        char deleted_id[32];
        misskey_notes_delete(client, note.id, deleted_id);
        return 1;
    }
    
    printf("Source lang: %s -> Target lang: %s\n", result.source_lang, result.target_lang);
    printf("Translated: %s\n", result.text);
    
    char deleted_id[32];
    err = misskey_notes_delete(client, note.id, deleted_id);
    if (err == MISSKEY_OK) {
        printf("Note deleted: %s\n", deleted_id);
    } else {
        printf("Warning: Failed to delete note %s\n", note.id);
    }
    
    return 0;
}

int example_drive_folders(MisskeyClient* client, int limit) {
    printf("\n=== Get Drive Folders (limit %d) ===\n", limit);
    MisskeyDriveFolder* folders = NULL;
    int folder_count = 0;
    MisskeyError err = misskey_drive_folders(client, limit, NULL, &folders, &folder_count);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    printf("Got %d folders:\n", folder_count);
    for (int i = 0; i < folder_count; i++) {
        printf("  [%d] %s - %s\n", i + 1, folders[i].id, folders[i].name);
    }
    misskey_free_drive_folders(client, folders, folder_count);
    return 0;
}

int example_notes(MisskeyClient* client) {
    printf("\n=== Search Notes ===\n");
    MisskeyNote* notes = NULL;
    int note_count = 0;
    MisskeyError err = misskey_notes(client, NULL, NULL, NULL, NULL, 5, 0, NULL, 0, 0, 0, 0, NULL, NULL, &notes, &note_count);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    printf("Got %d notes:\n", note_count);
    for (int i = 0; i < note_count; i++) {
        print_struct_note(&notes[i]);
    }
    misskey_free_notes(client, notes, note_count);
    return 0;
}

int example_notes_show(MisskeyClient* client) {
    printf("\n=== Get Notes (create 3 -> show -> delete) ===\n");
    const char* note_ids[3] = {NULL, NULL, NULL};
    
    for (int i = 0; i < 3; i++) {
        char text[32];
        snprintf(text, sizeof(text), "Note for show test #%d", i + 1);
        MisskeyNote note;
        misskey_note_init(&note);
        MisskeyError err = misskey_notes_create(client, text, NULL, NULL, &note);
        if (err != MISSKEY_OK) {
            print_error_details(client, err);
            for (int j = 0; j < i; j++) {
                if (note_ids[j]) {
                    char deleted_id[32];
                    misskey_notes_delete(client, note_ids[j], deleted_id);
                }
            }
            return 1;
        }
        note_ids[i] = strdup(note.id);
        printf("Created note %d: %s\n", i + 1, note_ids[i]);
    }
    
    for (int i = 0; i < 3; i++) {
        printf("\n--- Get Note %d ---\n", i + 1);
        MisskeyNote note;
        misskey_note_init(&note);
        MisskeyError err = misskey_notes_show(client, note_ids[i], &note);
        if (err != MISSKEY_OK) {
            print_error_details(client, err);
        } else {
            print_struct_note(&note);
        }
    }
    
    for (int i = 0; i < 3; i++) {
        if (note_ids[i]) {
            char deleted_id[32];
            misskey_notes_delete(client, note_ids[i], deleted_id);
            printf("Deleted note %d: %s\n", i + 1, note_ids[i]);
            free((void*)note_ids[i]);
        }
    }
    return 0;
}

int example_clips_list(MisskeyClient* client) {
    printf("\n=== List Clips ===\n");
    MisskeyClip* clips = NULL;
    int clip_count = 0;
    MisskeyError err = misskey_clips_list(client, &clips, &clip_count);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    printf("Got %d clips:\n", clip_count);
    for (int i = 0; i < clip_count; i++) {
        printf("  [%d] %s - %s (public: %s)\n", i + 1, 
               clips[i].id, clips[i].name, clips[i].is_public ? "yes" : "no");
    }
    misskey_free_clips(client, clips, clip_count);
    return 0;
}

int example_clips_show(MisskeyClient* client) {
    printf("\n=== Get Clip (create -> show -> delete) ===\n");
    
    MisskeyClip clip;
    misskey_clip_init(&clip);
    MisskeyError err = misskey_clips_create(client, "Test Clip for Show", "Auto-generated test clip", 1, &clip);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    printf("Created clip: %s\n", clip.id);
    const char* clip_id = strdup(clip.id);
    
    MisskeyClip show_clip;
    misskey_clip_init(&show_clip);
    err = misskey_clips_show(client, clip_id, &show_clip);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        free((void*)clip_id);
        return 1;
    }
    
    printf("Clip details: name=%s, description=%s\n", show_clip.name, show_clip.description);
    
    char deleted_id[32];
    err = misskey_clips_delete(client, clip_id, deleted_id);
    if (err == MISSKEY_OK) {
        printf("Clip deleted: %s\n", deleted_id);
    } else {
        printf("Warning: Failed to delete clip %s\n", clip_id);
        print_error_details(client, err);
    }
    free((void*)clip_id);
    
    return 0;
}

int example_clips_create(MisskeyClient* client, const char* name) {
    printf("\n=== Create Clip (name: %s) ===\n", name);
    MisskeyClip clip;
    misskey_clip_init(&clip);
    MisskeyError err = misskey_clips_create(client, name, "Test clip description", 1, &clip);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    printf("Created clip: %s - %s\n", clip.id, clip.name);
    return 0;
}

int example_clips_notes(MisskeyClient* client) {
    printf("\n=== Get Clip Notes (create clip -> add 5 notes -> get notes -> delete) ===\n");
    
    MisskeyClip clip;
    misskey_clip_init(&clip);
    MisskeyError err = misskey_clips_create(client, "Notes Test Clip", "Clip for testing notes API", 1, &clip);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    printf("Created clip: %s\n", clip.id);
    const char* clip_id = strdup(clip.id);
    
    const char* note_ids[5] = {NULL};
    for (int i = 0; i < 5; i++) {
        char text[32];
        snprintf(text, sizeof(text), "Note for clip test #%d", i + 1);
        MisskeyNote note;
        misskey_note_init(&note);
        err = misskey_notes_create(client, text, NULL, NULL, &note);
        if (err == MISSKEY_OK) {
            note_ids[i] = strdup(note.id);
            printf("Created note %d: %s\n", i + 1, note_ids[i]);
            
            err = misskey_clips_add_note(client, clip_id, note_ids[i]);
            if (err != MISSKEY_OK) {
                printf("Warning: Failed to add note to clip\n");
            }
        }
    }
    
    printf("\n--- Get Clip Notes ---\n");
    MisskeyNote* notes = NULL;
    int note_count = 0;
    err = misskey_clips_notes(client, clip_id, 10, &notes, &note_count);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
    } else {
        printf("Got %d notes in clip:\n", note_count);
        for (int i = 0; i < note_count; i++) {
            print_struct_note(&notes[i]);
        }
        misskey_free_notes(client, notes, note_count);
    }
    
    for (int i = 0; i < 5; i++) {
        if (note_ids[i]) {
            char deleted_id[32];
            misskey_notes_delete(client, note_ids[i], deleted_id);
            printf("Deleted note %d: %s\n", i + 1, note_ids[i]);
            free((void*)note_ids[i]);
        }
    }
    
    char deleted_id[32];
    err = misskey_clips_delete(client, clip_id, deleted_id);
    if (err == MISSKEY_OK) {
        printf("Clip deleted: %s\n", deleted_id);
    }
    free((void*)clip_id);
    
    return 0;
}

int example_users_show(MisskeyClient* client) {
    printf("\n=== Get User Profile ===\n");
    MisskeyUser user;
    misskey_user_init(&user);
    MisskeyError err = misskey_users_show(client, NULL, "syuilo", NULL, 1, &user);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    
    char full_username[256];
    misskey_user_get_full_username(&user, full_username, sizeof(full_username));
    
    printf("User ID: %s\n", user.id);
    printf("Full username: %s\n", full_username);
    printf("Name: %s\n", user.name);
    printf("Host: %s\n", user.host);
    printf("Avatar: %s\n", user.avatar_url);
    printf("Banner: %s\n", user.banner_url);
    printf("Description: %.100s...\n", user.description);
    printf("Followers: %d\n", user.followers_count);
    printf("Following: %d\n", user.following_count);
    printf("Notes: %d\n", user.notes_count);
    printf("Bot: %s, Cat: %s, Locked: %s\n",
           user.is_bot ? "yes" : "no",
           user.is_cat ? "yes" : "no",
           user.is_locked ? "yes" : "no");
    return 0;
}

int example_local_timeline_full(MisskeyClient* client) {
    printf("\n=== Get Local Timeline (full options) ===\n");
    MisskeyTimelineOptions opts = {
        .limit = 5,
        .with_files = 0,
        .with_renotes = 1,
        .with_replies = 0,
        .allow_partial = 0,
        .since_id = NULL,
        .until_id = NULL,
        .since_date = 0,
        .until_date = 0
    };
    MisskeyNote* notes = NULL;
    int note_count = 0;
    MisskeyError err = misskey_notes_local_timeline_full(client, &opts, &notes, &note_count);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    printf("Got %d notes:\n", note_count);
    for (int i = 0; i < note_count; i++) {
        printf("  [%d] %.50s (renote=%d, reply=%d, files=%d)\n",
               i + 1, notes[i].text, notes[i].is_renote, notes[i].is_reply, notes[i].files_count);
    }
    misskey_free_notes(client, notes, note_count);
    return 0;
}

int example_global_timeline(MisskeyClient* client) {
    printf("\n=== Get Global Timeline ===\n");
    MisskeyNote* notes = NULL;
    int note_count = 0;
    MisskeyError err = misskey_notes_global_timeline(client, 5, &notes, &note_count);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    printf("Got %d notes:\n", note_count);
    for (int i = 0; i < note_count; i++) {
        print_struct_note(&notes[i]);
    }
    misskey_free_notes(client, notes, note_count);
    return 0;
}

int example_global_timeline_full(MisskeyClient* client) {
    printf("\n=== Get Global Timeline (full options) ===\n");
    MisskeyTimelineOptions opts = {
        .limit = 5,
        .with_files = 1,
        .with_renotes = 1,
        .with_replies = 0,
        .allow_partial = 0,
        .since_id = NULL,
        .until_id = NULL,
        .since_date = 0,
        .until_date = 0
    };
    MisskeyNote* notes = NULL;
    int note_count = 0;
    MisskeyError err = misskey_notes_global_timeline_full(client, &opts, &notes, &note_count);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    printf("Got %d notes:\n", note_count);
    for (int i = 0; i < note_count; i++) {
        printf("  [%d] %.50s (renote=%d, files=%d)\n",
               i + 1, notes[i].text, notes[i].is_renote, notes[i].files_count);
    }
    misskey_free_notes(client, notes, note_count);
    return 0;
}

int example_notes_create_full(MisskeyClient* client) {
    printf("\n=== Create Note (full options) ===\n");
    MisskeyNote note;
    misskey_note_init(&note);
    MisskeyError err = misskey_notes_create_full(client, 
        "Hello from C client with full options!",
        NULL, NULL,
        NULL, 0,
        0, NULL, 0, NULL, 0, 0,
        &note);
    if (err != MISSKEY_OK) {
        print_error_details(client, err);
        return 1;
    }
    printf("Created note ID: %s\n", note.id);
    printf("Has files: %d\n", note.has_files);
    
    char deleted_id[32];
    err = misskey_notes_delete(client, note.id, deleted_id);
    if (err == MISSKEY_OK) {
        printf("Note deleted: %s\n", deleted_id);
    }
    return 0;
}

static void stream_callback(const char* type, const char* body, void* user_data) {
    (void)user_data;
    printf("[STREAM] type=%s, body=%.100s...\n", type, body);
}

int example_streaming(const char* host, const char* token) {
    printf("\n=== Streaming API Test ===\n");
    
    MisskeyStream* stream = misskey_stream_new(host, token);
    if (!stream) {
        printf("Failed to create stream\n");
        return 1;
    }
    
    misskey_stream_set_callback(stream, stream_callback, NULL);
    
    MisskeyError err = misskey_stream_connect(stream, MISSKEY_STREAM_CHANNEL_LOCAL_TIMELINE, "test-channel-1");
    if (err != MISSKEY_OK) {
        printf("Failed to connect to stream: %s\n", misskey_error_str(err));
        misskey_stream_free(stream);
        return 1;
    }
    printf("Connected to local timeline stream\n");
    
    printf("Polling for 2 seconds...\n");
    for (int i = 0; i < 4; i++) {
        misskey_stream_poll(stream, 500);
    }
    
    misskey_stream_disconnect(stream, "test-channel-1");
    misskey_stream_free(stream);
    printf("Stream closed\n");
    return 0;
}

static int example_reactions(MisskeyClient* client) {
    const char* test_note_id = "test_note_123";
    
    printf("\n--- Reactions API ---\n");
    
    MisskeyError err;
    
    // Create reaction
    printf("Creating reaction (note_id=%s, reaction=👍)...\n", test_note_id);
    err = misskey_notes_reactions_create(client, test_note_id, "👍");
    if (err != MISSKEY_OK) {
        printf("Failed to create reaction\n");
        print_error_details(client, err);
        return 1;
    }
    printf("Reaction created successfully\n");
    
    // Get reactions
    printf("Getting reactions for note_id=%s...\n", test_note_id);
    MisskeyReaction* reactions = NULL;
    int count = 0;
    err = misskey_notes_reactions(client, test_note_id, NULL, 10, &reactions, &count);
    if (err != MISSKEY_OK) {
        printf("Failed to get reactions\n");
        print_error_details(client, err);
        return 1;
    }
    printf("Got %d reactions:\n", count);
    for (int i = 0; i < count; i++) {
        printf("  [%d] type=%s, user=@%s\n", 
               i + 1, reactions[i].type, reactions[i].user.username);
    }
    misskey_free_reactions(client, reactions, count);
    
    // Delete reaction
    printf("Deleting reaction (note_id=%s)...\n", test_note_id);
    err = misskey_notes_reactions_delete(client, test_note_id);
    if (err != MISSKEY_OK) {
        printf("Failed to delete reaction\n");
        print_error_details(client, err);
        return 1;
    }
    printf("Reaction deleted successfully\n");
    
    return 0;
}

static int example_reactions_raw(MisskeyClient* client) {
    const char* test_note_id = "test_note_456";
    
    printf("\n--- Reactions API (raw) ---\n");
    
    // Create reaction (raw)
    printf("Creating reaction (raw)...\n");
    char* resp = NULL;
    MisskeyError err = misskey_notes_reactions_create_raw(client, test_note_id, "❤️", &resp);
    if (err != MISSKEY_OK) {
        printf("Failed to create reaction (raw)\n");
        print_error_details(client, err);
        return 1;
    }
    printf("Response: %s (empty = success)\n", resp ? resp : "(empty)");
    if (resp) misskey_free_string(client, resp);
    
    // Get reactions (raw)
    printf("Getting reactions (raw)...\n");
    err = misskey_notes_reactions_raw(client, test_note_id, NULL, 5, &resp);
    if (err != MISSKEY_OK) {
        printf("Failed to get reactions (raw)\n");
        print_error_details(client, err);
        return 1;
    }
    printf("Response:\n");
    print_json_parsed(resp);
    if (resp) misskey_free_string(client, resp);
    
    return 0;
}

int main(int argc, char* argv[]) {
    const char* host = argc > 1 ? argv[1] : "localhost:3000";
    const char* token = argc > 2 ? argv[2] : NULL;
    int use_custom_allocator = argc > 3 && strcmp(argv[3], "--track-alloc") == 0;
    
    printf("===========================================\n");
    printf("  Misskey C Client Example\n");
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
        misskey_request_set_debug(client, 0);
    } else {
        printf("Token: [not set - some APIs will fail]\n");
    }
    
    printf("\n--- Starting API calls (structured API) ---\n");
    
    api_call_start("meta");  api_call_end(example_meta(client) == 0);
    api_call_start("users/show");  api_call_end(example_users_show(client) == 0);
    
    if (token) {
        api_call_start("notes/timeline");  api_call_end(example_timeline(client, 3, 1) == 0);
        api_call_start("notes/local-timeline/full");  api_call_end(example_local_timeline_full(client) == 0);
        api_call_start("notes/global-timeline");  api_call_end(example_global_timeline(client) == 0);
        api_call_start("notes/global-timeline/full");  api_call_end(example_global_timeline_full(client) == 0);
        api_call_start("notes/create/full");  api_call_end(example_notes_create_full(client) == 0);
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
        api_call_start("notes/reactions");  api_call_end(example_reactions(client) == 0);
        api_call_start("notes/reactions (raw)");  api_call_end(example_reactions_raw(client) == 0);
        api_call_start("streaming");  api_call_end(example_streaming(host, token) == 0);
    }
    
    misskey_client_free(client);
    
    print_api_summary();
    
    if (use_custom_allocator) {
        print_alloc_stats();
    }
    
    printf("\n=== Done ===\n");
    return 0;
}
