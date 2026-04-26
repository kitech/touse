
实现nixpkgut包，要求实现两个版本，C99+libcurl, Go


* 从 search.nixos.org 执行搜索nix包的功能模块，

参考 python 版本的实现
https://github.com/SarahhhhFoster/nix-pkg-query/blob/main/nix-pkg-query.py

```
./nix-pkg-query.py QUERY

Options

    -a, --arch : Target architecture (e.g., x86_64-linux, aarch64-darwin)
    -n, --num-results : Number of results to display (max 50)
    -p, --page : Page number for results
    -c, --channel : NixOS channel to search (default: 24.11)
    --plain : Output only package names, one per line
```

* 命令行程序，调用前的搜索模块，实现以上 Options 功能

* 实现从nix包的package.nix中计算包store path的函数

package.nix 示例，https://github.com/NixOS/nixpkgs/blob/nixos-25.11/pkgs/by-name/he/hello/package.nix

* 把这个nix-download封装为可调用库

https://github.com/simonfxr/nix-download/blob/master/main.go


nix binary cache 的下载源可以设置镜像站url。环境变量名为 NIX\_CACHE\_URL

* 最终工具命令，指定包名，搜索，列表交互选项，下载对应的二进制 .nar 包

* 目录结构，

   nixse.c
   nigse.go
   nardl.c
   nardl.go
   go.mod
   cmd/main.c
   cmd/main.go
ses_237b923b3ffeDMADYCURby3nNd
