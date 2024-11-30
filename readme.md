
### TODOS

- [+] treemacs 添加函数列表/类型列表窗口
- [+] 弹出窗口式操作
- [ ] i18n
- [ ] 中文界面,菜单/工具条提示等
- [x] 支持绑定按键
- [ ] 按键绑定尽量用两个键
- [ ] minibuffer不应该占全部宽度
- [ ] 像firefox/vscode那种tab切换,非全循环,有一种栈结构
- [ ] 滚动条的宽度
- [ ] window title bar, hide/height
- [ ] 无法获取到错误信息
- [ ] tab line 最右,显示关闭窗口?

### compile

v -keepc -shared .

### cmdline

emacs --init-directory=./  --debug-init -l  emacs.so
emacs --init-directory=./  --debug-init -l  emacs.so --eval '(message (veclos13))'

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


#### more docs

https://www.masteringemacs.org/article/mastering-key-bindings-emacs

https://phst.eu/emacs-modules.html

