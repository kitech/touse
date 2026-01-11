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
添加一个从png/jpg/bmp转换为 托盘支持的 xpm格式图标的函数，注意图片尺寸不固定，需要处理，并在主函数 main 中添加参数支持指定 png/jpg/bmp文件。必须依赖 libpng 和 libjpeg外部库，不要使用stb库。

使用_NET_SYSTEM_TRAY_S0协议
XEmbed协议也受支持
StatusNotifierItem协议可用


# 编译测试程序
gcc -std=c99 -Wall -Wextra -O0 -g -o x11_tray x11tray.c -lX11 -lXft -lXrender -lXpm -DHAVE_LIBPNG -DHAVE_LIBJPEG  -lpng -ljpeg -lm -I/usr/include/freetype2/ -I/opt/vcpkg/installed/x64-linux-dynamic/include/

tcc.exe -std=c99 -Wall -Wextra -O0 -g -o x11_tray x11tray.c -lX11 -lXft -lXrender -DHAVE_LIBPNG -DHAVE_LIBJPEG  -lpng -ljpeg -lm -I/usr/include/freetype2/ -I/opt/vcpkg/installed/x64-linux-dynamic/include/ -lXpm -I ~/bprog/vlang/thirdparty/tcc/lib/tcc/include/ -L ~/bprog/vlang/thirdparty/tcc/lib/tcc/

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


### APIII  

  // ==================== 初始化和管理 ====================
  bool x11ut__tray_init(x11ut__tray_t* tray, const char* display_name);
  bool x11ut__tray_set_icon(x11ut__tray_t* tray, int width, int height, const unsigned char* data);
  bool x11ut__tray_embed(x11ut__tray_t* tray);
  bool x11ut__tray_process_events(x11ut__tray_t* tray);
  void x11ut__tray_cleanup(x11ut__tray_t* tray);
  
  // ==================== 图标相关 ====================
  bool x11ut__tray_set_icon_with_data(x11ut__tray_t* tray, int width, int height, const unsigned char* data);
  bool x11ut__tray_set_icon_from_xpm(x11ut__tray_t* tray, char** xpm_data);
  
  // ==================== 图像处理API ====================
  char** x11ut__convert_image_to_xpm(const char* input_file, int* width, int* height);
  void x11ut__free_xpm_data(char** xpm_data);
  bool x11ut__validate_xpm_data(char** xpm_data);
  
  // ==================== 图像加载API ====================
  bool x11ut__load_png(const char* filename, unsigned char** pixels, int* width, int* height);
  bool x11ut__load_jpeg(const char* filename, unsigned char** pixels, int* width, int* height);
  bool x11ut__load_bmp(const char* filename, unsigned char** pixels, int* width, int* height);
  unsigned char* x11ut__resize_image(const unsigned char* src_pixels, int src_width, int src_height, 
                                     int dest_width, int dest_height);
  
  // ==================== 菜单API ====================
  x11ut__menu_t* x11ut__menu_create(x11ut__tray_t* tray);
  bool x11ut__menu_add_item(x11ut__tray_t* tray, x11ut__menu_t* menu, const char* label, 
                           void (*callback)(void*, bool), void* user_data);
  bool x11ut__menu_add_checkable_item(x11ut__tray_t* tray, x11ut__menu_t* menu, const char* label,
                                     void (*callback)(void*, bool), void* user_data, bool initial_state);
  bool x11ut__menu_add_separator(x11ut__tray_t* tray, x11ut__menu_t* menu);
  bool x11ut__menu_set_checked(x11ut__tray_t* tray, x11ut__menu_t* menu, int index, bool checked);
  void x11ut__menu_show(x11ut__tray_t* tray, x11ut__menu_t* menu, int x, int y);
  void x11ut__menu_hide(x11ut__tray_t* tray, x11ut__menu_t* menu);
  void x11ut__menu_cleanup(x11ut__tray_t* tray, x11ut__menu_t* menu);
  
  // ==================== 工具提示API ====================
  x11ut__tooltip_t* x11ut__tooltip_create(x11ut__tray_t* tray);
  void x11ut__tooltip_show(x11ut__tray_t* tray, x11ut__tooltip_t* tooltip, const char* text, int x, int y);
  void x11ut__tooltip_hide(x11ut__tray_t* tray, x11ut__tooltip_t* tooltip);
  void x11ut__tooltip_cleanup(x11ut__tray_t* tray, x11ut__tooltip_t* tooltip);
  
  // ==================== 日志系统API ====================
  void x11ut__set_log_level(x11ut__log_level_t level);
  bool x11ut__set_log_file(const char* filename);
  void x11ut__log_cleanup(void);
  
  // ==================== 回调函数示例 ====================
  // 这些可以作为示例或直接使用
  static void x11ut__example_callback1(void* data, bool checked);
  static void x11ut__example_callback2(void* data, bool checked);
  static void x11ut__test_callback(void* data, bool checked);
  static void x11ut__settings_callback(void* data, bool checked);
  static void x11ut__toggle_callback(void* data, bool checked);
  static void x11ut__exit_callback(void* data, bool checked);
  static void x11ut__switch_language_callback(void* data, bool checked);
  static void x11ut__toggle_dark_mode_callback(void* data, bool checked);
