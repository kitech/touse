# ntipc 的 V 封装

`module ntipc` 在 `touse` 模块中按 `touse.ntipc` 导入。V 通过 `#flag .../xxx.o`
引入 C；若 `src/*.o` 不存在，会自动编译同名 `src/*.c`，不需要先 `make lib`。
C 绑定与 `#flag` 都放在 `ntipc.v`，不额外拆分 `.c.v` 文件。

## 用法

服务端与客户端应在不同进程；同一进程里请用 `spawn` 让 `connect` 与 `accept` 并发，
因为 `connect` 要等 `accept()` 回显 hello 才返回。

```v
// 服务端进程
import touse.ntipc

mut listener := ntipc.listen('my-service')!
defer { listener.close() }
mut server := listener.accept()!
defer { server.close() }
payload := ntipc.recv_frame(server)!
println(payload.str())
```

```v
// 客户端进程
import touse.ntipc

mut client := ntipc.connect('my-service', 2000)!
defer { client.close() }
ntipc.send_frame(client, 'hello'.bytes())!
```

## 测试

```sh
# 在 ntipc 模块目录下
v test .
```

## 说明

- 所有可能失败的操作返回 `!T`，错误类型是 `NtipcError`（实现 `msg()`）。
- 空句柄为 `voidptr(0)`；`close()` 会把句柄清空，避免重复释放。
- 帧格式是 4 字节小端长度 + payload，最大 8 MiB（见 `PROTOCOL.md`）。
- 若手动放了 `src/*.o`，V 会优先链接它；正常构建时 V 会把同名 `.c` 编译到对象缓存，不会在 `src/` 生成 `.o`。
- 不指定 `v -cc gcc`，按 V 默认编译器；Windows/macOS 未在本机实测。
