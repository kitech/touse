#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <limits.h>
#include <stdint.h>
#include "misskey_client.h"

void test_empty_string() {
    printf("=== Test: Empty string ===\n");
    
    MisskeyClient* client = misskey_client_new("");
    if (!client) {
        printf("Empty host: REJECTED (OK)\n");
    } else {
        misskey_client_free(client);
        printf("Empty host: ACCEPTED\n");
    }
    
    client = misskey_client_new("localhost:3000");
    if (client) {
        misskey_client_set_token(client, "");
        
        char* resp = NULL;
        int err = misskey_notes_create(client, "", NULL, NULL, &resp);
        printf("notes_create with empty text = %d\n", err);
        if (resp) misskey_free_string(client, resp);
        
        err = misskey_drive_files_delete(client, "", &resp);
        printf("drive_files_delete with empty id = %d\n", err);
        if (resp) misskey_free_string(client, resp);
        
        misskey_client_free(client);
    }
    
    printf("PASS\n\n");
}

void test_negative_values() {
    printf("=== Test: Negative values ===\n");
    
    MisskeyClient* client = misskey_client_new("localhost:3000");
    misskey_client_set_token(client, "test");
    
    char* resp = NULL;
    int err;
    
    err = misskey_notes_timeline(client, -1, 0, &resp);
    printf("notes_timeline(limit=-1) = %d\n", err);
    if (resp) { misskey_free_string(client, resp); resp = NULL; }
    
    err = misskey_i_notifications(client, -100, &resp);
    printf("i_notifications(limit=-100) = %d\n", err);
    if (resp) { misskey_free_string(client, resp); resp = NULL; }
    
    err = misskey_drive_files(client, -999, 0, &resp);
    printf("drive_files(limit=-999) = %d\n", err);
    if (resp) { misskey_free_string(client, resp); resp = NULL; }
    
    misskey_client_free(client);
    printf("PASS\n\n");
}

void test_zero_values() {
    printf("=== Test: Zero values ===\n");
    
    MisskeyClient* client = misskey_client_new("localhost:3000");
    misskey_client_set_token(client, "test");
    
    char* resp = NULL;
    int err;
    
    err = misskey_notes_timeline(client, 0, 0, &resp);
    printf("notes_timeline(limit=0) = %d\n", err);
    if (resp) { misskey_free_string(client, resp); resp = NULL; }
    
    err = misskey_i_notifications(client, 0, &resp);
    printf("i_notifications(limit=0) = %d\n", err);
    if (resp) { misskey_free_string(client, resp); resp = NULL; }
    
    misskey_client_free(client);
    printf("PASS\n\n");
}

void test_large_limit() {
    printf("=== Test: Large limit values ===\n");
    
    MisskeyClient* client = misskey_client_new("localhost:3000");
    misskey_client_set_token(client, "test");
    
    char* resp = NULL;
    int err;
    
    err = misskey_notes_timeline(client, 100000, 0, &resp);
    printf("notes_timeline(limit=100000) = %d\n", err);
    if (resp) { misskey_free_string(client, resp); resp = NULL; }
    
    err = misskey_i_notifications(client, 999999, &resp);
    printf("i_notifications(limit=999999) = %d\n", err);
    if (resp) { misskey_free_string(client, resp); resp = NULL; }
    
    misskey_client_free(client);
    printf("PASS\n\n");
}

void test_special_characters() {
    printf("=== Test: Special characters ===\n");
    
    MisskeyClient* client = misskey_client_new("localhost:3000");
    misskey_client_set_token(client, "test");
    
    char* resp = NULL;
    int err;
    
    const char* special_texts[] = {
        "Test with 'single quotes'",
        "Test with \"double quotes\"",
        "Test with\nnewlines",
        "Test with\ttabs",
        "Test with emoji 🎉",
        "Test with 日本語",
        "Test with 中文",
        "Test with <script>alert('xss')</script>",
        "SQL injection: '; DROP TABLE users; --",
        "Test with\r\ncarriage\r\nreturns",
        NULL
    };
    
    for (int i = 0; special_texts[i] != NULL; i++) {
        err = misskey_notes_create(client, special_texts[i], NULL, NULL, &resp);
        printf("notes_create(text[%d]) = %d\n", i, err);
        if (resp) { misskey_free_string(client, resp); resp = NULL; }
    }
    
    misskey_client_free(client);
    printf("PASS\n\n");
}

void test_very_long_strings() {
    printf("=== Test: Very long strings ===\n");
    
    MisskeyClient* client = misskey_client_new("localhost:3000");
    misskey_client_set_token(client, "test");
    
    size_t sizes[] = { 1000, 10000, 100000 };
    
    for (size_t i = 0; i < sizeof(sizes) / sizeof(sizes[0]); i++) {
        char* long_text = malloc(sizes[i] + 1);
        memset(long_text, 'A', sizes[i]);
        long_text[sizes[i]] = '\0';
        
        char* resp = NULL;
        int err = misskey_notes_create(client, long_text, NULL, NULL, &resp);
        printf("notes_create(text_len=%zu) = %d\n", sizes[i], err);
        if (resp) { misskey_free_string(client, resp); resp = NULL; }
        
        free(long_text);
    }
    
    misskey_client_free(client);
    printf("PASS\n\n");
}

void test_invalid_host() {
    printf("=== Test: Invalid hosts ===\n");
    
    const char* invalid_hosts[] = {
        "invalid..host",
        "host with spaces",
        "host\twith\ttabs",
        "host\nwith\nnewlines",
        "://invalid",
        "host:abc",
        "host:99999",
        "host:-1",
        "a",  // single char
        "localhost",  // no port
        NULL
    };
    
    for (int i = 0; invalid_hosts[i] != NULL; i++) {
        MisskeyClient* client = misskey_client_new(invalid_hosts[i]);
        printf("host[%d] = '%s': %s\n", i, invalid_hosts[i], 
               client ? "accepted" : "rejected");
        if (client) {
            misskey_client_free(client);
        }
    }
    
    printf("PASS\n\n");
}

void test_malformed_urls() {
    printf("=== Test: Malformed URLs ===\n");
    
    MisskeyClient* client = misskey_client_new("localhost:3000");
    misskey_client_set_token(client, "test");
    
    char* resp = NULL;
    
    int err = misskey_drive_files_find(client, "not_a_valid_hash_but_should_work", &resp);
    printf("drive_files_find(invalid_hash) = %d\n", err);
    if (resp) { misskey_free_string(client, resp); resp = NULL; }
    
    err = misskey_drive_files_upload_from_url(client, "not-a-url", NULL, 0, NULL, &resp);
    printf("drive_files_upload_from_url(invalid_url) = %d\n", err);
    if (resp) { misskey_free_string(client, resp); resp = NULL; }
    
    err = misskey_translate(client, "test", "invalid_lang", "ja", &resp);
    printf("translate(invalid_lang) = %d\n", err);
    if (resp) { misskey_free_string(client, resp); resp = NULL; }
    
    misskey_client_free(client);
    printf("PASS\n\n");
}


void test_timeout_values() {
    printf("=== Test: Timeout values ===\n");
    
    MisskeyClient* client = misskey_client_new("localhost:3000");
    
    misskey_client_set_timeout(client, 0);
    printf("timeout = 0: OK\n");
    
    misskey_client_set_timeout(client, -1);
    printf("timeout = -1: OK\n");
    
    misskey_client_set_timeout(client, 999999);
    printf("timeout = 999999: OK\n");
    
    misskey_client_set_timeout(client, INT32_MAX);
    printf("timeout = INT32_MAX: OK\n");
    
    misskey_client_free(client);
    printf("PASS\n\n");
}

void test_debug_toggle() {
    printf("=== Test: Debug toggle ===\n");
    
    MisskeyClient* client = misskey_client_new("localhost:3000");
    
    misskey_request_set_debug(client, 0);
    printf("debug = 0: OK\n");
    
    misskey_request_set_debug(client, 1);
    printf("debug = 1: OK\n");
    
    misskey_request_set_debug(client, 999);
    printf("debug = 999: OK\n");
    
    misskey_request_set_debug(client, -1);
    printf("debug = -1: OK\n");
    
    misskey_client_free(client);
    printf("PASS\n\n");
}

int main() {
    printf("===========================================\n");
    printf("  Fuzz Tests - C API\n");
    printf("===========================================\n\n");
    
    test_empty_string();
    test_negative_values();
    test_zero_values();
    test_large_limit();
    test_special_characters();
    test_very_long_strings();
    test_invalid_host();
    test_malformed_urls();
    test_timeout_values();
    test_debug_toggle();
    
    printf("===========================================\n");
    printf("  All fuzz tests passed!\n");
    printf("===========================================\n");
    
    return 0;
}
