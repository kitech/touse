#include <stdio.h>
#include <string.h>
#include "misskey_client.h"

#define ITERATIONS 100

int main() {
    printf("Testing memory leaks with %d iterations...\n", ITERATIONS);
    
    MisskeyClient* client = misskey_client_new("localhost:3000");
    if (!client) {
        printf("Failed to create client\n");
        return 1;
    }
    
    misskey_client_set_token(client, "test_token_12345");
    
    for (int i = 0; i < ITERATIONS; i++) {
        char* resp = NULL;
        
        int err = misskey_meta(client, &resp);
        if (err == 0 && resp) {
            misskey_free_string(client, resp);
        }
        
        err = misskey_drive(client, &resp);
        if (err == 0 && resp) {
            misskey_free_string(client, resp);
        }
        
        err = misskey_i_notifications(client, 5, &resp);
        if (err == 0 && resp) {
            misskey_free_string(client, resp);
        }
        
        if (i % 10 == 0) {
            printf("Progress: %d/%d\n", i, ITERATIONS);
        }
    }
    
    misskey_client_free(client);
    
    printf("Done! Ran %d iterations.\n", ITERATIONS);
    return 0;
}
