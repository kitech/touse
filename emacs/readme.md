
### TODOS

- [+] treemacs 添加函数列表/类型列表窗口
- [+] 弹出窗口式操作
- [ ] 弹出菜单
- [ ] i18n
- [ ] 中文界面,菜单/工具条提示等
- [x] 支持绑定按键
- [ ] 按键绑定尽量用两个键
- [ ] minibuffer不应该占全部宽度
- [ ] 像firefox/vscode那种tab切换,非全循环,有一种栈结构
        https://github.com/plexus/chemacs2
- [x] 滚动条的宽度
- [x] window title bar, hide/height
- [ ] tab line 最右,显示关闭窗口?
- [+] 像sublime安装插件的浮动窗口
- [ ] 扩展管理
- [+] vscode右侧工具按钮,文件,扩展,...
- [ ] 遵循先启动再配置的原则.
        现有的好多是先配置,有问题无法正常启动
- [ ] 应该有emacs的全局搜索,文档,代码,api
- [x] 无法获取到错误信息

### compile

v -keepc -shared .

### cmdline

- 测试时的启动命令
emacs --init-directory=./  --debug-init -l  emacs.so
emacs --init-directory=./  --debug-init -l  emacs.so --eval '(message (veclos13))'

- 正式使用, 基于chemacs2: emacs --with-profile=vemacs

emacs 命令行参数:
--with-modules ???

--quick, -Q                 equivalent to:
                              -q --no-site-file --no-site-lisp --no-splash
                              --no-x-resources
--init-directory=DIR
--directory, -L DIR     prepend DIR to load-path (with :DIR, append DIR)

--module-assertions

--debug-init

--fg-daemon[=NAME]


#### emacs client/server unix socket protocol

发送数据,仅一行,\n结束
```
-dir ~/.emacs.d/ -current-frame -eval (prin1-to-string&_server-socket-dir)
```

返回多行,
```
-emacs-pid 292272
-print "\"/run/user/1000/emacs\""
```
返回错误,
```
-emacs-pid 292272
-error "\"error&message""
```

发送的参数值quote, 空格转换为&, 返回值unquote
使用-eval参数的时候,返回结果后服务端会主动关闭连接.

支持的参数,
```
-eval
-file
-dir
-current-frame
-nowait
-position
-tty
-env
-parent-id
-frame-parameters
-window-system
-display
```

这是使用strace --write=3 捕捉到的,同时还看了 emacsclient.c的代码对照,
以及 socat -U 的测试.

#### more docs

- emacs 内搜索, apropos, info-apropos, elisp-index-search,
  只是缺少: 聚焦搜索/spotlight

- emacs四套ui, console(make-button), widget(widget-create), xwidget(native widget), webkit widgets

// float window
// Emacs里有两种实现方式，一种基于overlay，缺点是遇到Unicode或者不等宽的字符会出问题，不过支持Terminal。另一种是基于Emacs26加入的childframe机制，可以完美显示，不过不支持TUI（不过终端下的显示元素都比较单一）。

https://emacsdocs.org/docs/elisp/Window-Frame-Parameters

https://www.masteringemacs.org/article/mastering-key-bindings-emacs

https://phst.eu/emacs-modules.html


