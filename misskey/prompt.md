# Misskey API C 客户端开发需求

## 项目概述

创建 Misskey API 的 C 语言客户端库，使用 libcurl，并提供 V 语言 0.5 绑定。

## 技术要求

### 核心要求
- 使用 libcurl 进行 HTTP 请求
- 支持自定义内存分配器（用于内存追踪）
- 所有 API 支持可选的自定义 allocator
- 包含 curl 调试输出（打印 curl 命令）
- localhost 使用 HTTP，其他主机使用 HTTPS

### V 语言 0.5 兼容
- 使用 `!` 表示错误返回（Result 类型）
- 使用 `@[attr]` 替代 `[attr]`
- 函数参数不可变，需要用 `mut` 声明可变变量
- 使用 `voidptr(0)` 替代 `&char(0)` 表示空指针
- 编译为共享库：`v -shared xxx.v`
- **C 指针类型映射**：
  - `char*`（指向 char 的指针）→ `charptr`
  - `char**`（指向字符串指针的指针）→ `&charptr`
  - `charptr` 表示 C 中的 `char*`
  - `&charptr` 表示传入一个指针变量的地址，用于接收返回的字符串

## API 实现清单

### 基础 API
| 函数 | 端点 | 说明 |
|------|------|------|
| `misskey_meta()` | `/api/meta` | 获取服务器信息 |
| `misskey_notes_timeline()` | `/api/notes/timeline` | 获取时间线 |
| `misskey_notes_create()` | `/api/notes/create` | 创建笔记 |
| `misskey_i_notifications()` | `/api/i/notifications` | 获取通知 |

### 网盘 API
| 函数 | 端点 | 说明 |
|------|------|------|
| `misskey_drive()` | `/api/drive` | 获取网盘容量信息 |
| `misskey_drive_files()` | `/api/drive/files` | 获取文件列表 |
| `misskey_drive_files_create()` | `/api/drive/files/create` | 上传文件（multipart/form-data） |
| `misskey_drive_files_delete()` | `/api/drive/files/delete` | 删除文件 |
| `misskey_drive_files_update()` | `/api/drive/files/update` | 更新文件 |
| `misskey_drive_files_find()` | `/api/drive/files/find` | 按哈希查找文件 |
| `misskey_drive_files_show()` | `/api/drive/files/show` | 获取文件属性 |
| `misskey_drive_files_upload_from_url()` | `/api/drive/files/upload-from-url` | 从URL上传文件 |
| `misskey_drive_files_download()` | - | 下载文件（支持断点续传） |
| `misskey_drive_folders()` | `/api/drive/folders` | 获取文件夹列表 |
| `misskey_drive_folders_create()` | `/api/drive/folders/create` | 创建文件夹 |
| `misskey_drive_folders_delete()` | `/api/drive/folders/delete` | 删除文件夹 |
| `misskey_drive_folders_update()` | `/api/drive/folders/update` | 更新文件夹 |

### 工具 API
| 函数 | 端点 | 说明 |
|------|------|------|
| `misskey_translate()` | `/api/notes/translate` | 翻译文本 |

### 时间线 API
| 函数 | 端点 | 说明 |
|------|------|------|
| `misskey_notes_timeline()` | `/api/notes/timeline` | 获取时间线 |
| `misskey_notes_local_timeline()` | `/api/notes/local-timeline` | 获取本地时间线 |
| `misskey_notes_global_timeline()` | `/api/notes/global-timeline` | 获取全局时间线 |
| `misskey_notes_timeline_full()` | `/api/notes/timeline` | 带选项的时间线 |
| `misskey_notes_local_timeline_full()` | `/api/notes/local-timeline` | 带选项的本地时间线 |
| `misskey_notes_global_timeline_full()` | `/api/notes/global-timeline` | 带选项的全局时间线 |

### 用户 API
| 函数 | 端点 | 说明 |
|------|------|------|
| `misskey_users_show()` | `/api/users/show` | 获取用户信息（支持扩展字段） |

### 收藏夹 API
| 函数 | 端点 | 说明 |
|------|------|------|
| `misskey_clips_list()` | `/api/clips/list` | 获取收藏夹列表 |
| `misskey_clips_show()` | `/api/clips/show` | 获取收藏夹详情 |
| `misskey_clips_create()` | `/api/clips/create` | 创建收藏夹 |
| `misskey_clips_update()` | `/api/clips/update` | 更新收藏夹 |
| `misskey_clips_delete()` | `/api/clips/delete` | 删除收藏夹 |
| `misskey_clips_notes()` | `/api/clips/notes` | 获取收藏夹中的帖子 |

### 流式 API
| 函数 | 说明 |
|------|------|
| `misskey_stream_new()` | 创建 WebSocket 流连接 |
| `misskey_stream_connect()` | 连接到频道 |
| `misskey_stream_disconnect()` | 断开连接 |
| `misskey_stream_poll()` | 轮询事件 |
| `misskey_stream_subscribe_note()` | 订阅帖子 |
| `misskey_stream_unsubscribe_note()` | 取消订阅帖子 |

### 代理 (Proxy) API
| 函数 | 说明 |
|------|------|
| `misskey_client_set_proxy_url()` | 设置代理（URL格式） |
| `misskey_client_set_proxy()` | 设置代理（结构体格式） |
| `misskey_client_clear_proxy()` | 清除代理设置 |
| `misskey_client_get_proxy()` | 获取当前代理配置 |
| `misskey_stream_new_with_proxy()` | 创建带代理的 WebSocket 流连接 |

## 代理支持

### 代理类型

| 类型 | URL 前缀 | 说明 |
|------|---------|------|
| HTTP | `http://` | 标准 HTTP 代理 |
| HTTPS | `https://` | HTTPS CONNECT 隧道代理 |
| SOCKS4 | `socks4://` | SOCKS4 协议 |
| SOCKS4A | `socks4a://` | SOCKS4 with DNS on proxy |
| SOCKS5 | `socks5://` | SOCKS5 协议 |

### C 语言使用示例

```c
// 简单代理
misskey_client_set_proxy_url(client, "socks5://127.0.0.1:1080");

// 带认证的代理
misskey_client_set_proxy_url(client, "socks5://user:pass@proxy.com:1080");

// HTTPS 代理
misskey_client_set_proxy_url(client, "https://proxy.com:8080");

// 使用代理结构体
MisskeyProxy proxy = {
    .type = MISSKEY_PROXY_SOCKS5,
    .host = "proxy.example.com",
    .port = 1080,
    .username = "user",
    .password = "pass"
};
misskey_client_set_proxy(client, &proxy);

// 清除代理
misskey_client_clear_proxy(client);

// WebSocket 流使用代理
MisskeyStream* stream = misskey_stream_new_with_proxy("misskey.io", "token", &proxy);
```

### V 语言使用示例

```v
import misskey

// 简单代理
client.set_proxy_url("socks5://127.0.0.1:1080")!

// 带认证的代理
client.set_proxy_url("socks5://user:pass@proxy.com:1080")!

// 使用代理结构体
proxy := misskey.Proxy{
    proxy_type: .socks5
    host: "proxy.example.com"
    port: 1080
    username: "user"
    password: "pass"
}
client.set_proxy(proxy)!

// 清除代理
client.clear_proxy()

// WebSocket 流使用代理
stream := misskey.stream_new_with_proxy("misskey.io", "token", proxy)!
```

### 代理认证

支持以下代理协议的认证：
- HTTP 代理：Basic Auth
- SOCKS5 代理：Username/Password

认证信息通过 URL 格式 `protocol://user:pass@host:port` 或 `Proxy` 结构体传入。

## 下载功能设计

### MisskeyDownloadOptions 结构体
```c
typedef struct {
    const char* url;           // 文件URL（可选，从file_id获取）
    const char* output_path;   // 输出文件路径（可选）
    misskey_write_callback write_cb;  // 写入回调（可选）
    void* write_userdata;      // 回调用户数据
    long resume_from;          // 断点续传起始位置（0表示从头开始）
    int follow_redirects;      // 是否跟随重定向
} MisskeyDownloadOptions;
```

### 断点续传支持
- 使用 `CURLOPT_RESUME_FROM_LARGE` 支持断点续传
- 根据 `resume_from` 值设置下载起始位置
- 文件模式：追加写入（"ab"）或覆盖写入（"wb"）

### 使用示例
```c
// 完整下载
MisskeyDownloadOptions opts = {
    .url = "https://example.com/file.png",
    .output_path = "/tmp/file.png",
    .resume_from = 0,
    .follow_redirects = 1
};
misskey_drive_files_download(client, NULL, &opts, &http_code, NULL);

// 断点续传
opts.resume_from = 1024000;  // 从1MB处继续
misskey_drive_files_download(client, NULL, &opts, &http_code, NULL);
```

## 第三方库版本兼容

### libcurl 版本检测
```c
#define MISSKEY_CURL_VERSION_7_55_0 (LIBCURL_VERSION_NUM >= 0x073700)

#if MISSKEY_CURL_VERSION_7_55_0
    curl_easy_getinfo(curl, CURLINFO_CONTENT_LENGTH_DOWNLOAD_T, &content_length);
#else
    double content_length_old = 0;
    curl_easy_getinfo(curl, CURLINFO_CONTENT_LENGTH_DOWNLOAD, &content_length_old);
    content_length = (curl_off_t)content_length_old;
#endif
```

### 兼容性要点
- `CURLINFO_CONTENT_LENGTH_DOWNLOAD_T` (curl_off_t) 需要 libcurl 7.55.0+
- 旧版本使用 `CURLINFO_CONTENT_LENGTH_DOWNLOAD` (double)
- 需要检测版本并条件编译

## 文件组织

```
misskey/
├── src/
│   ├── misskey_client.h      # C 头文件
│   ├── misskey_client.c      # C 实现
│   ├── misskey.hpp           # C++ 封装头文件
│   ├── examples.c             # C 示例
│   ├── test_cpp.cpp          # C++ 测试程序
│   └── cJSON/                # JSON 库
├── misskey.v                 # V 语言绑定模块
├── examples/
│   └── demo.v               # V 演示程序
├── mock_server.py             # Flask Mock 服务器
├── Makefile
├── README.md                 # 中文文档
├── README_en.md              # 英文文档
├── test_api.sh               # Shell 测试脚本
└── libmisskey.a              # C 静态库
```

## C++ 封装

### 类名
`misskey::MisskeyApi`

### 特性
- RAII 资源管理（自动析构）
- 现代 C++ 接口（std::string、std::optional）
- 异常机制（misskey::MisskeyApi::Exception）
- 移动语义支持

### 编译
```bash
make cpp    # 使用 -O1 优化编译
```

### 测试命令
```bash
# 启动 Mock 服务器
/opt/pyenv/bin/python mock_server.py &

# 测试 C++ 客户端
make cpp && ./misskey_cpp_test localhost:3000 test_token
```

## Misskey API 特性说明

### 上传
- **不支持断点续传**：Misskey 的 `/api/drive/files/create` 是单次请求，无法在中断后恢复
- 文件通过 multipart/form-data 上传
- 支持可选参数：folderId, name, comment, isSensitive, force

### 下载
- 通过 `drive/files/show` 获取文件 URL
- 实际下载由客户端直接访问返回的 URL
- **断点续传支持**：取决于存储/CDN 是否支持 HTTP Range 请求
- Misskey 不提供专门的下载 API，客户端需自行实现

### 认证
- Bearer Token 放在 Authorization header
- 大多数 API 需要认证（credential required）

## 测试环境

### Mock 服务器
- 使用 Python Flask 实现
- 端口：3000
- 所有 API 返回模拟数据

### Mock 服务器端点
| 端点 | 说明 |
|------|------|
| `/api/meta` | 服务器信息 |
| `/api/notes/timeline` | 时间线 |
| `/api/notes/create` | 创建笔记 |
| `/api/notes/delete` | 删除笔记 |
| `/api/i/notifications` | 通知列表 |
| `/api/i` | 用户信息 |
| `/api/drive` | 网盘容量 |
| `/api/drive/files` | 文件列表 |
| `/api/drive/folders` | 文件夹列表 |
| `/api/clips/list` | 收藏夹列表 |
| `/api/announcements` | 公告列表 |
| `/api/stats` | 统计信息 |
| `/api/notes/global-timeline` | 全局时间线 |
| `/api/i/favorites` | 收藏列表 |
| `/api/antenna/list` | 天线列表 |
| `/api/channel/list` | 频道列表 |

### 测试命令
```bash
# 启动 Mock 服务器
/opt/pyenv/bin/python mock_server.py &

# 测试 C 客户端
make clean && make && ./misskey_example localhost:3000 test_token

# 测试 V 客户端
v examples/demo.v && ./examples/demo localhost:3000 test_token

# Fuzz 测试
make fuzz fuzz-cpp && ./fuzz_test && ./fuzz_test_cpp
```

## Fuzz 测试

### 测试覆盖
| 测试项 | C API | C++ API |
|--------|-------|---------|
| 空字符串 | ✅ | ✅ |
| 负数参数 | ✅ | ✅ |
| 零值参数 | ✅ | ✅ |
| 大数值参数 | ✅ | ✅ |
| 特殊字符 | ✅ | ✅ |
| 超长字符串 | ✅ | ✅ |
| 无效主机 | ✅ | ✅ |
| 畸形 URL | ✅ | ✅ |
| 超时值 | ✅ | ✅ |
| 调试开关 | ✅ | ✅ |
| 移动语义 | - | ✅ |
| 可选参数 | - | ✅ |

## V Binding 开发指南

### 1. API 函数命名规范

- **结构体 API**（默认）：返回 V 结构体，如 `meta()`, `notes_timeline()`, `notes_timeline_full()`
- **Raw API**：返回 JSON 字符串，如 `meta_raw()`, `notes_timeline_raw()`, `notes_timeline_full_raw()`

### 1.1 函数重命名规则

| 原函数 | 新函数（默认） | Raw 版本 |
|--------|----------------|----------|
| `misskey_notes_timeline_struct()` | `misskey_notes_timeline()` | `misskey_notes_timeline_raw()` |
| `misskey_notes_timeline_full()` | `misskey_notes_timeline_full()` | `misskey_notes_timeline_full_raw()` |
| `misskey_notes_local_timeline()` | `misskey_notes_local_timeline()` | `misskey_notes_local_timeline_raw()` |
| `misskey_notes_global_timeline()` | `misskey_notes_global_timeline()` | `misskey_notes_global_timeline_raw()` |
| `misskey_notes_create()` | `misskey_notes_create()` | `misskey_notes_create_raw()` |
| `misskey_users_show()` | `misskey_users_show()` | `misskey_users_show_raw()` |

### 1.2 时间线选项 (TimelineOptions)

```v
pub struct TimelineOptions {
    limit           int      // 限制数量 (默认20)
    with_files      bool     // 仅显示带附件的帖子
    with_renotes    bool     // 包含转推
    with_replies    bool     // 包含回复
    allow_partial   bool     // 允许返回不完整数据
    since_id        string   // 返回此ID之后的帖子
    until_id        string   // 返回此ID之前的帖子
    since_date      int      // 返回此日期之后的帖子 (Unix时间戳)
    until_date      int      // 返回此日期之前的帖子 (Unix时间戳)
}
```

使用示例：
```v
opts := TimelineOptions{
    limit: 10
    with_files: true
    with_renotes: false
}
notes := client.notes_local_timeline_full(opts)!
```

### 1.3 创建笔记选项 (CreateNoteOptions)

```v
pub struct CreateNoteOptions {
    text           string   // 笔记内容
    reply_id       string   // 回复目标笔记ID
    renote_id      string   // 转推目标笔记ID
    file_ids       []string // 附件文件ID列表
    visibility     int      // 可见性 (0=public, 1=home, 2=followers, 3=specified)
    cw             string   // 内容警告文字
    local_only     bool     // 仅本地可见
    channel_id     string   // 频道ID
    auto_sensitive bool     // 自动敏感内容标记
    draft          bool     // 保存为草稿
}
```

### 1.4 用户信息扩展字段

V 结构体包含以下扩展字段：
```v
pub struct User {
    id                       string
    name                     string
    username                 string
    host                     string
    avatar_url               string
    avatar_blurhash          string
    banner_url               string      // 新增：用户横幅图片
    description              string      // 新增：用户简介
    url                      string
    followers_count          int         // 新增：粉丝数
    following_count          int         // 新增：关注数
    notes_count              int         // 新增：帖子数
    is_bot                   bool
    is_cat                   bool
    is_locked                bool
    is_silenced              bool
    has_pending_follow_request bool
}
```

### 1.5 笔记扩展字段

```v
pub struct Note {
    id              string
    created_at      string
    text            string
    cw              string
    user_id         string
    reply_id        string
    renote_id       string
    channel_id      string
    local_only      bool
    reactions_count int
    replies_count   int         // 新增：回复数
    renote_count    int          // 新增：转推数
    renote_text     string       // 新增：转推的原始文本
    is_renote       bool         // 新增：是否为转推
    is_reply        bool         // 新增：是否为回复
    has_files       bool         // 新增：是否有附件
    files_count     int          // 新增：附件数量
    user            User
}
```

### 2. V 语言 0.5 类型映射

| C 类型 | V 类型 |
|--------|--------|
| `char*` | `charptr` |
| `char**` | `&charptr` |
| `byte` | `u8` |
| `[heap]` | `@[heap]` |
| `&char(0)` | `voidptr(0)` |

### 3. 指针和数组处理

```v
// C 函数声明使用 voidptr
fn C.misskey_meta(client &C.MisskeyClient, response &charptr) int

// 字符串转换
fn cstr_to_string(cptr voidptr) string {
    if cptr == unsafe { nil } {
        return ''
    }
    return unsafe { cstring_to_vstring(&char(cptr)) }
}

// 固定大小数组访问
cstr_to_string(voidptr(&cmeta.name[0]))
```

### 4. Receiver 语法

```v
// 使用不可变引用
pub fn (c &Client) meta() !Meta
pub fn (c &Client) notes_timeline_raw(limit int, local bool) !string
```

### 5. 编译配置

```v
module misskey

import json // includes cJSON

#flag -I@DIR/src
#flag @DIR/cJSON.o
#flag @DIR/misskey_client.o
#flag -lcurl

#include "misskey_client.h"
```

### 6. 错误处理

```v
// 获取详细错误信息
fn (c &Client) get_last_error() (int, string)

fn (c &Client) get_error_msg() string {
    http_code, detail := c.get_last_error()
    if http_code > 0 {
        if detail.len > 0 {
            return 'HTTP ${http_code}: ${detail}'
        }
        return 'HTTP ${http_code}'
    }
    if detail.len > 0 {
        return detail
    }
    return ''
}

// HTTP 错误格式：HTTP {状态码}: {详情}
```

### 7. V 字符串到 C 字符串的正确用法

**V 0.5 使用 `charptr` 类型声明 C 函数参数**：

```v
// C 函数声明使用 charptr
fn C.misskey_notes_create(client &C.MisskeyClient, text charptr, reply_id charptr, renote_id charptr, note_out &C.MisskeyNote) int

// 调用时直接使用 .str 属性（返回 charptr）
ret := C.misskey_notes_create(c.c_client, text.str, reply_cstr, renote_cstr, cnote)
```

**可选字符串参数模式**：
```v
// 可选参数使用三元表达式，NULL 用 voidptr(0) 表示
reply_cstr := if reply_id.len > 0 { reply_id.str } else { voidptr(0) }
```

**注意**：不要使用 `&char()` 强制转换，直接使用 `.str` 即可。

### 8. cstring_to_vstring 和 free_string

这两个函数需要 `&char` 类型参数，需要强制转换：

```v
// 将 C 字符串转为 V 字符串
result := unsafe { cstring_to_vstring(&char(c_response)) }

// 释放 C 分配的字符串
C.misskey_free_string(c.c_client, &char(response))
```

### 9. V 0.5 类型映射

| C 类型 | V 0.5 类型 | 说明 |
|--------|------------|------|
| `char*` | `charptr` | C 字符串指针 |
| `char**` | `&charptr` | 指向字符串指针的指针（用于输出参数） |
| `void*` | `voidptr` | 通用指针 |
| `byte` | `u8` | 单字节 |
| `[heap]` | `@[heap]` | 堆分配结构体 |
| `NULL` | `voidptr(0)` 或 `unsafe { nil }` | 空指针 |

### 10. cJSON 冲突解决方案

V 自带 json 模块使用 cJSON，与独立的 cJSON.o 冲突：
- 移除独立的 cJSON.o
- 使用 V 自带的 `import json`（包含 cJSON）

## Streaming API

### WebSocket 连接

Misskey 支持通过 WebSocket 接收实时事件流。使用 libcurl 的 WebSocket 支持实现。

### V 语言流式 API

```v
import misskey

// 创建流连接
mut stream := misskey.stream_new('misskey.example.com', 'your-token')!
defer { stream.freeit() }

// 设置事件处理器
stream.set_handler(fn(msg_type string, body string) {
    println('收到事件: ${msg_type}')
    println('内容: ${body}')
})

// 连接到时间线频道
stream.connect(.local_timeline, '')!

// 或者连接到主频道并订阅特定帖子
stream.connect(.main, '')!
stream.subscribe_note('note_id_here')!

// 轮询事件（非阻塞）
for {
    stream.poll(1000) or {
        // 处理错误
    }
}
```

### StreamChannel 枚举

| 值 | 名称 | 说明 |
|----|------|------|
| 0 | `main` | 主时间线 |
| 1 | `home_timeline` | 家庭时间线 |
| 2 | `local_timeline` | 本地时间线 |
| 3 | `hybrid_timeline` | 混合时间线 |
| 4 | `global_timeline` | 全局时间线 |

### 流方法

| 方法 | 说明 |
|------|------|
| `stream_new(host, token)` | 创建新的流连接 |
| `connect(channel, channel_id)` | 连接到指定频道 |
| `disconnect(channel_id)` | 断开连接 |
| `subscribe_note(note_id)` | 订阅特定帖子 |
| `unsubscribe_note(note_id)` | 取消订阅帖子 |
| `poll(timeout_ms)` | 轮询事件（阻塞指定毫秒） |
| `set_handler(handler)` | 设置事件回调处理函数 |
| `freeit()` | 释放流资源 |

### C 流式 API

```c
// 创建流
MisskeyStream* stream = misskey_stream_new("misskey.example.com", "token");

// 设置回调
misskey_stream_set_callback(stream, my_callback, user_data);

// 连接频道
misskey_stream_connect(stream, MISSKEY_STREAM_CHANNEL_LOCAL_TIMELINE, "");

// 订阅帖子
misskey_stream_subscribe_note(stream, "note_id");

// 轮询事件
while (1) {
    misskey_stream_poll(stream, 1000);
}

// 清理
misskey_stream_free(stream);
```

## 已知问题与限制

1. **上传不支持断点续传**：网络中断需重新上传整个文件
2. **V 不支持函数重载**：不能有两个同名不同返回类型的函数
3. **cJSON 冲突**：使用 V 自带的 json 模块 (cJSON)
4. **Misskey 不支持帖子编辑**：只能删除后重建
5. **本地时间线**：使用 `notes/local-timeline` 端点，不要使用 `notes/timeline` 的 `local` 参数（该参数不存在）
6. **本地用户识别**：本地用户的 `host` 字段为空字符串，用户名为 `@username` 格式
