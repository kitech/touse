使用C99编写基于libX11 使用_NET_SYSTEM_TRAY_S0协议 的linux/bsd托盘图标程序，支持添加菜单和点击处理，
函数名加前缀 x11ut__，注意是双下划线。报告错误时同时显示调用返回的错误码和错误信息。X11有错误处理函数你查找一下。
菜单项鼠标悬停没有背景颜色变化反馈，不能正常显示中文，配色默认改为dark模式。
这一版本可以显示英文字符。再尝试菜单中的文字正常靠左对齐，不要居中。再尝试添加菜单和提示中文显示功能。
提示中文文字正常显示，菜单项中的中文文字显示为方框。
添加两个固定菜单，分别用来切换菜单中文和英文，切换dark模式。
菜单支持checkbox功能，点击可勾选菜单项会自动切换状态，并在回调函数中提供当前checked状态
整理成独立的库风格，main函数用测试宏包装起来，
添加测试参数指定中文/英文选项，是否dark模式，指定字体的功能。
生成公式API函数列表。
给这个库实现添加支持png/jpg图标的功能，并在测试用的main函数添加相应的命令行选项。

使用_NET_SYSTEM_TRAY_S0协议
XEmbed协议也受支持
StatusNotifierItem协议可用


# 编译测试程序
gcc -std=c99 -DX11UT_TEST -o x11ut_tray_test x11ut_tray.c -lX11 -lXft -lfontconfig -lXrender -DHAVE_LIBPNG -DHAVE_LIBJPEG -lpng -ljpeg -lm -I/usr/include/freetype2/

# 如果需要调试信息
gcc -std=c99 -DX11UT_TEST -g -o x11ut_tray_test x11ut_tray.c -lX11

# 编译为库（不包含测试代码）
gcc -std=c99 -fPIC -shared -o libx11ut_tray.so x11ut_tray.c -lX11


主要功能：
功能特性:
  - 支持暗色/亮色主题切换
  - 支持中英文语言切换
  - 菜单项左对齐
  - 支持checkbox菜单项
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
  - 支持checkbox，点击可切换状态
  - 支持分隔线
  - 点击菜单项后菜单自动隐藏

  
  1. 初始化和配置
  
      x11ut_create_tray() - 创建托盘实例
  
      x11ut_destroy_tray() - 销毁托盘实例
  
      x11ut_default_config() - 获取默认配置
  
  2. 托盘图标操作
  
      x11ut_set_icon() - 设置托盘图标
  
      x11ut_embed() - 嵌入到系统托盘
  
      x11ut_process_events() - 处理事件
  
  3. 运行时设置
  
      x11ut_set_dark_mode() - 设置暗色/亮色模式
  
      x11ut_set_english_mode() - 设置中英文模式
  
      x11ut_set_font() - 设置字体
  
  4. 菜单操作
  
      x11ut_create_menu() - 创建菜单
  
      x11ut_destroy_menu() - 销毁菜单
  
      x11ut_menu_add_item() - 添加菜单项
  
      x11ut_menu_add_checkable_item() - 添加可勾选菜单项
  
      x11ut_menu_add_separator() - 添加分隔线
  
      x11ut_menu_set_checked() - 设置勾选状态
  
      x11ut_menu_show() - 显示菜单
  
      x11ut_menu_hide() - 隐藏菜单
  
  5. 工具提示操作
  
      x11ut_create_tooltip() - 创建工具提示
  
      x11ut_destroy_tooltip() - 销毁工具提示
  
      x11ut_tooltip_show() - 显示工具提示
  
      x11ut_tooltip_hide() - 隐藏工具提示
  
  6. 实用函数
  
      x11ut_sleep_ms() - 毫秒级休眠
  
      x11ut_is_running() - 检查是否运行中
  
      x11ut_set_running() - 设置运行状态
  
  编译和测试
  编译库和测试程序：
  bash
  
  # 编译库
  gcc -c -fPIC x11systray.c -o x11systray.o -lX11 -lXft
  gcc -shared x11systray.o -o libx11systray.so -lX11 -lXft
  
  # 编译测试程序
  gcc test_x11systray.c -L. -lx11systray -lX11 -lXft -o test_systray
  
  # 设置库路径并运行
  export LD_LIBRARY_PATH=.:$LD_LIBRARY_PATH
  ./test_systray --help
