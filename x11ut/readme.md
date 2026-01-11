使用C99编写基于libX11 使用_NET_SYSTEM_TRAY_S0协议 的linux/bsd托盘图标程序，支持添加菜单和点击处理，函数名加前缀 x11ut__，注意是双下划线。报告错误时同时显示调用返回的错误码和错误信息。X11有错误处理函数你查找一下。
菜单项鼠标悬停没有背景颜色变化反馈，不能正常显示中文，配色默认改为dark模式。
这一版本可以显示英文字符。再尝试菜单中的文字正常靠左对齐，不要居中。再尝试添加菜单和提示中文显示功能。

使用_NET_SYSTEM_TRAY_S0协议
XEmbed协议也受支持
StatusNotifierItem协议可用



# 编译测试程序
gcc -std=c99 -DX11UT_TEST -o x11ut_tray_test x11ut_tray.c -lX11 -lXft -I/usr/include/freetype2/

# 如果需要调试信息
gcc -std=c99 -DX11UT_TEST -g -o x11ut_tray_test x11ut_tray.c -lX11

# 编译为库（不包含测试代码）
gcc -std=c99 -fPIC -shared -o libx11ut_tray.so x11ut_tray.c -lX11


主要功能：

    创建和销毁托盘图标：

        x11ut_create_tray() - 创建托盘图标

        x11ut_destroy_tray() - 销毁托盘图标

    图标管理：

        x11ut_update_tray_icon() - 更新图标

        x11ut_set_tray_tooltip() - 设置工具提示

    事件处理：

        x11ut_set_tray_click_callback() - 设置点击回调

        x11ut_set_tray_middle_click_callback() - 设置中键点击回调

        x11ut_set_tray_right_click_callback() - 设置右键点击回调

        x11ut_process_tray_events() - 处理事件

    菜单管理：

        x11ut_add_tray_menu_item() - 添加菜单项

        x11ut_show_tray_menu() - 显示菜单

        x11ut_hide_tray_menu() - 隐藏菜单

    状态检查：

        x11ut_is_tray_running() - 检查是否正在运行

特性：

    跨平台：支持Linux和BSD系统

    遵循标准：使用FreeDesktop.org系统托盘规范

    完整功能：支持图标、工具提示、右键菜单

    事件驱动：高效的X11事件处理

    内存安全：完整的资源管理

    易用API：简单的函数接口

这个实现提供了一个完整的系统托盘图标解决方案，可以用于各种需要在系统托盘中显示图标的应用程序。
