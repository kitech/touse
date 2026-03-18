# Misskey C Client

基于libcurl的Misskey API客户端库，支持自定义内存分配器。

## 特性

- 简洁的C语言API
- 支持自定义内存分配器
- 自动打印curl调试命令
- 支持Bearer Token认证

## 项目结构

```
misskey-client/
├── Makefile
├── README.md
├── README_en.md
├── mock_server.py      # Mock服务器
├── test_api.sh         # API测试脚本
├── misskey_example     # 编译后的示例
└── src/
    ├── misskey_client.h      # API头文件
    ├── misskey_client.c       # 核心实现
    ├── examples.c             # 使用示例
    └── cJSON/               # JSON解析库
        ├── cJSON.h
        └── cJSON.c
```

## 编译

```bash
make
```

## Mock服务器

提供了本地Mock服务器用于测试，无需真实Misskey实例。

### 启动Mock服务器

```bash
/opt/pyenv/bin/python mock_server.py
```

Mock服务器会监听 `http://localhost:3000`，默认Token为 `test_token_12345`。

### API测试脚本

```bash
# 测试所有API
./test_api.sh localhost:3000 test_token_12345

# 测试真实服务器
./test_api.sh misskey.io YOUR_TOKEN
```

测试脚本会自动检测：
- localhost/127.0.0.1 使用 HTTP
- 其他使用 HTTPS

## 运行

```bash
# 无token（仅测试公开API）
./misskey_example misskey.io

# 带token
./misskey_example misskey.io YOUR_TOKEN

# 启用内存追踪
./misskey_example misskey.io YOUR_TOKEN --track-alloc

# 通过代理
proxychains ./misskey_example misskey.io YOUR_TOKEN
```

## API列表

### 客户端管理

| 函数 | 说明 |
|------|------|
| `misskey_client_new()` | 创建客户端 |
| `misskey_client_new_with_allocator()` | 使用自定义allocator创建 |
| `misskey_client_free()` | 释放客户端 |
| `misskey_client_set_token()` | 设置访问令牌 |
| `misskey_client_set_timeout()` | 设置超时时间 |
| `misskey_client_get_allocator()` | 获取allocator |

### 基础API

| 函数 | 端点 | 说明 |
|------|------|------|
| `misskey_request()` | 通用 | 通用POST请求 |
| `misskey_meta()` | `/api/meta` | 获取服务器信息 |
| `misskey_request_set_debug()` | - | 启用/禁用curl调试 |
| `misskey_request_print_curl()` | - | 打印curl命令 |

### 笔记API

| 函数 | 端点 | 说明 |
|------|------|------|
| `misskey_notes_timeline()` | `/api/notes/timeline` | 获取时间线 |
| `misskey_notes_create()` | `/api/notes/create` | 发布笔记 |

### 账号API

| 函数 | 端点 | 说明 |
|------|------|------|
| `misskey_i_notifications()` | `/api/i/notifications` | 获取通知 |

### 网盘API

| 函数 | 端点 | 说明 |
|------|------|------|
| `misskey_drive()` | `/api/drive` | 获取网盘容量信息 |
| `misskey_drive_files()` | `/api/drive/files` | 获取文件列表 |
| `misskey_drive_files_create()` | `/api/drive/files/create` | 上传文件 |
| `misskey_drive_files_delete()` | `/api/drive/files/delete` | 删除文件 |
| `misskey_drive_files_update()` | `/api/drive/files/update` | 更新文件 |
| `misskey_drive_files_find()` | `/api/drive/files/find` | 按哈希查找文件 |
| `misskey_drive_files_show()` | `/api/drive/files/show` | 获取文件属性 |
| `misskey_drive_files_upload_from_url()` | `/api/drive/files/upload-from-url` | 从URL上传文件 |
| `misskey_drive_folders()` | `/api/drive/folders` | 获取文件夹列表 |
| `misskey_drive_folders_create()` | `/api/drive/folders/create` | 创建文件夹 |
| `misskey_drive_folders_delete()` | `/api/drive/folders/delete` | 删除文件夹 |
| `misskey_drive_folders_update()` | `/api/drive/folders/update` | 更新文件夹 |

### 工具API

| 函数 | 端点 | 说明 |
|------|------|------|
| `misskey_translate()` | `/api/notes/translate` | 翻译文本 |

## 使用示例

### 基本用法

```c
#include "misskey_client.h"
#include <stdio.h>

int main() {
    // 创建客户端
    MisskeyClient* client = misskey_client_new("misskey.io");
    
    // 设置token
    misskey_client_set_token(client, "your_token_here");
    
    // 获取服务器信息
    char* resp = NULL;
    MisskeyError err = misskey_meta(client, &resp);
    if (err == MISSKEY_OK) {
        printf("%s\n", resp);
        misskey_free_string(client, resp);
    }
    
    // 发布笔记
    err = misskey_notes_create(client, "Hello from C!", NULL, NULL, &resp);
    if (err == MISSKEY_OK) {
        printf("%s\n", resp);
        misskey_free_string(client, resp);
    }
    
    misskey_client_free(client);
    return 0;
}
```

### 自定义内存分配器

```c
static void* my_malloc(size_t size) {
    // 自定义malloc实现
    return malloc(size);
}

static void my_free(void* ptr) {
    // 自定义free实现
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
    
    // ... 使用客户端 ...
    
    misskey_client_free(client);
    return 0;
}
```

### 启用curl调试

```c
MisskeyClient* client = misskey_client_new("misskey.io");
misskey_client_set_token(client, "your_token");

// 启用调试 - 每次请求会打印对应的curl命令
misskey_request_set_debug(client, 1);

// 请求会自动打印curl命令
misskey_notes_create(client, "Hello!", NULL, NULL, &resp);
```

输出示例：
```
### curl command for 'notes/create' ###
curl -X POST 'https://misskey.io/api/notes/create' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer your_token' \
  -d '{"i":"your_token","text":"Hello!"}'
##################################
```

## 错误处理

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

// 获取错误描述
const char* msg = misskey_error_str(err);
```

## 依赖

- libcurl
- Python 3 + Flask (仅用于Mock服务器)

### Python依赖安装

```bash
/opt/pyenv/bin/pip install flask
```

## 获取Token

参考 [Misskey官方文档](https://misskey-hub.net/docs/for-developers/api/token/) 获取访问令牌。

## License

MIT
