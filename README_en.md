# Misskey C Client

A Misskey API client library based on libcurl with custom memory allocator support.

## Features

- Clean C API
- Custom memory allocator support
- Auto print curl debug commands
- Bearer Token authentication

## Project Structure

```
misskey-client/
├── Makefile
├── README.md
├── README_en.md        # This file
└── src/
    ├── misskey_client.h    # API header
    ├── misskey_client.c    # Core implementation
    ├── examples.c          # Usage examples
    └── cJSON/             # JSON parser library
        ├── cJSON.h
        └── cJSON.c
```

## Build

```bash
make
```

## Run

```bash
# Without token (public API only)
./misskey_example misskey.io

# With token
./misskey_example misskey.io YOUR_TOKEN

# With memory tracking
./misskey_example misskey.io YOUR_TOKEN --track-alloc

# Via proxy
proxychains ./misskey_example misskey.io YOUR_TOKEN
```

## API Reference

### Client Management

| Function | Description |
|----------|-------------|
| `misskey_client_new()` | Create client |
| `misskey_client_new_with_allocator()` | Create with custom allocator |
| `misskey_client_free()` | Free client |
| `misskey_client_set_token()` | Set access token |
| `misskey_client_set_timeout()` | Set timeout |
| `misskey_client_get_allocator()` | Get allocator |

### Basic API

| Function | Endpoint | Description |
|----------|----------|-------------|
| `misskey_request()` | Generic | Generic POST request |
| `misskey_meta()` | `/api/meta` | Get server info |
| `misskey_request_set_debug()` | - | Enable/disable curl debug |
| `misskey_request_print_curl()` | - | Print curl command |

### Notes API

| Function | Endpoint | Description |
|----------|----------|-------------|
| `misskey_notes_timeline()` | `/api/notes/timeline` | Get timeline |
| `misskey_notes_create()` | `/api/notes/create` | Post note |

### Account API

| Function | Endpoint | Description |
|----------|----------|-------------|
| `misskey_i_notifications()` | `/api/i/notifications` | Get notifications |

### Drive API - Files

| Function | Endpoint | Description |
|----------|----------|-------------|
| `misskey_drive_files()` | `/api/drive/files` | List files |
| `misskey_drive_files_create()` | `/api/drive/files/create` | Upload file |
| `misskey_drive_files_delete()` | `/api/drive/files/delete` | Delete file |
| `misskey_drive_files_update()` | `/api/drive/files/update` | Update file |
| `misskey_drive_files_find()` | `/api/drive/files/find` | Find file |

### Drive API - Folders

| Function | Endpoint | Description |
|----------|----------|-------------|
| `misskey_drive_folders()` | `/api/drive/folders` | List folders |
| `misskey_drive_folders_create()` | `/api/drive/folders/create` | Create folder |
| `misskey_drive_folders_delete()` | `/api/drive/folders/delete` | Delete folder |
| `misskey_drive_folders_update()` | `/api/drive/folders/update` | Update folder |

### Utility API

| Function | Endpoint | Description |
|----------|----------|-------------|
| `misskey_translate()` | `/api/notes/translate` | Translate text |

## Usage Examples

### Basic Usage

```c
#include "misskey_client.h"
#include <stdio.h>

int main() {
    // Create client
    MisskeyClient* client = misskey_client_new("misskey.io");
    
    // Set token
    misskey_client_set_token(client, "your_token_here");
    
    // Get server info
    char* resp = NULL;
    MisskeyError err = misskey_meta(client, &resp);
    if (err == MISSKEY_OK) {
        printf("%s\n", resp);
        misskey_free_string(client, resp);
    }
    
    // Post a note
    err = misskey_notes_create(client, "Hello from C!", NULL, NULL, &resp);
    if (err == MISSKEY_OK) {
        printf("%s\n", resp);
        misskey_free_string(client, resp);
    }
    
    misskey_client_free(client);
    return 0;
}
```

### Custom Memory Allocator

```c
static void* my_malloc(size_t size) {
    // Custom malloc implementation
    return malloc(size);
}

static void my_free(void* ptr) {
    // Custom free implementation
    free(ptr);
}

int main() {
    MisskeyAllocator alloc = {
        .malloc_fn = my_malloc,
        .realloc_fn = realloc,
        .free_fn = my_free,
        .user_data = NULL
    };
    
    MisskeyClient* client = misskey_client_new_with_allocator("misskey.io", &alloc);
    
    // ... use client ...
    
    misskey_client_free(client);
    return 0;
}
```

### Enable Curl Debug

```c
MisskeyClient* client = misskey_client_new("misskey.io");
misskey_client_set_token(client, "your_token");

// Enable debug - prints curl command for each request
misskey_request_set_debug(client, 1);

// Request will auto-print curl command
misskey_notes_create(client, "Hello!", NULL, NULL, &resp);
```

Output example:
```
### curl command for 'notes/create' ###
curl -X POST 'https://misskey.io/api/notes/create' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer your_token' \
  -d '{"i":"your_token","text":"Hello!"}'
##################################
```

## Error Handling

```c
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

// Get error description
const char* msg = misskey_error_str(err);
```

## Dependencies

- libcurl
- cJSON (included)

## Getting Token

Refer to [Misskey Official Documentation](https://misskey-hub.net/docs/for-developers/api/token/) to obtain an access token.

## License

MIT
