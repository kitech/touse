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

int example_meta(MisskeyClient* client) {
    printf("\n=== Get Server Meta ===\n");
    char* resp = NULL;
    MisskeyError err = misskey_meta(client, &resp);
    if (err != MISSKEY_OK) {
        printf("Error: %s\n", misskey_error_str(err));
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
        printf("Error: %s\n", misskey_error_str(err));
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
        printf("Error: %s\n", misskey_error_str(err));
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
        printf("Error: %s\n", misskey_error_str(err));
        return 1;
    }
    print_json_parsed(resp);
    misskey_free_string(client, resp);
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
    } else {
        printf("Token: [not set - some APIs will fail]\n");
    }
    
    printf("\n--- Starting API calls ---\n");
    
    example_meta(client);
    
    if (token) {
        example_timeline(client, 3, 1);
        example_notifications(client, 5);
    }
    
    misskey_client_free(client);
    
    if (use_custom_allocator) {
        print_alloc_stats();
    }
    
    printf("\n=== Done ===\n");
    return 0;
}
