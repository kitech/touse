
### TODOS

- [ ] treemacs 添加函数列表/类型列表窗口
- [ ] 弹出窗口式操作
- [ ] i18n

### compile

v -keepc -shared .

### cmdline

emacs --init-directory=./  --debug-init -l  emacs.so

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


