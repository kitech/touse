#!/bin/sh

# 用于在桌面启动器打开
shdir=$(dirname $0)
cd $shdir

$shdir/mpvtk/mpvtk "$@" > $shdir/mpvtk.log 2>&1
