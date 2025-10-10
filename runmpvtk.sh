#!/bin/sh

# 用于在桌面启动器打开
shdir=$(dirname $0)
cd $shdir

# 源码数模式运行
if [ -d $shdir/mpvtk ]; then
    export LD_LIBRARY_PATH=$shdir/mpvtk
    $shdir/mpvtk/mpvtk "$@" > $shdir/mpvtk.log 2>&1
elif [ -f $shdir/mpvtk ]; then
    # 打包运行，本脚本和exe在同一个目录
    export LD_LIBRARY_PATH=$shdir
    $shdir/mpvtk "$@" > $shdir/mpvtk.log 2>&1
else
    echo "mpvtk executable not found"
fi
