# nixpkgut 实现总结

## 项目概述

nixpkgut 工具用于搜索 Nix 包和下载 NAR 归档，有 C99+libcurl 和 Go 两个版本。

## 项目结构

```
nixpkgut/
├── nixse.c / nixse.go        # 搜索模块
├── nardl.c / nardl.go        # 下载模块
├── nixse.h / nardl.h         # C 头文件
├── go.mod
├── Makefile                  # C 版本构建
└── cmd/
    ├── main.c
    └── main.go
```

## 已完成功能

### 搜索 (nixse)
- 调用 search.nixos.org API (需 Basic 认证)
- 支持频道: unstable, staging, staging-next, 25.11, 25.04
- 自动检测当前系统架构 (x86_64-linux, aarch64-linux 等)
- 获取 store path (Hydra API 或 nix eval)

### 下载 (nardl)
- 从 binary cache 下载 NAR 归档
- 支持自定义 cache URL (NIX_CACHE_URL 环境变量)
- 支持输出到文件或 stdout

## CLI 用法

### Go 版本
```bash
go build -o nixpkgut ./cmd
./nixpkgut search hello
./nixpkgut s -P -n 5 hello
./nixpkgut download /nix/store/xxx-hello-2.12.3
./nixpkgut help
```

### C 版本
```bash
make
./nixpkgut search hello
./nixpkgut s -P -n 5 hello
./nixpkgut download /nix/store/xxx-hello-2.12.3
./nixpkgut help
```

### 搜索参数
| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-a`, `--arch` | 架构 | 当前系统 |
| `-n`, `--num` | 结果数 (max 50) | 20 |
| `-p`, `--page` | 页码 | 0 |
| `-c`, `--channel` | 频道 | unstable |
| `-P`, `--plain` | 仅输出 attr version | false |
| `-d`, `--details` | 显示 store path | false |

### 下载参数
| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-o`, `--output` | 输出文件 | stdout |
| `-c`, `--cache` | Cache URL | https://cache.nixos.org |

**注意**: search 子命令的 flags 必须出现在 query 参数之前

## 技术细节

### API 端点
- 搜索: `https://search.nixos.org/api/v1/search`
- Hydra: `https://hydra.nixos.org/job/nixpkgs/<jobset>.<system>/<package>/latest-finished`
  - 示例: https://hydra.nixos.org/job/nixpkgs/unstable.x86_64-linux/hello/latest-finished

### 认证
- search.nixos.org 使用 Basic 认证
  - 来源: https://github.com/SarahhhhFoster/nix-pkg-query/blob/main/nix-pkg-query.py#L41
  - 用户名: aWVSALXpZv
  - 密码: X8gPHnzL52wFEekuxsfQ9cSh

### 环境变量
- `NIX_CACHE_URL`: 二进制缓存 URL (默认: https://cache.nixos.org)

## 依赖

### Go
- Go 1.18+

### C
- libcurl
- json-c
- getopt_long (GNU extensions)

## 构建

### Go
```bash
go build -o nixpkgut ./cmd
```

### C
```bash
make
# 或
make clean && make
```

## 测试

```bash
# 搜索包
./nixpkgut search hello
./nixpkgut search -P -n 5 hello
./nixpkgut search -c 25.11 -d -n 1 hello

# 下载 NAR
./nixpkgut download /nix/store/xxx-hello-2.12.3 -o hello.nar
```