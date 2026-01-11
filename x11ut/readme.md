使用C99编写基于libX11 使用_NET_SYSTEM_TRAY_S0协议 的linux/bsd托盘图标程序，支持添加菜单和点击处理，函数名加前缀 x11ut__，注意是双下划线。报告错误时同时显示调用返回的错误码和错误信息。X11有错误处理函数你查找一下。
菜单项鼠标悬停没有背景颜色变化反馈，不能正常显示中文，配色默认改为dark模式。
这一版本可以显示英文字符。再尝试菜单中的文字正常靠左对齐，不要居中。再尝试添加菜单和提示中文显示功能。
提示中文文字正常显示，菜单项中的中文文字显示为方框。
添加两个固定菜单，分别用来切换菜单中文和英文，切换dark模式。
菜单支持checkbox功能，点击可勾选菜单项会自动切换状态，并在回调函数中提供当前checked状态

使用_NET_SYSTEM_TRAY_S0协议
XEmbed协议也受支持
StatusNotifierItem协议可用



# 编译测试程序
gcc -std=c99 -DX11UT_TEST -o x11ut_tray_test x11ut_tray.c -lX11 -lXft -lfontconfig -lXrender -I/usr/include/freetype2/

# 如果需要调试信息
gcc -std=c99 -DX11UT_TEST -g -o x11ut_tray_test x11ut_tray.c -lX11

# 编译为库（不包含测试代码）
gcc -std=c99 -fPIC -shared -o libx11ut_tray.so x11ut_tray.c -lX11


主要功能：

 功能特性:
   - 暗色主题界面
   - 支持中文显示
   - 菜单项左对齐
   - 菜单项鼠标悬停效果
   - 工具提示支持
   - 分隔线支持
   - 使用Xft字体渲染，支持UTF-8
 
 鼠标悬停在托盘图标上显示工具提示
 点击托盘图标显示菜单
 菜单特性:
   - 无标题栏，真正的弹出菜单外观
   - 显示在托盘图标附近
   - 鼠标悬停有视觉反馈
   - 支持分隔线
   - 暗色主题配色
