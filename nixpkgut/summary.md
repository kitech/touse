# nixpkgut 实现计划

## 项目概述

实现 nixpkgut 工具，C99+libcurl 和 Go 两个版本，功能包括：
1. 搜索 Nix 包 (search.nixos.org API)
2. 获取 store path (Hydra API)
3. 下载 NAR 包 (binary cache)

## 项目结构

```
nixpkgut/
├── nixse.c / nixse.go        # 搜索 + Hydra hashpath
├── nardl.c / nardl.go        # 下载
├── go.mod
└── cmd/
    ├── main.c
    └── main.go
```

## 当前进度

### ✅ 已完成 (Go)

- `nixse.go` - 搜索模块，可 import
- `nardl.go` - 下载模块，可 import  
- `cmd/main.go` - 统一 CLI，支持子命令

### ⏳ 待完成 (C)

- `nixse.c` - 搜索模块
- `nardl.c` - 下载模块
- `cmd/main.c` - 统一 CLI

## 搜索输出格式

### 完整模式 (--details)
```
第1行: {attr_name} {version} {arch-os}
第2行:     {description}
第3行:     {date} {platforms}
第4行:     {store_path}
```

### 默认模式
```
第1行: {attr_name} {version} {arch-os}
第2行:     {description}
第3行:     {date} {platforms}
```

### --plain 模式
```
{attr_name} {version}
```

## CLI 用法

### 搜索
```bash
nixpkgut search QUERY [options]
nixpkgut s QUERY [options]       # 短别名
```

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-a` | 架构 | 当前系统 |
| `-n` | 结果数 | 20 |
| `-p` | 页码 | 0 |
| `-c` | 频道 | unstable |
| `-P`, `--plain` | 仅输出 attr+version | false |
| `--details` | 显示 store path | false |

### 下载
```bash
nixpkgut download STORE_PATH [options]
nixpkgut dl STORE_PATH [options]  # 短别名
```

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-s` | Store path | - |
| `-o` | 输出文件 | stdout |
| `-c` | Cache URL | https://cache.nixos.org |

### 帮助
```bash
nixpkgut help
```

**注意**: search 子命令的 flags 必须出现在 query 参数之前:
```bash
nixpkgut search -P -n 5 hello   # ✅ 正确
nixpkgut search hello -P -n 5   # ❌ 错误
```

## API

| 功能 | API |
|------|-----|
| 搜索 | POST https://search.nixos.org/backend/latest-45-nixos-{channel}/_search |
| Hydra hashpath | GET https://hydra.nixos.org/job/nixpkgs/{jobset}/{attr}.{arch}/latest-finished |
| 下载 narinfo | {NIX_CACHE_URL}/{hash}.narinfo |
| 下载 NAR | {NIX_CACHE_URL}/nar/{narhash}.nar.xz |

## 认证

- search.nixos.org: Basic auth
  - Username: aWVSALXpZv
  - Password: X8gPHnzL52wFEekuxsfQ9cSh

## 环境变量

| 变量 | 默认值 |
|------|-------|
| NIX_CACHE_URL | https://cache.nixos.org |

## Channel 映射

| search channel | Hydra jobset |
|--------------|------------|
| unstable | unstable |
| staging | staging |
| staging-next | staging-next |

## 实现顺序

1. ✅ nixse.go - 搜索模块
2. ⏳ nixse.c - 搜索模块 (C)
3. ✅ nardl.go - 下载模块
4. ⏳ nardl.c - 下载模块 (C)
5. ✅ cmd/main.go - CLI
6. ⏳ cmd/main.c - CLI (C)