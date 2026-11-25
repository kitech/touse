# ntipc

纯 C 的 Pipe 层实现，基于 [DimensionscapeOrg/native-ipc](https://github.com/DimensionscapeOrg/native-ipc)（Apache 2.0, commit `39fc532`）。只保留 Pipe（listener/connection 传输原语），不包含 Channel/SharedMemory 层。

## 范围

- **包含**：`include/ntipc.h`、`src/common.c`、`src/pipe_posix.c`、`src/pipe_windows.c`
- **不包含**：原项目的 Channel（线程+事件队列）、SharedMemory（命名共享 payload）
- **API 前缀**：`ntipc_*` / `NTIPC_*`（与原 `native_ipc_*` 对应，语义一致）
- **OS 对象名**：仍沿用协议规定的 `native-ipc-*` 名字空间，目的是保持与上游 C++ 实现的对象/协议互通

## 协议

见 `PROTOCOL.md`（原样保留）。重点：

- Unix：`AF_UNIX` `SOCK_STREAM`，字节流；应用层用 `hello` + `[u32 len][payload]` 分帧。
- Windows：byte-mode named pipe（`PIPE_TYPE_BYTE | PIPE_READMODE_BYTE`），同样是字节流，同一套分帧。
- hello：16 字节，`"NIPC" + u16 version + u16 flags + u64 id`，client 发后 listener 回显 id。
- frame payload 最大 8 MiB。

## 构建（Linux/macOS）

```sh
make -C /home/gzleo/aprog/touse/ntipc OUTDIR=/tmp/opencode
/tmp/opencode/ntipc-test
```

或 CMake：

```sh
cmake -S /home/gzleo/aprog/touse/ntipc -B /tmp/opencode/ntipc-build -DBUILD_TESTING=ON
cmake --build /tmp/opencode/ntipc-build
ctest --test-dir /tmp/opencode/ntipc-build --output-on-failure
```

## Windows

- 目标最低：WinXP SP3 / Server 2003+ API 集（`CreateNamedPipeA`, `PIPE_REJECT_REMOTE_CLIENTS`, `_Interlocked*` intrinsic, QPC）。
- 不使用 `GetTickCount64`、`Interlocked*64` API 函数形式。
- 当前环境未做 Windows 编译/运行实测；Linux 已实测。

## 许可

- 原项目：Apache 2.0，Copyright Dimensionscape contributors（见 `LICENSE`）。
- 纯 C 重写改动：同样 Apache 2.0，保留原版权与 NOTICE 要求。