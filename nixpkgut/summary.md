# nixpkgut 实现计划

## 项目概述

实现 nixpkgut 工具，C99+libcurl 和 Go 两个版本，功能包括：
1. 搜索 Nix 包 (search.nixos.org API)
2. 获取 store path (Hydra API)
3. 下载 NAR 包 (binary cache)

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

## 当前进度

### ✅ 已完成 (Go)

- `nixse.go` - 搜索模块，可 import
- `nardl.go` - 下载模块，可 import  
- `cmd/main.go` - 统一 CLI，支持子命令

### ✅ 已完成 (C)

- `nixse.c` / `nixse.h` - 搜索模块
- `nardl.c` / `nardl.h` - 下载模块
- `cmd/main.c` - 统一 CLI
- `Makefile` - 构建配置

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
| `-n`, `--num` | 结果数 | 20 |
| `-p`, `--page` | 页码 | 0 |
| `-c`, `--channel` | 频道 | unstable |
| `-P`, `--plain` | 仅输出 attr+version | false |
| `-d`, `--details` | 显示 store path | false |

### 下载参数
| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-o`, `--output` | 输出文件 | stdout |
| `-c`, `--cache` | Cache URL | https://cache.nixos.org |

**注意**: search 子命令的 flags 必须出现在 query 参数之前

## 依赖

### Go
- Go 1.18+

### C
- libcurl
- json-c
- getopt_long (GNU extensions)

## 实现顺序

1. ✅ nixse.go - 搜索模块
2. ✅ nixse.c - 搜索模块 (C)
3. ✅ nardl.go - 下载模块
4. ✅ nardl.c - 下载模块 (C)
5. ✅ cmd/main.go - CLI
6. ✅ cmd/main.c - CLI (C)