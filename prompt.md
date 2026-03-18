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
├── misskey.v                 # V 语言绑定
├── misskey_demo.v            # V 演示程序
├── mock_server.py            # Flask Mock 服务器
├── Makefile
├── README.md                 # 中文文档
├── README_en.md              # 英文文档
├── test_api.sh              # Shell 测试脚本
├── libmisskey.a              # C 静态库
└── misskey.so                # V 共享库
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

### 测试命令
```bash
# 启动 Mock 服务器
/opt/pyenv/bin/python mock_server.py &

# 测试 C 客户端
make clean && make && ./misskey_example localhost:3000 test_token

# 测试 V 客户端
LD_LIBRARY_PATH=. v run misskey_demo.v localhost:3000 test_token
```

## 已知问题与限制

1. **上传不支持断点续传**：网络中断需重新上传整个文件
2. **V 0.5 不支持 `json.Any`**：需要直接处理 JSON 字符串
3. **文件上传使用 curl_mime API**：需要正确处理 multipart 数据
