#define _POSIX_C_SOURCE 199309L
#define _XOPEN_SOURCE 500

#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>
#include <X11/Xft/Xft.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <signal.h>
#include <unistd.h>
#include <time.h>
#include <locale.h>
#include <wchar.h>
#include <iconv.h>

// ==================== 日志系统 ====================

// 日志级别
typedef enum {
    X11UT_LOG_NONE = 0,    // 不显示任何日志
    X11UT_LOG_ERROR = 1,   // 只显示错误
    X11UT_LOG_WARNING = 2, // 显示错误和警告
    X11UT_LOG_INFO = 3,    // 显示错误、警告和信息（默认）
    X11UT_LOG_DEBUG = 4,   // 显示所有日志，包括调试信息
    X11UT_LOG_VERBOSE = 5  // 显示所有日志，包括详细信息
} x11ut__log_level_t;

// 全局日志级别（默认为INFO）
static x11ut__log_level_t g_x11ut_log_level = X11UT_LOG_INFO;
// 全局日志文件指针
static FILE* g_x11ut_log_file = NULL;

// 获取文件名（去掉路径）
static const char* x11ut__get_filename(const char* path) {
    const char* filename = strrchr(path, '/');
    return filename ? filename + 1 : path;
}

// 日志函数（内部使用）
static void x11ut__log_internal(x11ut__log_level_t level, const char* file, int line, const char* format, ...) {
    // 如果请求的日志级别高于当前设置的级别，则不输出
    if (level > g_x11ut_log_level) {
        return;
    }
    
    // 获取当前时间
    time_t now;
    struct tm* tm_info;
    char time_buffer[20];
    
    time(&now);
    tm_info = localtime(&now);
    strftime(time_buffer, sizeof(time_buffer), "%H:%M:%S", tm_info);
    
    // 日志级别名称
    const char* level_name;
    switch(level) {
        case X11UT_LOG_ERROR:   level_name = "ERROR"; break;
        case X11UT_LOG_WARNING: level_name = "WARNING"; break;
        case X11UT_LOG_INFO:    level_name = "INFO"; break;
        case X11UT_LOG_DEBUG:   level_name = "DEBUG"; break;
        case X11UT_LOG_VERBOSE: level_name = "VERBOSE"; break;
        default:                level_name = "UNKNOWN"; break;
    }
    
    // 确定输出目标
    FILE* output = stdout;
    if (level == X11UT_LOG_ERROR || level == X11UT_LOG_WARNING) {
        output = stderr;
    }
    
    // 输出日志头（时间、级别、文件、行号）
    fprintf(output, "[%s] [%-7s] %s:%d: ", 
            time_buffer, level_name, x11ut__get_filename(file), line);
    
    // 输出日志内容
    va_list args;
    va_start(args, format);
    vfprintf(output, format, args);
    va_end(args);
    
    fprintf(output, "\n");
    fflush(output);
    
    // 如果启用了日志文件，也输出到文件
    if (g_x11ut_log_file) {
        fprintf(g_x11ut_log_file, "[%s] [%-7s] %s:%d: ", 
                time_buffer, level_name, x11ut__get_filename(file), line);
        va_start(args, format);
        vfprintf(g_x11ut_log_file, format, args);
        va_end(args);
        fprintf(g_x11ut_log_file, "\n");
        fflush(g_x11ut_log_file);
    }
}

// 日志宏（包含文件行数）
#define X11UT_LOG_ERROR(...)    x11ut__log_internal(X11UT_LOG_ERROR, __FILE__, __LINE__, __VA_ARGS__)
#define X11UT_LOG_WARNING(...)  x11ut__log_internal(X11UT_LOG_WARNING, __FILE__, __LINE__, __VA_ARGS__)
#define X11UT_LOG_INFO(...)     x11ut__log_internal(X11UT_LOG_INFO, __FILE__, __LINE__, __VA_ARGS__)
#define X11UT_LOG_DEBUG(...)    x11ut__log_internal(X11UT_LOG_DEBUG, __FILE__, __LINE__, __VA_ARGS__)
#define X11UT_LOG_VERBOSE(...)  x11ut__log_internal(X11UT_LOG_VERBOSE, __FILE__, __LINE__, __VA_ARGS__)

// 设置日志级别
static void x11ut__set_log_level(x11ut__log_level_t level) {
    g_x11ut_log_level = level;
    X11UT_LOG_INFO("设置日志级别为: %d", level);
}

// 解析日志级别字符串
static x11ut__log_level_t x11ut__parse_log_level(const char* level_str) {
    if (strcmp(level_str, "none") == 0 || strcmp(level_str, "NONE") == 0) {
        return X11UT_LOG_NONE;
    } else if (strcmp(level_str, "error") == 0 || strcmp(level_str, "ERROR") == 0) {
        return X11UT_LOG_ERROR;
    } else if (strcmp(level_str, "warning") == 0 || strcmp(level_str, "WARNING") == 0) {
        return X11UT_LOG_WARNING;
    } else if (strcmp(level_str, "info") == 0 || strcmp(level_str, "INFO") == 0) {
        return X11UT_LOG_INFO;
    } else if (strcmp(level_str, "debug") == 0 || strcmp(level_str, "DEBUG") == 0) {
        return X11UT_LOG_DEBUG;
    } else if (strcmp(level_str, "verbose") == 0 || strcmp(level_str, "VERBOSE") == 0) {
        return X11UT_LOG_VERBOSE;
    } else {
        // 尝试解析数字
        int level = atoi(level_str);
        if (level >= X11UT_LOG_NONE && level <= X11UT_LOG_VERBOSE) {
            return (x11ut__log_level_t)level;
        }
        return X11UT_LOG_INFO; // 默认
    }
}

// 设置日志文件
static bool x11ut__set_log_file(const char* filename) {
    if (g_x11ut_log_file) {
        fclose(g_x11ut_log_file);
        g_x11ut_log_file = NULL;
    }
    
    if (filename) {
        g_x11ut_log_file = fopen(filename, "a");
        if (!g_x11ut_log_file) {
            X11UT_LOG_ERROR("无法打开日志文件: %s", filename);
            return false;
        }
        X11UT_LOG_INFO("日志将保存到文件: %s", filename);
    }
    
    return true;
}

// 清理日志系统
static void x11ut__log_cleanup(void) {
    if (g_x11ut_log_file) {
        X11UT_LOG_INFO("关闭日志文件");
        fclose(g_x11ut_log_file);
        g_x11ut_log_file = NULL;
    }
}

// ==================== 错误处理 ====================

// X11错误处理函数
static int x11ut__error_handler(Display* display, XErrorEvent* error) {
    char error_text[256];
    XGetErrorText(display, error->error_code, error_text, sizeof(error_text));
    X11UT_LOG_ERROR("X11错误 [代码: %d, 请求: %d, 小代码: %d]: %s",
                    error->error_code, error->request_code, error->minor_code, error_text);
    return 0;
}

// ==================== 类型定义 ====================

// 菜单项结构
typedef struct x11ut__menu_item {
    char* label;
    char* utf8_label;  // UTF-8编码的标签
    void (*callback)(void*, bool);  // 回调函数，第二个参数是checked状态
    void* user_data;
    bool is_separator;  // 是否是分隔线
    bool is_checkable;  // 是否可勾选
    bool checked;       // 是否已勾选
    struct x11ut__menu_item* next;
} x11ut__menu_item_t;

// 工具提示结构
typedef struct {
    Window window;
    char* text;
    XftFont* font;
    XftDraw* draw;
    XftColor color;
    Pixmap pixmap;
    bool visible;
    int width;
    int height;
    int padding;
} x11ut__tooltip_t;

// 菜单结构
typedef struct {
    x11ut__menu_item_t* items;
    int item_count;
    Window window;
    bool visible;
    int width;
    int height;
    int item_height;
    int hover_index;     // 当前鼠标悬停的菜单项索引
    XftFont* font;       // Xft字体
    XftDraw* draw;       // Xft绘制上下文
    XftColor fg_color;   // 前景色
    XftColor hover_fg_color; // 悬停前景色
    XftColor check_color;    // checkbox颜色
    GC hover_gc;         // 悬停图形上下文
    GC separator_gc;     // 分隔线图形上下文
    GC border_gc;        // 边框图形上下文
    GC check_gc;         // checkbox图形上下文
} x11ut__menu_t;

// 颜色结构（支持暗色和亮色主题）
typedef struct {
    unsigned long bg_color;        // 背景色
    unsigned long fg_color;        // 前景色（文本）
    unsigned long border_color;    // 边框色
    unsigned long hover_bg_color;  // 悬停背景色
    unsigned long hover_fg_color;  // 悬停前景色
    unsigned long separator_color; // 分隔线颜色
    unsigned long check_bg_color;  // checkbox背景色
    unsigned long check_fg_color;  // checkbox前景色
    unsigned long check_border_color; // checkbox边框色
} x11ut__colors_t;

// 托盘图标结构
typedef struct {
    Display* display;
    int screen;
    Visual* visual;
    Colormap colormap;
    Window window;
    Window tray_window;
    GC gc;
    Pixmap icon_pixmap;
    
    // 原子
    Atom net_system_tray_s0;
    Atom net_system_tray_opcode;
    Atom net_wm_window_type_dock;
    Atom net_wm_window_type_menu;
    Atom net_wm_state_skip_taskbar;
    Atom net_wm_window_type_tooltip;
    Atom xembed_info;
    
    // 状态
    bool embedded;
    bool running;
    
    // 菜单
    x11ut__menu_t* menu;
    
    // 工具提示
    x11ut__tooltip_t* tooltip;
    
    // 图标尺寸
    int icon_width;
    int icon_height;
    
    // 颜色
    x11ut__colors_t colors;
    
    // 应用状态
    bool dark_mode;      // 当前是否为暗色模式
    bool english_mode;   // 当前是否为英文模式
} x11ut__tray_t;

// ==================== 函数声明 ====================

// 初始化函数
bool x11ut__tray_init(x11ut__tray_t* tray, const char* display_name);
bool x11ut__tray_set_icon(x11ut__tray_t* tray, int width, int height, const unsigned char* data);
bool x11ut__tray_embed(x11ut__tray_t* tray);

// 事件处理
bool x11ut__tray_process_events(x11ut__tray_t* tray);

// 菜单函数
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

// 工具提示函数
x11ut__tooltip_t* x11ut__tooltip_create(x11ut__tray_t* tray);
void x11ut__tooltip_show(x11ut__tray_t* tray, x11ut__tooltip_t* tooltip, const char* text, int x, int y);
void x11ut__tooltip_hide(x11ut__tray_t* tray, x11ut__tooltip_t* tooltip);
void x11ut__tooltip_cleanup(x11ut__tray_t* tray, x11ut__tooltip_t* tooltip);

// 工具函数
void x11ut__tray_cleanup(x11ut__tray_t* tray);
static void x11ut__draw_default_icon(x11ut__tray_t* tray);
static void x11ut__msleep(long milliseconds);
static void x11ut__init_colors(x11ut__tray_t* tray);
static bool x11ut__load_font(x11ut__tray_t* tray, x11ut__menu_t* menu, const char* font_name);

// 绘制函数声明
static void x11ut__menu_draw(x11ut__tray_t* tray, x11ut__menu_t* menu);

// 创建菜单函数声明
static void x11ut__create_menu(x11ut__tray_t* tray);

// ==================== 辅助函数 ====================

// 自定义 strdup
static char* x11ut__strdup(const char* s) {
    if (!s) return NULL;
    size_t len = strlen(s) + 1;
    char* copy = malloc(len);
    if (copy) {
        memcpy(copy, s, len);
    }
    return copy;
}

// 转换颜色值
static unsigned long x11ut__rgb_to_color(x11ut__tray_t* tray, int r, int g, int b) {
    return (r << 16) | (g << 8) | b;
}

// 初始化颜色（支持暗色和亮色主题）
static void x11ut__init_colors(x11ut__tray_t* tray) {
    if (tray->dark_mode) {
        // 暗色主题颜色
        tray->colors.bg_color = x11ut__rgb_to_color(tray, 45, 45, 45);        // #2D2D2D
        tray->colors.fg_color = x11ut__rgb_to_color(tray, 224, 224, 224);     // #E0E0E0
        tray->colors.border_color = x11ut__rgb_to_color(tray, 68, 68, 68);    // #444444
        tray->colors.hover_bg_color = x11ut__rgb_to_color(tray, 58, 58, 58);  // #3A3A3A
        tray->colors.hover_fg_color = x11ut__rgb_to_color(tray, 255, 255, 255); // #FFFFFF
        tray->colors.separator_color = x11ut__rgb_to_color(tray, 68, 68, 68); // #444444
        tray->colors.check_bg_color = x11ut__rgb_to_color(tray, 70, 70, 70);  // checkbox背景
        tray->colors.check_fg_color = x11ut__rgb_to_color(tray, 0, 200, 0);   // checkbox勾选颜色
        tray->colors.check_border_color = x11ut__rgb_to_color(tray, 100, 100, 100); // checkbox边框
    } else {
        // 亮色主题颜色
        tray->colors.bg_color = x11ut__rgb_to_color(tray, 255, 255, 255);     // #FFFFFF
        tray->colors.fg_color = x11ut__rgb_to_color(tray, 0, 0, 0);           // #000000
        tray->colors.border_color = x11ut__rgb_to_color(tray, 200, 200, 200); // #C8C8C8
        tray->colors.hover_bg_color = x11ut__rgb_to_color(tray, 240, 240, 240); // #F0F0F0
        tray->colors.hover_fg_color = x11ut__rgb_to_color(tray, 0, 0, 0);     // #000000
        tray->colors.separator_color = x11ut__rgb_to_color(tray, 200, 200, 200); // #C8C8C8
        tray->colors.check_bg_color = x11ut__rgb_to_color(tray, 245, 245, 245); // checkbox背景
        tray->colors.check_fg_color = x11ut__rgb_to_color(tray, 0, 150, 0);   // checkbox勾选颜色
        tray->colors.check_border_color = x11ut__rgb_to_color(tray, 180, 180, 180); // checkbox边框
    }
}

// ==================== 初始化函数 ====================

// 初始化托盘
bool x11ut__tray_init(x11ut__tray_t* tray, const char* display_name) {
    // 设置区域设置以支持中文
    setlocale(LC_ALL, "");
    
    // 设置错误处理
    XSetErrorHandler(x11ut__error_handler);
    
    // 打开显示
    tray->display = XOpenDisplay(display_name);
    if (!tray->display) {
        X11UT_LOG_ERROR("无法打开X显示连接");
        return false;
    }
    
    tray->screen = DefaultScreen(tray->display);
    tray->visual = DefaultVisual(tray->display, tray->screen);
    tray->colormap = DefaultColormap(tray->display, tray->screen);
    tray->icon_width = 24;
    tray->icon_height = 24;
    tray->running = true;
    tray->embedded = false;
    tray->dark_mode = true;     // 默认暗色模式
    tray->english_mode = false; // 默认中文模式
    
    // 初始化颜色
    x11ut__init_colors(tray);
    
    // 获取原子
    tray->net_system_tray_s0 = XInternAtom(tray->display, "_NET_SYSTEM_TRAY_S0", False);
    tray->net_system_tray_opcode = XInternAtom(tray->display, "_NET_SYSTEM_TRAY_OPCODE", False);
    tray->net_wm_window_type_dock = XInternAtom(tray->display, "_NET_WM_WINDOW_TYPE_DOCK", False);
    tray->net_wm_window_type_menu = XInternAtom(tray->display, "_NET_WM_WINDOW_TYPE_MENU", False);
    tray->net_wm_state_skip_taskbar = XInternAtom(tray->display, "_NET_WM_STATE_SKIP_TASKBAR", False);
    tray->net_wm_window_type_tooltip = XInternAtom(tray->display, "_NET_WM_WINDOW_TYPE_TOOLTIP", False);
    tray->xembed_info = XInternAtom(tray->display, "_XEMBED_INFO", False);
    
    // 创建颜色映射
    XColor bg_color, fg_color, border_color, hover_bg_color, hover_fg_color, separator_color;
    XColor check_bg_color, check_fg_color, check_border_color;
    
    // 背景色
    if (tray->dark_mode) {
        bg_color.red = 45 * 256;
        bg_color.green = 45 * 256;
        bg_color.blue = 45 * 256;
    } else {
        bg_color.red = 255 * 256;
        bg_color.green = 255 * 256;
        bg_color.blue = 255 * 256;
    }
    bg_color.flags = DoRed | DoGreen | DoBlue;
    XAllocColor(tray->display, tray->colormap, &bg_color);
    tray->colors.bg_color = bg_color.pixel;
    
    // 前景色
    if (tray->dark_mode) {
        fg_color.red = 224 * 256;
        fg_color.green = 224 * 256;
        fg_color.blue = 224 * 256;
    } else {
        fg_color.red = 0;
        fg_color.green = 0;
        fg_color.blue = 0;
    }
    fg_color.flags = DoRed | DoGreen | DoBlue;
    XAllocColor(tray->display, tray->colormap, &fg_color);
    tray->colors.fg_color = fg_color.pixel;
    
    // 边框色
    if (tray->dark_mode) {
        border_color.red = 68 * 256;
        border_color.green = 68 * 256;
        border_color.blue = 68 * 256;
    } else {
        border_color.red = 200 * 256;
        border_color.green = 200 * 256;
        border_color.blue = 200 * 256;
    }
    border_color.flags = DoRed | DoGreen | DoBlue;
    XAllocColor(tray->display, tray->colormap, &border_color);
    tray->colors.border_color = border_color.pixel;
    
    // 悬停背景色
    if (tray->dark_mode) {
        hover_bg_color.red = 58 * 256;
        hover_bg_color.green = 58 * 256;
        hover_bg_color.blue = 58 * 256;
    } else {
        hover_bg_color.red = 240 * 256;
        hover_bg_color.green = 240 * 256;
        hover_bg_color.blue = 240 * 256;
    }
    hover_bg_color.flags = DoRed | DoGreen | DoBlue;
    XAllocColor(tray->display, tray->colormap, &hover_bg_color);
    tray->colors.hover_bg_color = hover_bg_color.pixel;
    
    // 悬停前景色
    if (tray->dark_mode) {
        hover_fg_color.red = 255 * 256;
        hover_fg_color.green = 255 * 256;
        hover_fg_color.blue = 255 * 256;
    } else {
        hover_fg_color.red = 0;
        hover_fg_color.green = 0;
        hover_fg_color.blue = 0;
    }
    hover_fg_color.flags = DoRed | DoGreen | DoBlue;
    XAllocColor(tray->display, tray->colormap, &hover_fg_color);
    tray->colors.hover_fg_color = hover_fg_color.pixel;
    
    // 分隔线颜色
    if (tray->dark_mode) {
        separator_color.red = 68 * 256;
        separator_color.green = 68 * 256;
        separator_color.blue = 68 * 256;
    } else {
        separator_color.red = 200 * 256;
        separator_color.green = 200 * 256;
        separator_color.blue = 200 * 256;
    }
    separator_color.flags = DoRed | DoGreen | DoBlue;
    XAllocColor(tray->display, tray->colormap, &separator_color);
    tray->colors.separator_color = separator_color.pixel;
    
    // checkbox背景色
    if (tray->dark_mode) {
        check_bg_color.red = 70 * 256;
        check_bg_color.green = 70 * 256;
        check_bg_color.blue = 70 * 256;
    } else {
        check_bg_color.red = 245 * 256;
        check_bg_color.green = 245 * 256;
        check_bg_color.blue = 245 * 256;
    }
    check_bg_color.flags = DoRed | DoGreen | DoBlue;
    XAllocColor(tray->display, tray->colormap, &check_bg_color);
    tray->colors.check_bg_color = check_bg_color.pixel;
    
    // checkbox勾选颜色
    if (tray->dark_mode) {
        check_fg_color.red = 0;
        check_fg_color.green = 200 * 256;
        check_fg_color.blue = 0;
    } else {
        check_fg_color.red = 0;
        check_fg_color.green = 150 * 256;
        check_fg_color.blue = 0;
    }
    check_fg_color.flags = DoRed | DoGreen | DoBlue;
    XAllocColor(tray->display, tray->colormap, &check_fg_color);
    tray->colors.check_fg_color = check_fg_color.pixel;
    
    // checkbox边框色
    if (tray->dark_mode) {
        check_border_color.red = 100 * 256;
        check_border_color.green = 100 * 256;
        check_border_color.blue = 100 * 256;
    } else {
        check_border_color.red = 180 * 256;
        check_border_color.green = 180 * 256;
        check_border_color.blue = 180 * 256;
    }
    check_border_color.flags = DoRed | DoGreen | DoBlue;
    XAllocColor(tray->display, tray->colormap, &check_border_color);
    tray->colors.check_border_color = check_border_color.pixel;
    
    // 创建窗口
    Window root = RootWindow(tray->display, tray->screen);
    tray->window = XCreateSimpleWindow(tray->display, root,
                                       0, 0, tray->icon_width, tray->icon_height,
                                       0, 
                                       tray->colors.border_color,  // 边框颜色
                                       tray->colors.bg_color);     // 背景颜色
    
    if (!tray->window) {
        X11UT_LOG_ERROR("无法创建窗口");
        XCloseDisplay(tray->display);
        return false;
    }
    
    // 选择输入事件
    XSelectInput(tray->display, tray->window,
                 ExposureMask | ButtonPressMask | ButtonReleaseMask |
                 StructureNotifyMask | EnterWindowMask | LeaveWindowMask);
    
    // 设置窗口属性
    XSizeHints hints;
    hints.flags = PMinSize | PMaxSize;
    hints.min_width = hints.max_width = tray->icon_width;
    hints.min_height = hints.max_height = tray->icon_height;
    XSetWMNormalHints(tray->display, tray->window, &hints);
    
    // 设置窗口类型
    Atom window_type = XInternAtom(tray->display, "_NET_WM_WINDOW_TYPE", False);
    Atom dock_atom = tray->net_wm_window_type_dock;
    XChangeProperty(tray->display, tray->window, window_type,
                   XA_ATOM, 32, PropModeReplace,
                   (unsigned char*)&dock_atom, 1);
    
    // 设置窗口状态
    Atom state = XInternAtom(tray->display, "_NET_WM_STATE", False);
    XChangeProperty(tray->display, tray->window, state,
                   XA_ATOM, 32, PropModeReplace,
                   (unsigned char*)&tray->net_wm_state_skip_taskbar, 1);
    
    // 设置XEmbed信息
    long xembed_info[2] = {0, 0};
    XChangeProperty(tray->display, tray->window, tray->xembed_info,
                   XA_CARDINAL, 32, PropModeReplace,
                   (unsigned char*)xembed_info, 2);
    
    // 创建图形上下文
    XGCValues gc_vals;
    gc_vals.foreground = tray->colors.fg_color;
    gc_vals.background = tray->colors.bg_color;
    gc_vals.line_width = 1;
    
    tray->gc = XCreateGC(tray->display, tray->window, 
                        GCForeground | GCBackground | GCLineWidth, &gc_vals);
    if (!tray->gc) {
        X11UT_LOG_ERROR("无法创建图形上下文");
        XDestroyWindow(tray->display, tray->window);
        XCloseDisplay(tray->display);
        return false;
    }
    
    // 创建图标pixmap
    tray->icon_pixmap = XCreatePixmap(tray->display, tray->window,
                                     tray->icon_width, tray->icon_height,
                                     DefaultDepth(tray->display, tray->screen));
    
    // 绘制默认图标
    x11ut__draw_default_icon(tray);
    
    X11UT_LOG_INFO("托盘初始化成功，窗口ID: 0x%lx", tray->window);
    return true;
}

// 绘制默认图标

// ==================== 图标生成和绘制函数 ====================

// 生成默认图标数据
static unsigned char* x11ut__generate_default_icon(x11ut__tray_t* tray, int* width, int* height) {
    if (!tray) return NULL;
    
    // 默认图标尺寸
    int icon_width = 24;
    int icon_height = 24;
    
    // 计算行字节对齐（通常是4字节对齐）
    int row_stride = (icon_width * 3 + 3) & ~3;
    
    // 分配内存存储像素数据（RGB格式）
    unsigned char* pixels = malloc(row_stride * icon_height);
    if (!pixels) {
        X11UT_LOG_ERROR("无法分配图标像素内存");
        return NULL;
    }
    
    X11UT_LOG_DEBUG("生成默认图标数据: %dx%d", icon_width, icon_height);
    
    // 清空像素数据
    memset(pixels, 0, row_stride * icon_height);
    
    // 获取颜色分量（用于RGB像素）
    unsigned char bg_r, bg_g, bg_b;
    unsigned char fg_r, fg_g, fg_b;
    
    if (tray->dark_mode) {
        // 暗色主题
        bg_r = 45;   // #2D2D2D
        bg_g = 45;
        bg_b = 45;
        fg_r = 224;  // #E0E0E0
        fg_g = 224;
        fg_b = 224;
    } else {
        // 亮色主题
        bg_r = 255;  // #FFFFFF
        bg_g = 255;
        bg_b = 255;
        fg_r = 0;    // #000000
        fg_g = 0;
        fg_b = 0;
    }
    
    // 填充背景色
    for (int y = 0; y < icon_height; y++) {
        for (int x = 0; x < icon_width; x++) {
            int offset = y * row_stride + x * 3;
            pixels[offset] = bg_r;     // R
            pixels[offset + 1] = bg_g; // G
            pixels[offset + 2] = bg_b; // B
        }
    }
    
    // 绘制边框
    for (int x = 0; x < icon_width; x++) {
        // 顶部边框
        int offset = 0 * row_stride + x * 3;
        pixels[offset] = fg_r;
        pixels[offset + 1] = fg_g;
        pixels[offset + 2] = fg_b;
        
        // 底部边框
        offset = (icon_height - 1) * row_stride + x * 3;
        pixels[offset] = fg_r;
        pixels[offset + 1] = fg_g;
        pixels[offset + 2] = fg_b;
    }
    
    for (int y = 0; y < icon_height; y++) {
        // 左侧边框
        int offset = y * row_stride + 0 * 3;
        pixels[offset] = fg_r;
        pixels[offset + 1] = fg_g;
        pixels[offset + 2] = fg_b;
        
        // 右侧边框
        offset = y * row_stride + (icon_width - 1) * 3;
        pixels[offset] = fg_r;
        pixels[offset + 1] = fg_g;
        pixels[offset + 2] = fg_b;
    }
    
    // 绘制图标内容（三条线，类似菜单图标）
    int center_x = icon_width / 2;
    int center_y = icon_height / 2;
    
    // 顶部横线
    for (int x = center_x - 6; x <= center_x + 6; x++) {
        int y = center_y - 3;
        int offset = y * row_stride + x * 3;
        if (offset >= 0 && offset < row_stride * icon_height - 2) {
            pixels[offset] = fg_r;
            pixels[offset + 1] = fg_g;
            pixels[offset + 2] = fg_b;
        }
    }
    
    // 中间横线
    for (int x = center_x - 6; x <= center_x + 6; x++) {
        int y = center_y;
        int offset = y * row_stride + x * 3;
        if (offset >= 0 && offset < row_stride * icon_height - 2) {
            pixels[offset] = fg_r;
            pixels[offset + 1] = fg_g;
            pixels[offset + 2] = fg_b;
        }
    }
    
    // 底部横线
    for (int x = center_x - 6; x <= center_x + 6; x++) {
        int y = center_y + 3;
        int offset = y * row_stride + x * 3;
        if (offset >= 0 && offset < row_stride * icon_height - 2) {
            pixels[offset] = fg_r;
            pixels[offset + 1] = fg_g;
            pixels[offset + 2] = fg_b;
        }
    }
    
    // 返回生成的尺寸
    if (width) *width = icon_width;
    if (height) *height = icon_height;
    
    return pixels;
}

// 使用X11绘制默认图标（调用生成函数并绘制）
static void x11ut__draw_default_icon(x11ut__tray_t* tray) {
    if (!tray || !tray->display) return;
    
    X11UT_LOG_DEBUG("绘制默认图标");
    
    // 生成图标数据
    int icon_width, icon_height;
    unsigned char* pixels = x11ut__generate_default_icon(tray, &icon_width, &icon_height);
    
    if (!pixels) {
        X11UT_LOG_ERROR("无法生成图标数据");
        return;
    }
    
    // 创建图像
    XImage* image = XCreateImage(tray->display, tray->visual,
                                DefaultDepth(tray->display, tray->screen),
                                ZPixmap, 0, (char*)pixels,
                                icon_width, icon_height,
                                8, 0);
    
    if (!image) {
        X11UT_LOG_ERROR("无法创建XImage");
        free(pixels);
        return;
    }
    
    // 计算行字节对齐（与生成时一致）
    int row_stride = (icon_width * 3 + 3) & ~3;
    image->bytes_per_line = row_stride;
    
    // 设置正确的字节序
    image->byte_order = MSBFirst;
    image->bitmap_bit_order = MSBFirst;
    
    // 重新配置窗口大小
    if (icon_width != tray->icon_width || icon_height != tray->icon_height) {
        tray->icon_width = icon_width;
        tray->icon_height = icon_height;
        XResizeWindow(tray->display, tray->window, icon_width, icon_height);
    }
    
    // 释放旧的pixmap
    if (tray->icon_pixmap) {
        XFreePixmap(tray->display, tray->icon_pixmap);
    }
    
    // 创建新的pixmap
    tray->icon_pixmap = XCreatePixmap(tray->display, tray->window,
                                     icon_width, icon_height,
                                     DefaultDepth(tray->display, tray->screen));
    
    // 将图像复制到pixmap
    XPutImage(tray->display, tray->icon_pixmap, tray->gc, image,
              0, 0, 0, 0, icon_width, icon_height);
    
    // 设置窗口背景
    XSetWindowBackgroundPixmap(tray->display, tray->window, tray->icon_pixmap);
    XClearWindow(tray->display, tray->window);
    
    // 清理资源
    image->data = NULL; // 防止XDestroyImage释放我们的像素数据
    XDestroyImage(image);
    free(pixels);
    
    X11UT_LOG_DEBUG("默认图标绘制完成，尺寸: %dx%d", icon_width, icon_height);
}

// 创建一个简单的测试图标（可选，用于测试）
static unsigned char* x11ut__generate_test_icon(x11ut__tray_t* tray, int width, int height) {
    if (!tray || width <= 0 || height <= 0) return NULL;
    
    X11UT_LOG_DEBUG("生成测试图标: %dx%d", width, height);
    
    int row_stride = (width * 3 + 3) & ~3;
    unsigned char* pixels = malloc(row_stride * height);
    if (!pixels) {
        X11UT_LOG_ERROR("无法分配测试图标内存");
        return NULL;
    }
    
    // 获取颜色分量
    unsigned char bg_r, bg_g, bg_b;
    unsigned char fg_r, fg_g, fg_b;
    
    if (tray->dark_mode) {
        // 暗色主题
        bg_r = 30;   // 深灰色背景
        bg_g = 30;
        bg_b = 30;
        fg_r = 200;  // 亮灰色前景
        fg_g = 200;
        fg_b = 200;
    } else {
        // 亮色主题
        bg_r = 240;  // 浅灰色背景
        bg_g = 240;
        bg_b = 240;
        fg_r = 60;   // 深灰色前景
        fg_g = 60;
        fg_b = 60;
    }
    
    // 填充背景色
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            int offset = y * row_stride + x * 3;
            pixels[offset] = bg_r;
            pixels[offset + 1] = bg_g;
            pixels[offset + 2] = bg_b;
        }
    }
    
    // 绘制一个简单的圆形
    int center_x = width / 2;
    int center_y = height / 2;
    int radius = width / 3;
    
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            int dx = x - center_x;
            int dy = y - center_y;
            int distance_squared = dx * dx + dy * dy;
            
            if (distance_squared <= radius * radius) {
                int offset = y * row_stride + x * 3;
                pixels[offset] = fg_r;
                pixels[offset + 1] = fg_g;
                pixels[offset + 2] = fg_b;
            }
        }
    }
    
    return pixels;
}

// 使用指定数据设置图标
bool x11ut__tray_set_icon_with_data(x11ut__tray_t* tray, int width, int height, const unsigned char* data) {
    if (!tray || !tray->display || !data || width <= 0 || height <= 0) {
        X11UT_LOG_ERROR("无效的图标参数");
        return false;
    }
    
    tray->icon_width = width;
    tray->icon_height = height;
    
    X11UT_LOG_DEBUG("设置自定义图标，尺寸: %dx%d", width, height);
    
    // 重新配置窗口
    XResizeWindow(tray->display, tray->window, width, height);
    
    // 释放旧的pixmap
    if (tray->icon_pixmap) {
        XFreePixmap(tray->display, tray->icon_pixmap);
    }
    
    // 创建新的pixmap
    tray->icon_pixmap = XCreatePixmap(tray->display, tray->window,
                                     width, height,
                                     DefaultDepth(tray->display, tray->screen));
    
    // 创建图像
    int row_stride = (width * 3 + 3) & ~3;
    XImage* image = XCreateImage(tray->display, tray->visual,
                                DefaultDepth(tray->display, tray->screen),
                                ZPixmap, 0, (char*)data,
                                width, height,
                                8, 0);
    
    if (!image) {
        X11UT_LOG_ERROR("无法创建XImage");
        XFreePixmap(tray->display, tray->icon_pixmap);
        tray->icon_pixmap = 0;
        return false;
    }
    
    image->bytes_per_line = row_stride;
    image->byte_order = MSBFirst;
    image->bitmap_bit_order = MSBFirst;
    
    // 将图像复制到pixmap
    XPutImage(tray->display, tray->icon_pixmap, tray->gc, image,
              0, 0, 0, 0, width, height);
    
    // 设置窗口背景
    XSetWindowBackgroundPixmap(tray->display, tray->window, tray->icon_pixmap);
    XClearWindow(tray->display, tray->window);
    
    // 清理资源
    image->data = NULL; // 防止XDestroyImage释放我们的数据
    XDestroyImage(image);
    
    XFlush(tray->display);
    X11UT_LOG_DEBUG("自定义图标设置成功");
    return true;
}

// 设置图标（兼容旧接口）
bool x11ut__tray_set_icon(x11ut__tray_t* tray, int width, int height, const unsigned char* data) {
    if (!tray || !tray->display) return false;
    
    if (data) {
        // 使用提供的数据
        return x11ut__tray_set_icon_with_data(tray, width, height, data);
    } else {
        // 使用默认图标
        tray->icon_width = width;
        tray->icon_height = height;
        
        // 重新绘制默认图标
        x11ut__draw_default_icon(tray);
        
        XFlush(tray->display);
        X11UT_LOG_DEBUG("设置默认图标，尺寸: %dx%d", width, height);
        return true;
    }
}

// 嵌入到系统托盘
bool x11ut__tray_embed(x11ut__tray_t* tray) {
    if (!tray || !tray->display) return false;
    
    X11UT_LOG_INFO("查找系统托盘...");
    
    // 获取系统托盘窗口
    tray->tray_window = XGetSelectionOwner(tray->display, tray->net_system_tray_s0);
    
    if (tray->tray_window == None) {
        X11UT_LOG_WARNING("未找到系统托盘，将在普通窗口中显示");
        XMapWindow(tray->display, tray->window);
        XFlush(tray->display);
        return false;
    }
    
    X11UT_LOG_INFO("找到系统托盘窗口: 0x%lx", tray->tray_window);
    
    // 发送嵌入消息
    XClientMessageEvent ev;
    memset(&ev, 0, sizeof(ev));
    
    ev.type = ClientMessage;
    ev.window = tray->tray_window;
    ev.message_type = tray->net_system_tray_opcode;
    ev.format = 32;
    ev.data.l[0] = CurrentTime;
    ev.data.l[1] = 0;  // SYSTEM_TRAY_REQUEST_DOCK
    ev.data.l[2] = tray->window;
    
    // 直接发送事件，不检查错误
    XSendEvent(tray->display, tray->tray_window, False, NoEventMask, (XEvent*)&ev);
    XFlush(tray->display);
    
    X11UT_LOG_INFO("已发送嵌入请求");
    
    // 等待一下然后映射窗口
    x11ut__msleep(100);
    XMapWindow(tray->display, tray->window);
    XFlush(tray->display);
    
    tray->embedded = true;
    X11UT_LOG_INFO("窗口已映射");
    
    return true;
}

// ==================== 菜单函数 ====================

// 加载字体（支持中文）
static bool x11ut__load_font(x11ut__tray_t* tray, x11ut__menu_t* menu, const char* font_name) {
    if (!tray || !tray->display || !menu) return false;
    
    // 如果指定了字体名，尝试加载
    if (font_name) {
        menu->font = XftFontOpenName(tray->display, tray->screen, font_name);
        if (menu->font) {
            X11UT_LOG_DEBUG("成功加载指定字体: %s", font_name);
            
            // 初始化颜色
            XRenderColor render_color;
            if (tray->dark_mode) {
                render_color.red = 224 * 256;   // #E0E0E0
                render_color.green = 224 * 256;
                render_color.blue = 224 * 256;
            } else {
                render_color.red = 0;           // #000000
                render_color.green = 0;
                render_color.blue = 0;
            }
            render_color.alpha = 0xffff;
            XftColorAllocValue(tray->display, tray->visual, tray->colormap, 
                              &render_color, &menu->fg_color);
            
            if (tray->dark_mode) {
                render_color.red = 255 * 256;   // #FFFFFF
                render_color.green = 255 * 256;
                render_color.blue = 255 * 256;
            } else {
                render_color.red = 0;           // #000000
                render_color.green = 0;
                render_color.blue = 0;
            }
            render_color.alpha = 0xffff;
            XftColorAllocValue(tray->display, tray->visual, tray->colormap, 
                              &render_color, &menu->hover_fg_color);
            
            render_color.red = 0;           // 绿色勾选
            render_color.green = 200 * 256;
            render_color.blue = 0;
            render_color.alpha = 0xffff;
            XftColorAllocValue(tray->display, tray->visual, tray->colormap, 
                              &render_color, &menu->check_color);
            
            return true;
        }
    }
    
    // 尝试加载中文字体
    const char* font_names[] = {
        "WenQuanYi Micro Hei:size=12",           // 文泉驿微米黑
        "Noto Sans CJK SC:size=12",             // Noto中文字体
        "DejaVu Sans:size=12",                  // DejaVu
        "Sans:size=12",                         // 通用无衬线字体
        "fixed:size=12",                        // 固定字体
        NULL
    };
    
    // 尝试加载字体
    for (int i = 0; font_names[i] != NULL; i++) {
        menu->font = XftFontOpenName(tray->display, tray->screen, font_names[i]);
        if (menu->font) {
            X11UT_LOG_DEBUG("成功加载字体: %s", font_names[i]);
            
            // 初始化颜色
            XRenderColor render_color;
            if (tray->dark_mode) {
                render_color.red = 224 * 256;   // #E0E0E0
                render_color.green = 224 * 256;
                render_color.blue = 224 * 256;
            } else {
                render_color.red = 0;           // #000000
                render_color.green = 0;
                render_color.blue = 0;
            }
            render_color.alpha = 0xffff;
            XftColorAllocValue(tray->display, tray->visual, tray->colormap, 
                              &render_color, &menu->fg_color);
            
            if (tray->dark_mode) {
                render_color.red = 255 * 256;   // #FFFFFF
                render_color.green = 255 * 256;
                render_color.blue = 255 * 256;
            } else {
                render_color.red = 0;           // #000000
                render_color.green = 0;
                render_color.blue = 0;
            }
            render_color.alpha = 0xffff;
            XftColorAllocValue(tray->display, tray->visual, tray->colormap, 
                              &render_color, &menu->hover_fg_color);
            
            render_color.red = 0;           // 绿色勾选
            render_color.green = 200 * 256;
            render_color.blue = 0;
            render_color.alpha = 0xffff;
            XftColorAllocValue(tray->display, tray->visual, tray->colormap, 
                              &render_color, &menu->check_color);
            
            return true;
        }
    }
    
    X11UT_LOG_ERROR("无法加载任何字体");
    return false;
}

// 创建菜单
x11ut__menu_t* x11ut__menu_create(x11ut__tray_t* tray) {
    if (!tray || !tray->display) return NULL;
    
    x11ut__menu_t* menu = malloc(sizeof(x11ut__menu_t));
    if (!menu) return NULL;
    
    memset(menu, 0, sizeof(x11ut__menu_t));
    menu->item_height = 30;  // 稍高以容纳中文
    menu->width = 220;       // 稍宽以容纳中英文
    menu->hover_index = -1;  // 初始无悬停
    
    // 加载字体，优先尝试中文字体
    const char* chinese_fonts[] = {
        "WenQuanYi Micro Hei:size=12",
        "Noto Sans CJK SC:size=12",
        "DejaVu Sans:size=12",
        "Sans:size=12",
        NULL
    };
    
    bool font_loaded = false;
    for (int i = 0; chinese_fonts[i] != NULL; i++) {
        if (x11ut__load_font(tray, menu, chinese_fonts[i])) {
            font_loaded = true;
            break;
        }
    }
    
    if (!font_loaded) {
        free(menu);
        return NULL;
    }
    
    // 创建菜单窗口属性
    XSetWindowAttributes attrs;
    attrs.override_redirect = True;  // 重要：使菜单窗口跳过窗口管理器
    attrs.background_pixel = tray->colors.bg_color;
    attrs.border_pixel = tray->colors.border_color;
    attrs.event_mask = ExposureMask | ButtonPressMask | ButtonReleaseMask |
                       LeaveWindowMask | FocusChangeMask | PointerMotionMask |
                       EnterWindowMask;  // 添加鼠标进入事件
    
    // 创建菜单窗口
    menu->window = XCreateWindow(tray->display,
                                 RootWindow(tray->display, tray->screen),
                                 0, 0, menu->width, 100,
                                 1,  // 边框宽度
                                 CopyFromParent,  // 深度
                                 InputOutput,     // 类
                                 CopyFromParent,  // 视觉
                                 CWOverrideRedirect | CWBackPixel | 
                                 CWBorderPixel | CWEventMask,
                                 &attrs);
    
    if (!menu->window) {
        if (menu->font) XftFontClose(tray->display, menu->font);
        free(menu);
        X11UT_LOG_ERROR("无法创建菜单窗口");
        return NULL;
    }
    
    // 创建Xft绘制上下文
    menu->draw = XftDrawCreate(tray->display, menu->window,
                              tray->visual, tray->colormap);
    
    // 创建图形上下文
    XGCValues gc_vals;
    
    // 悬停图形上下文
    gc_vals.foreground = tray->colors.hover_bg_color;
    gc_vals.background = tray->colors.bg_color;
    menu->hover_gc = XCreateGC(tray->display, menu->window,
                              GCForeground | GCBackground, &gc_vals);
    
    // 分隔线图形上下文
    gc_vals.foreground = tray->colors.separator_color;
    gc_vals.background = tray->colors.bg_color;
    gc_vals.line_width = 1;
    menu->separator_gc = XCreateGC(tray->display, menu->window,
                                  GCForeground | GCBackground | GCLineWidth, &gc_vals);
    
    // 边框图形上下文
    gc_vals.foreground = tray->colors.border_color;
    gc_vals.background = tray->colors.bg_color;
    gc_vals.line_width = 1;
    menu->border_gc = XCreateGC(tray->display, menu->window,
                               GCForeground | GCBackground | GCLineWidth, &gc_vals);
    
    // checkbox图形上下文
    gc_vals.foreground = tray->colors.check_fg_color;
    gc_vals.background = tray->colors.check_bg_color;
    gc_vals.line_width = 1;
    menu->check_gc = XCreateGC(tray->display, menu->window,
                              GCForeground | GCBackground | GCLineWidth, &gc_vals);
    
    // 设置窗口类型为菜单
    Atom window_type = XInternAtom(tray->display, "_NET_WM_WINDOW_TYPE", False);
    XChangeProperty(tray->display, menu->window, window_type,
                   XA_ATOM, 32, PropModeReplace,
                   (unsigned char*)&tray->net_wm_window_type_menu, 1);
    
    X11UT_LOG_DEBUG("创建菜单成功，窗口ID: 0x%lx", menu->window);
    return menu;
}

// 添加普通菜单项
bool x11ut__menu_add_item(x11ut__tray_t* tray, x11ut__menu_t* menu, 
                         const char* label, void (*callback)(void*, bool), 
                         void* user_data) {
    if (!menu || !label) return false;
    
    x11ut__menu_item_t* item = malloc(sizeof(x11ut__menu_item_t));
    if (!item) return false;
    
    // 存储UTF-8标签
    item->utf8_label = x11ut__strdup(label);
    item->label = x11ut__strdup(label);  // 直接复制，假设已经是UTF-8
    
    item->callback = callback;
    item->user_data = user_data;
    item->is_separator = false;
    item->is_checkable = false;
    item->checked = false;
    item->next = NULL;
    
    // 添加到链表
    if (!menu->items) {
        menu->items = item;
    } else {
        x11ut__menu_item_t* last = menu->items;
        while (last->next) last = last->next;
        last->next = item;
    }
    
    menu->item_count++;
    menu->height = menu->item_count * menu->item_height + 10;
    
    // 更新菜单宽度（基于最长标签）
    if (menu->font) {
        XGlyphInfo extents;
        XftTextExtentsUtf8(tray->display, menu->font, 
                          (const FcChar8*)item->utf8_label, 
                          strlen(item->utf8_label), &extents);
        
        // 为checkbox预留空间（即使不是checkable，也要预留空间以保持对齐）
        int needed_width = extents.width + 45; // 左边距15 + checkbox宽度15 + 间距5 + 右边距10
        if (needed_width > menu->width) {
            menu->width = needed_width;
        }
    }
    
    X11UT_LOG_DEBUG("添加菜单项: %s", label);
    return true;
}

// 添加可勾选菜单项
bool x11ut__menu_add_checkable_item(x11ut__tray_t* tray, x11ut__menu_t* menu, const char* label,
                                   void (*callback)(void*, bool), void* user_data, bool initial_state) {
    if (!menu || !label) return false;
    
    x11ut__menu_item_t* item = malloc(sizeof(x11ut__menu_item_t));
    if (!item) return false;
    
    // 存储UTF-8标签
    item->utf8_label = x11ut__strdup(label);
    item->label = x11ut__strdup(label);  // 直接复制，假设已经是UTF-8
    
    item->callback = callback;
    item->user_data = user_data;
    item->is_separator = false;
    item->is_checkable = true;
    item->checked = initial_state;
    item->next = NULL;
    
    // 添加到链表
    if (!menu->items) {
        menu->items = item;
    } else {
        x11ut__menu_item_t* last = menu->items;
        while (last->next) last = last->next;
        last->next = item;
    }
    
    menu->item_count++;
    menu->height = menu->item_count * menu->item_height + 10;
    
    // 更新菜单宽度（基于最长标签）
    if (menu->font) {
        XGlyphInfo extents;
        XftTextExtentsUtf8(tray->display, menu->font, 
                          (const FcChar8*)item->utf8_label, 
                          strlen(item->utf8_label), &extents);
        
        // 为checkbox预留空间
        int needed_width = extents.width + 45; // 左边距15 + checkbox宽度15 + 间距5 + 右边距10
        if (needed_width > menu->width) {
            menu->width = needed_width;
        }
    }
    
    X11UT_LOG_DEBUG("添加可勾选菜单项: %s (初始状态: %s)", label, initial_state ? "勾选" : "未勾选");
    return true;
}

// 设置菜单项勾选状态
bool x11ut__menu_set_checked(x11ut__tray_t* tray, x11ut__menu_t* menu, int index, bool checked) {
    if (!menu || index < 0 || index >= menu->item_count) return false;
    
    // 找到对应的菜单项
    x11ut__menu_item_t* item = menu->items;
    int current_index = 0;
    
    while (item && current_index < index) {
        item = item->next;
        current_index++;
    }
    
    if (!item || !item->is_checkable) return false;
    
    // 更新状态
    item->checked = checked;
    
    // 如果菜单可见，重新绘制
    if (menu->visible) {
        x11ut__menu_draw(tray, menu);
    }
    
    X11UT_LOG_DEBUG("设置菜单项 %d 勾选状态为: %s", index, checked ? "勾选" : "未勾选");
    return true;
}

// 添加分隔线
bool x11ut__menu_add_separator(x11ut__tray_t* tray, x11ut__menu_t* menu) {
    if (!menu) return false;
    
    // 标记未使用的参数
    (void)tray;
    
    x11ut__menu_item_t* item = malloc(sizeof(x11ut__menu_item_t));
    if (!item) return false;
    
    item->label = NULL;
    item->utf8_label = NULL;
    item->callback = NULL;
    item->user_data = NULL;
    item->is_separator = true;
    item->is_checkable = false;
    item->checked = false;
    item->next = NULL;
    
    // 添加到链表
    if (!menu->items) {
        menu->items = item;
    } else {
        x11ut__menu_item_t* last = menu->items;
        while (last->next) last = last->next;
        last->next = item;
    }
    
    menu->item_count++;
    menu->height = menu->item_count * menu->item_height + 10;
    
    X11UT_LOG_DEBUG("添加菜单分隔线");
    return true;
}

// 绘制菜单
static void x11ut__menu_draw(x11ut__tray_t* tray, x11ut__menu_t* menu) {
    if (!tray || !tray->display || !menu || !menu->window) return;
    
    X11UT_LOG_VERBOSE("绘制菜单");
    
    // 创建临时GC用于背景和边框
    XGCValues gc_vals;
    gc_vals.foreground = tray->colors.bg_color;
    gc_vals.background = tray->colors.bg_color;
    GC bg_gc = XCreateGC(tray->display, menu->window, 
                        GCForeground | GCBackground, &gc_vals);
    
    // 清除背景
    XSetForeground(tray->display, bg_gc, tray->colors.bg_color);
    XFillRectangle(tray->display, menu->window, bg_gc, 0, 0, menu->width, menu->height);
    
    // 绘制菜单项
    x11ut__menu_item_t* item = menu->items;
    int y = 5;
    int item_index = 0;
    
    while (item) {
        if (item->is_separator) {
            // 绘制分隔线
            XDrawLine(tray->display, menu->window, menu->separator_gc, 
                      10, y + menu->item_height/2, 
                      menu->width - 10, y + menu->item_height/2);
        } else {
            // 检查是否是悬停项
            bool is_hover = (item_index == menu->hover_index);
            
            // 绘制背景（如果是悬停项）
            if (is_hover) {
                XFillRectangle(tray->display, menu->window, menu->hover_gc, 
                               1, y, menu->width - 2, menu->item_height);
            }
            
            // 绘制checkbox（如果可勾选）
            if (item->is_checkable) {
                int check_x = 10;
                int check_y = y + 7;
                int check_size = 16;
                
                // 绘制checkbox边框
                XSetForeground(tray->display, menu->check_gc, tray->colors.check_border_color);
                XDrawRectangle(tray->display, menu->window, menu->check_gc,
                              check_x, check_y, check_size, check_size);
                
                // 绘制checkbox背景
                XSetForeground(tray->display, menu->check_gc, tray->colors.check_bg_color);
                XFillRectangle(tray->display, menu->window, menu->check_gc,
                              check_x + 1, check_y + 1, check_size - 2, check_size - 2);
                
                // 如果已勾选，绘制勾选标记
                if (item->checked) {
                    // 绘制对勾
                    XSetForeground(tray->display, menu->check_gc, tray->colors.check_fg_color);
                    XDrawLine(tray->display, menu->window, menu->check_gc,
                             check_x + 3, check_y + 9,
                             check_x + 7, check_y + 13);
                    XDrawLine(tray->display, menu->window, menu->check_gc,
                             check_x + 7, check_y + 13,
                             check_x + 13, check_y + 5);
                }
            }
            
            // 绘制文本（左对齐）
            if (item->utf8_label && menu->font) {
                int text_x = item->is_checkable ? 35 : 15;  // 如果有checkbox，文本向右偏移
                int text_y = y + menu->item_height/2 + 5;
                
                // 使用适当的颜色绘制文本
                XftColor* color = is_hover ? &menu->hover_fg_color : &menu->fg_color;
                XftDrawStringUtf8(menu->draw, color, menu->font,
                                 text_x, text_y,
                                 (const FcChar8*)item->utf8_label,
                                 strlen(item->utf8_label));
            }
        }
        
        y += menu->item_height;
        item_index++;
        item = item->next;
    }
    
    // 绘制边框
    XDrawRectangle(tray->display, menu->window, menu->border_gc, 
                   0, 0, menu->width - 1, menu->height - 1);
    
    XFreeGC(tray->display, bg_gc);
}

// 显示菜单
void x11ut__menu_show(x11ut__tray_t* tray, x11ut__menu_t* menu, int x, int y) {
    if (!tray || !tray->display || !menu || !menu->window) return;
    
    // 重置悬停索引
    menu->hover_index = -1;
    
    // 获取屏幕尺寸
    int screen_width = DisplayWidth(tray->display, tray->screen);
    int screen_height = DisplayHeight(tray->display, tray->screen);
    
    // 调整菜单位置
    int menu_x = x;
    int menu_y = y;
    
    // 如果点击位置太靠右，向左调整
    if (menu_x + menu->width > screen_width) {
        menu_x = screen_width - menu->width - 10;
    }
    
    // 如果点击位置太靠下，向上调整
    if (menu_y + menu->height > screen_height) {
        menu_y = screen_height - menu->height - 10;
    }
    
    // 如果点击位置太靠左，向右调整
    if (menu_x < 10) {
        menu_x = 10;
    }
    
    // 如果点击位置太靠上，向下调整
    if (menu_y < 10) {
        menu_y = 10;
    }
    
    X11UT_LOG_DEBUG("显示菜单于位置: (%d, %d)", menu_x, menu_y);
    
    // 移动和调整大小
    XMoveResizeWindow(tray->display, menu->window, menu_x, menu_y, 
                     menu->width, menu->height);
    
    // 绘制菜单
    x11ut__menu_draw(tray, menu);
    
    // 映射窗口
    XMapWindow(tray->display, menu->window);
    XRaiseWindow(tray->display, menu->window);
    
    // 获取输入焦点
    XSetInputFocus(tray->display, menu->window, RevertToParent, CurrentTime);
    
    menu->visible = true;
    XFlush(tray->display);
}

// 隐藏菜单
void x11ut__menu_hide(x11ut__tray_t* tray, x11ut__menu_t* menu) {
    if (!tray || !tray->display || !menu || !menu->window || !menu->visible) return;
    
    XUnmapWindow(tray->display, menu->window);
    menu->visible = false;
    menu->hover_index = -1;  // 重置悬停索引
    X11UT_LOG_DEBUG("隐藏菜单");
    XFlush(tray->display);
}

// 处理菜单点击
static void x11ut__handle_menu_click(x11ut__tray_t* tray, x11ut__menu_t* menu, int x, int y) {
    if (!menu || !menu->visible) return;
    
    // 计算点击的菜单项
    int item_index = (y - 5) / menu->item_height;
    if (item_index < 0 || item_index >= menu->item_count) {
        // 点击了菜单外区域，隐藏菜单
        x11ut__menu_hide(tray, menu);
        return;
    }
    
    // 找到对应的菜单项
    x11ut__menu_item_t* item = menu->items;
    int current_index = 0;
    
    while (item && current_index < item_index) {
        item = item->next;
        current_index++;
    }
    
    // 如果是分隔线，忽略点击
    if (!item || item->is_separator) {
        x11ut__menu_hide(tray, menu);
        return;
    }
    
    // 如果是可勾选菜单项，切换勾选状态
    if (item->is_checkable) {
        item->checked = !item->checked;
    }
    
    // 调用回调函数
    if (item->callback) {
        X11UT_LOG_DEBUG("点击菜单项: %s (checked: %s)", 
                        item->utf8_label ? item->utf8_label : item->label,
                        item->checked ? "true" : "false");
        item->callback(item->user_data, item->checked);
    }
    
    // 重新绘制菜单以显示新的勾选状态
    x11ut__menu_draw(tray, menu);
    
    // 所有菜单项点击后都隐藏菜单
    x11ut__menu_hide(tray, menu);
}

// 更新菜单悬停状态
static void x11ut__update_menu_hover(x11ut__tray_t* tray, x11ut__menu_t* menu, int x, int y) {
    if (!menu || !menu->visible) return;
    
    // 计算鼠标所在的菜单项索引
    int item_index = (y - 5) / menu->item_height;
    
    // 检查索引是否有效
    if (item_index < 0 || item_index >= menu->item_count) {
        // 鼠标在菜单项之外
        if (menu->hover_index != -1) {
            menu->hover_index = -1;
            x11ut__menu_draw(tray, menu);
        }
        return;
    }
    
    // 检查这个索引是否是分隔线
    x11ut__menu_item_t* item = menu->items;
    int current_index = 0;
    
    while (item && current_index < item_index) {
        item = item->next;
        current_index++;
    }
    
    // 如果是分隔线，不显示悬停效果
    if (item && item->is_separator) {
        if (menu->hover_index != -1) {
            menu->hover_index = -1;
            x11ut__menu_draw(tray, menu);
        }
        return;
    }
    
    // 如果悬停状态改变，重新绘制菜单
    if (menu->hover_index != item_index) {
        menu->hover_index = item_index;
        x11ut__menu_draw(tray, menu);
        X11UT_LOG_VERBOSE("菜单悬停项: %d", item_index);
    }
}

// 清理菜单
void x11ut__menu_cleanup(x11ut__tray_t* tray, x11ut__menu_t* menu) {
    if (!menu) return;
    
    X11UT_LOG_DEBUG("清理菜单资源");
    
    if (tray && tray->display && menu->window) {
        x11ut__menu_hide(tray, menu);
        
        // 释放资源
        if (menu->draw) XftDrawDestroy(menu->draw);
        if (menu->font) XftFontClose(tray->display, menu->font);
        if (menu->fg_color.pixel) XftColorFree(tray->display, tray->visual, 
                                               tray->colormap, &menu->fg_color);
        if (menu->hover_fg_color.pixel) XftColorFree(tray->display, tray->visual, 
                                                     tray->colormap, &menu->hover_fg_color);
        if (menu->check_color.pixel) XftColorFree(tray->display, tray->visual, 
                                                  tray->colormap, &menu->check_color);
        if (menu->hover_gc) XFreeGC(tray->display, menu->hover_gc);
        if (menu->separator_gc) XFreeGC(tray->display, menu->separator_gc);
        if (menu->border_gc) XFreeGC(tray->display, menu->border_gc);
        if (menu->check_gc) XFreeGC(tray->display, menu->check_gc);
        
        XDestroyWindow(tray->display, menu->window);
    }
    
    x11ut__menu_item_t* item = menu->items;
    while (item) {
        x11ut__menu_item_t* next = item->next;
        if (item->label) free(item->label);
        if (item->utf8_label) free(item->utf8_label);
        free(item);
        item = next;
    }
    
    free(menu);
}

// ==================== 工具提示函数 ====================

// 创建工具提示
x11ut__tooltip_t* x11ut__tooltip_create(x11ut__tray_t* tray) {
    if (!tray || !tray->display) return NULL;
    
    x11ut__tooltip_t* tooltip = malloc(sizeof(x11ut__tooltip_t));
    if (!tooltip) return NULL;
    
    memset(tooltip, 0, sizeof(x11ut__tooltip_t));
    tooltip->padding = 10;
    
    // 尝试加载字体，优先使用菜单的字体
    if (tray->menu && tray->menu->font) {
        tooltip->font = tray->menu->font;
    } else {
        // 尝试加载中文字体
        const char* font_names[] = {
            "WenQuanYi Micro Hei:size=10",
            "Noto Sans CJK SC:size=10",
            "DejaVu Sans:size=10",
            "Sans:size=10",
            "fixed:size=10",
            NULL
        };
        
        for (int i = 0; font_names[i] != NULL; i++) {
            tooltip->font = XftFontOpenName(tray->display, tray->screen, font_names[i]);
            if (tooltip->font) {
                X11UT_LOG_DEBUG("工具提示字体: %s", font_names[i]);
                break;
            }
        }
    }
    
    if (!tooltip->font) {
        free(tooltip);
        return NULL;
    }
    
    // 初始化颜色
    XRenderColor render_color;
    if (tray->dark_mode) {
        render_color.red = 224 * 256;   // #E0E0E0
        render_color.green = 224 * 256;
        render_color.blue = 224 * 256;
    } else {
        render_color.red = 0;           // #000000
        render_color.green = 0;
        render_color.blue = 0;
    }
    render_color.alpha = 0xffff;
    XftColorAllocValue(tray->display, tray->visual, tray->colormap, 
                      &render_color, &tooltip->color);
    
    // 创建工具提示窗口属性
    XSetWindowAttributes attrs;
    attrs.override_redirect = True;
    attrs.background_pixel = tray->colors.bg_color;
    attrs.border_pixel = tray->colors.border_color;
    attrs.event_mask = ExposureMask;
    
    // 创建工具提示窗口
    tooltip->window = XCreateWindow(tray->display,
                                   RootWindow(tray->display, tray->screen),
                                   0, 0, 100, 50,
                                   1,  // 边框宽度
                                   CopyFromParent,
                                   InputOutput,
                                   CopyFromParent,
                                   CWOverrideRedirect | CWBackPixel | 
                                   CWBorderPixel | CWEventMask,
                                   &attrs);
    
    if (!tooltip->window) {
        // 注意：如果字体是从菜单借用的，不要关闭它
        if (tooltip->font != tray->menu->font) {
            XftFontClose(tray->display, tooltip->font);
        }
        XftColorFree(tray->display, tray->visual, tray->colormap, &tooltip->color);
        free(tooltip);
        X11UT_LOG_ERROR("无法创建工具提示窗口");
        return NULL;
    }
    
    // 创建Xft绘制上下文
    tooltip->draw = XftDrawCreate(tray->display, tooltip->window,
                                 tray->visual, tray->colormap);
    
    // 设置窗口类型为工具提示
    Atom window_type = XInternAtom(tray->display, "_NET_WM_WINDOW_TYPE", False);
    XChangeProperty(tray->display, tooltip->window, window_type,
                   XA_ATOM, 32, PropModeReplace,
                   (unsigned char*)&tray->net_wm_window_type_tooltip, 1);
    
    X11UT_LOG_DEBUG("创建工具提示成功，窗口ID: 0x%lx", tooltip->window);
    return tooltip;
}

// 显示工具提示
void x11ut__tooltip_show(x11ut__tray_t* tray, x11ut__tooltip_t* tooltip, 
                        const char* text, int x, int y) {
    if (!tray || !tray->display || !tooltip || !text) return;
    
    // 设置文本
    if (tooltip->text) free(tooltip->text);
    tooltip->text = x11ut__strdup(text);
    
    // 计算文本尺寸
    if (tooltip->font) {
        XGlyphInfo extents;
        XftTextExtentsUtf8(tray->display, tooltip->font, 
                          (const FcChar8*)tooltip->text, 
                          strlen(tooltip->text), &extents);
        
        tooltip->width = extents.width + tooltip->padding * 2;
        tooltip->height = extents.height + tooltip->padding * 2;
        
        // 调整位置
        int screen_width = DisplayWidth(tray->display, tray->screen);
        int screen_height = DisplayHeight(tray->display, tray->screen);
        
        // 默认显示在鼠标右下方
        int tip_x = x + 10;
        int tip_y = y + 10;
        
        // 如果太靠右，向左调整
        if (tip_x + tooltip->width > screen_width) {
            tip_x = x - tooltip->width - 10;
        }
        
        // 如果太靠下，向上调整
        if (tip_y + tooltip->height > screen_height) {
            tip_y = y - tooltip->height - 10;
        }
        
        // 确保在屏幕内
        if (tip_x < 10) tip_x = 10;
        if (tip_y < 10) tip_y = 10;
        
        // 移动和调整大小
        XMoveResizeWindow(tray->display, tooltip->window, tip_x, tip_y,
                         tooltip->width, tooltip->height);
        
        // 绘制工具提示
        if (tooltip->pixmap) {
            XFreePixmap(tray->display, tooltip->pixmap);
        }
        
        tooltip->pixmap = XCreatePixmap(tray->display, tooltip->window,
                                       tooltip->width, tooltip->height,
                                       DefaultDepth(tray->display, tray->screen));
        
        // 创建临时GC
        XGCValues gc_vals;
        gc_vals.foreground = tray->colors.bg_color;
        gc_vals.background = tray->colors.bg_color;
        GC bg_gc = XCreateGC(tray->display, tooltip->window, 
                            GCForeground | GCBackground, &gc_vals);
        
        // 绘制背景
        XSetForeground(tray->display, bg_gc, tray->colors.bg_color);
        XFillRectangle(tray->display, tooltip->pixmap, bg_gc, 
                      0, 0, tooltip->width, tooltip->height);
        
        // 绘制边框
        XSetForeground(tray->display, bg_gc, tray->colors.border_color);
        XDrawRectangle(tray->display, tooltip->pixmap, bg_gc, 
                      0, 0, tooltip->width - 1, tooltip->height - 1);
        
        XFreeGC(tray->display, bg_gc);
        
        // 设置窗口背景
        XSetWindowBackgroundPixmap(tray->display, tooltip->window, tooltip->pixmap);
        
        // 映射窗口
        XMapWindow(tray->display, tooltip->window);
        tooltip->visible = true;
        
        // 绘制文本
        XClearWindow(tray->display, tooltip->window);
        
        int text_x = tooltip->padding;
        int text_y = tooltip->padding + tooltip->font->ascent;
        
        XftDrawStringUtf8(tooltip->draw, &tooltip->color, tooltip->font,
                         text_x, text_y,
                         (const FcChar8*)tooltip->text,
                         strlen(tooltip->text));
        
        XFlush(tray->display);
        X11UT_LOG_DEBUG("显示工具提示: %s", text);
    }
}

// 隐藏工具提示
void x11ut__tooltip_hide(x11ut__tray_t* tray, x11ut__tooltip_t* tooltip) {
    if (!tray || !tray->display || !tooltip || !tooltip->visible) return;
    
    XUnmapWindow(tray->display, tooltip->window);
    tooltip->visible = false;
    X11UT_LOG_VERBOSE("隐藏工具提示");
    XFlush(tray->display);
}

// 清理工具提示
void x11ut__tooltip_cleanup(x11ut__tray_t* tray, x11ut__tooltip_t* tooltip) {
    if (!tooltip) return;
    
    X11UT_LOG_DEBUG("清理工具提示资源");
    
    if (tray && tray->display && tooltip->window) {
        x11ut__tooltip_hide(tray, tooltip);
        
        // 释放资源
        if (tooltip->draw) XftDrawDestroy(tooltip->draw);
        // 如果字体是从菜单借用的，不要关闭它
        if (tooltip->font && (!tray->menu || tooltip->font != tray->menu->font)) {
            XftFontClose(tray->display, tooltip->font);
        }
        if (tooltip->color.pixel) XftColorFree(tray->display, tray->visual, 
                                               tray->colormap, &tooltip->color);
        if (tooltip->pixmap) XFreePixmap(tray->display, tooltip->pixmap);
        
        XDestroyWindow(tray->display, tooltip->window);
    }
    
    if (tooltip->text) free(tooltip->text);
    free(tooltip);
}

// ==================== 事件处理 ====================

// 处理事件
bool x11ut__tray_process_events(x11ut__tray_t* tray) {
    if (!tray || !tray->display) return false;
    
    while (XPending(tray->display) > 0) {
        XEvent event;
        XNextEvent(tray->display, &event);
        
        switch (event.type) {
            case Expose:
                if (event.xexpose.window == tray->window) {
                    XCopyArea(tray->display, tray->icon_pixmap, tray->window, tray->gc,
                              0, 0, tray->icon_width, tray->icon_height, 0, 0);
                    X11UT_LOG_VERBOSE("重绘托盘图标");
                } else if (tray->menu && event.xexpose.window == tray->menu->window) {
                    x11ut__menu_draw(tray, tray->menu);
                    X11UT_LOG_VERBOSE("重绘菜单");
                } else if (tray->tooltip && event.xexpose.window == tray->tooltip->window) {
                    // 重新绘制工具提示
                    if (tray->tooltip->text && tray->tooltip->font) {
                        int text_x = tray->tooltip->padding;
                        int text_y = tray->tooltip->padding + tray->tooltip->font->ascent;
                        
                        XftDrawStringUtf8(tray->tooltip->draw, &tray->tooltip->color, 
                                         tray->tooltip->font,
                                         text_x, text_y,
                                         (const FcChar8*)tray->tooltip->text,
                                         strlen(tray->tooltip->text));
                    }
                    X11UT_LOG_VERBOSE("重绘工具提示");
                }
                break;
                
            case ButtonPress:
                if (event.xbutton.window == tray->window) {
                    X11UT_LOG_DEBUG("托盘图标被点击 (位置: %d, %d)", 
                                   event.xbutton.x_root, event.xbutton.y_root);
                    if (tray->menu) {
                        x11ut__menu_show(tray, tray->menu, 
                                       event.xbutton.x_root, 
                                       event.xbutton.y_root);
                    }
                } else if (tray->menu && event.xbutton.window == tray->menu->window) {
                    x11ut__handle_menu_click(tray, tray->menu, 
                                           event.xbutton.x, 
                                           event.xbutton.y);
                }
                break;
                
            case MotionNotify:
                // 鼠标移动事件
                if (tray->menu && event.xmotion.window == tray->menu->window) {
                    x11ut__update_menu_hover(tray, tray->menu, 
                                           event.xmotion.x, 
                                           event.xmotion.y);
                }
                break;
                
            case EnterNotify:
                // 鼠标进入托盘图标
                if (event.xcrossing.window == tray->window) {
                    if (tray->tooltip) {
                        // 显示工具提示（根据当前语言）
                        if (tray->english_mode) {
                            x11ut__tooltip_show(tray, tray->tooltip, 
                                              "System Tray Icon\nClick to show menu",
                                              event.xcrossing.x_root,
                                              event.xcrossing.y_root);
                        } else {
                            x11ut__tooltip_show(tray, tray->tooltip, 
                                              "系统托盘图标\n点击显示菜单",
                                              event.xcrossing.x_root,
                                              event.xcrossing.y_root);
                        }
                    }
                }
                break;
                
            case LeaveNotify:
                // 鼠标离开托盘图标
                if (event.xcrossing.window == tray->window) {
                    if (tray->tooltip) {
                        x11ut__tooltip_hide(tray, tray->tooltip);
                    }
                }
                // 鼠标离开菜单窗口
                else if (tray->menu && event.xcrossing.window == tray->menu->window) {
                    // 检查鼠标是否真的离开了菜单区域
                    Window root, child;
                    int root_x, root_y, win_x, win_y;
                    unsigned int mask;
                    
                    XQueryPointer(tray->display, tray->menu->window,
                                 &root, &child, &root_x, &root_y,
                                 &win_x, &win_y, &mask);
                    
                    if (win_x < 0 || win_x >= tray->menu->width ||
                        win_y < 0 || win_y >= tray->menu->height) {
                        x11ut__msleep(100);
                        x11ut__menu_hide(tray, tray->menu);
                    }
                }
                break;
                
            case FocusOut:
                // 当菜单失去焦点时隐藏
                if (tray->menu && event.xfocus.window == tray->menu->window) {
                    x11ut__msleep(50);
                    x11ut__menu_hide(tray, tray->menu);
                }
                break;
                
            case DestroyNotify:
                if (event.xdestroywindow.window == tray->window) {
                    X11UT_LOG_INFO("托盘窗口被销毁");
                    tray->running = false;
                }
                break;
                
            case ClientMessage:
                if (event.xclient.message_type == tray->net_system_tray_opcode) {
                    X11UT_LOG_DEBUG("收到系统托盘消息");
                }
                break;
        }
    }
    
    return true;
}

// ==================== 工具函数 ====================

// 休眠函数
static void x11ut__msleep(long milliseconds) {
    struct timespec ts;
    ts.tv_sec = milliseconds / 1000;
    ts.tv_nsec = (milliseconds % 1000) * 1000000;
    nanosleep(&ts, NULL);
}

// 清理资源
void x11ut__tray_cleanup(x11ut__tray_t* tray) {
    if (!tray) return;
    
    X11UT_LOG_INFO("清理托盘资源");
    
    if (tray->display) {
        // 清理菜单
        if (tray->menu) {
            x11ut__menu_cleanup(tray, tray->menu);
        }
        
        // 清理工具提示
        if (tray->tooltip) {
            x11ut__tooltip_cleanup(tray, tray->tooltip);
        }
        
        // 清理资源
        if (tray->gc) XFreeGC(tray->display, tray->gc);
        if (tray->icon_pixmap) XFreePixmap(tray->display, tray->icon_pixmap);
        if (tray->window) XDestroyWindow(tray->display, tray->window);
        
        XCloseDisplay(tray->display);
    }
    
    memset(tray, 0, sizeof(x11ut__tray_t));
}

// ==================== 示例回调函数 ====================

static void x11ut__example_callback1(void* data, bool checked) {
    X11UT_LOG_INFO("选项1被点击: %s (checked: %s)", (char*)data, checked ? "true" : "false");
}

static void x11ut__example_callback2(void* data, bool checked) {
    X11UT_LOG_INFO("选项2被点击 (checked: %s)", checked ? "true" : "false");
}

static void x11ut__test_callback(void* data, bool checked) {
    X11UT_LOG_INFO("测试功能被点击 (checked: %s)", checked ? "true" : "false");
}

static void x11ut__settings_callback(void* data, bool checked) {
    X11UT_LOG_INFO("设置被点击 (checked: %s)", checked ? "true" : "false");
}

static void x11ut__toggle_callback(void* data, bool checked) {
    X11UT_LOG_INFO("切换功能: %s", checked ? "启用" : "禁用");
    
    // 这里可以执行实际的启用/禁用操作
    if (checked) {
        X11UT_LOG_DEBUG("功能已启用");
    } else {
        X11UT_LOG_DEBUG("功能已禁用");
    }
}

static void x11ut__exit_callback(void* data, bool checked) {
    x11ut__tray_t* tray = (x11ut__tray_t*)data;
    if (tray) {
        X11UT_LOG_INFO("退出程序 (checked: %s)", checked ? "true" : "false");
        tray->running = false;
    }
}

// ==================== 语言和主题切换回调函数 ====================

// 切换语言回调函数
static void x11ut__switch_language_callback(void* data, bool checked) {
    x11ut__tray_t* tray = (x11ut__tray_t*)data;
    if (!tray) return;
    
    // 切换语言模式
    tray->english_mode = !tray->english_mode;
    
    if (tray->english_mode) {
        X11UT_LOG_INFO("已切换到英文模式");
    } else {
        X11UT_LOG_INFO("已切换到中文模式");
    }
    
    // 重新创建菜单（使用新的语言）
    if (tray->menu) {
        // 先清理旧菜单
        x11ut__menu_cleanup(tray, tray->menu);
        tray->menu = NULL;
        
        // 创建新菜单
        x11ut__create_menu(tray);
    }
}

// 切换主题回调函数
static void x11ut__toggle_dark_mode_callback(void* data, bool checked) {
    x11ut__tray_t* tray = (x11ut__tray_t*)data;
    if (!tray) return;
    
    // 切换主题模式
    tray->dark_mode = !tray->dark_mode;
    
    if (tray->dark_mode) {
        X11UT_LOG_INFO("已切换到暗色主题");
    } else {
        X11UT_LOG_INFO("已切换到亮色主题");
    }
    
    // 重新初始化颜色
    x11ut__init_colors(tray);
    
    // 重新绘制托盘图标
    x11ut__draw_default_icon(tray);
    XCopyArea(tray->display, tray->icon_pixmap, tray->window, tray->gc,
              0, 0, tray->icon_width, tray->icon_height, 0, 0);
    
    // 重新创建菜单（使用新主题）
    if (tray->menu) {
        // 先清理旧菜单
        x11ut__menu_cleanup(tray, tray->menu);
        tray->menu = NULL;
        
        // 创建新菜单
        x11ut__create_menu(tray);
    }
}

// ==================== 创建菜单函数 ====================

// 创建菜单（根据当前语言和主题）
static void x11ut__create_menu(x11ut__tray_t* tray) {
    // 创建菜单
    tray->menu = x11ut__menu_create(tray);
    if (!tray->menu) {
        X11UT_LOG_WARNING("无法创建菜单，字体加载失败");
        return;
    }
    
    // 根据当前语言添加菜单项
    if (tray->english_mode) {
        // 英文菜单
        x11ut__menu_add_item(tray, tray->menu, "Switch Language", x11ut__switch_language_callback, tray);
        x11ut__menu_add_item(tray, tray->menu, "Toggle Dark Mode", x11ut__toggle_dark_mode_callback, tray);
        x11ut__menu_add_separator(tray, tray->menu);
        
        // 添加普通菜单项
        x11ut__menu_add_item(tray, tray->menu, "Option 1 (English)", x11ut__example_callback1, "Test Data");
        x11ut__menu_add_item(tray, tray->menu, "Option 2 (English)", x11ut__example_callback2, NULL);
        x11ut__menu_add_separator(tray, tray->menu);
        
        // 添加可勾选菜单项
        x11ut__menu_add_checkable_item(tray, tray->menu, "Auto Start", x11ut__toggle_callback, NULL, false);
        x11ut__menu_add_checkable_item(tray, tray->menu, "Enable Notifications", x11ut__toggle_callback, NULL, true);
        x11ut__menu_add_checkable_item(tray, tray->menu, "Dark Theme", x11ut__toggle_callback, NULL, tray->dark_mode);
        x11ut__menu_add_separator(tray, tray->menu);
        
        // 继续添加其他菜单项
        x11ut__menu_add_item(tray, tray->menu, "Test Function", x11ut__test_callback, NULL);
        x11ut__menu_add_item(tray, tray->menu, "Settings", x11ut__settings_callback, NULL);
        x11ut__menu_add_separator(tray, tray->menu);
        x11ut__menu_add_item(tray, tray->menu, "Exit Program", x11ut__exit_callback, tray);
    } else {
        // 中文菜单
        x11ut__menu_add_item(tray, tray->menu, "切换语言", x11ut__switch_language_callback, tray);
        x11ut__menu_add_item(tray, tray->menu, "切换暗色模式", x11ut__toggle_dark_mode_callback, tray);
        x11ut__menu_add_separator(tray, tray->menu);
        
        // 添加普通菜单项
        x11ut__menu_add_item(tray, tray->menu, "选项1 (中文)", x11ut__example_callback1, "测试数据");
        x11ut__menu_add_item(tray, tray->menu, "选项2 (中文)", x11ut__example_callback2, NULL);
        x11ut__menu_add_separator(tray, tray->menu);
        
        // 添加可勾选菜单项
        x11ut__menu_add_checkable_item(tray, tray->menu, "自动启动", x11ut__toggle_callback, NULL, false);
        x11ut__menu_add_checkable_item(tray, tray->menu, "启用通知", x11ut__toggle_callback, NULL, true);
        x11ut__menu_add_checkable_item(tray, tray->menu, "暗色主题", x11ut__toggle_callback, NULL, tray->dark_mode);
        x11ut__menu_add_separator(tray, tray->menu);
        
        // 继续添加其他菜单项
        x11ut__menu_add_item(tray, tray->menu, "测试功能", x11ut__test_callback, NULL);
        x11ut__menu_add_item(tray, tray->menu, "设置", x11ut__settings_callback, NULL);
        x11ut__menu_add_separator(tray, tray->menu);
        x11ut__menu_add_item(tray, tray->menu, "退出程序", x11ut__exit_callback, tray);
    }
    
    X11UT_LOG_DEBUG("创建菜单完成，共 %d 个菜单项", tray->menu->item_count);
}

// ==================== 字体测试函数 ====================

static void x11ut__test_fonts(x11ut__tray_t* tray) {
    X11UT_LOG_INFO("=== 字体测试 ===");
    
    // 测试一些常见的中文字体
    const char* test_fonts[] = {
        "WenQuanYi Micro Hei:size=12",
        "Noto Sans CJK SC:size=12",
        "DejaVu Sans:size=12",
        "Sans:size=12",
        "fixed:size=12",
        NULL
    };
    
    for (int i = 0; test_fonts[i] != NULL; i++) {
        XftFont* font = XftFontOpenName(tray->display, tray->screen, test_fonts[i]);
        if (font) {
            X11UT_LOG_INFO("✓ 字体可用: %s", test_fonts[i]);
            XftFontClose(tray->display, font);
        } else {
            X11UT_LOG_WARNING("✗ 字体不可用: %s", test_fonts[i]);
        }
    }
    
    X11UT_LOG_INFO("=== 字体测试结束 ===");
}

// ==================== 主函数 ====================

// ==================== 主函数 ====================

// 显示帮助信息
static void x11ut__print_help(const char* program_name) {
    printf("用法: %s [选项]\n", program_name);
    printf("选项:\n");
    printf("  -h, --help             显示此帮助信息\n");
    printf("  -l, --lang <语言>      设置语言: en (英文) 或 zh (中文)\n");
    printf("  -d, --dark             启用暗色模式 (默认)\n");
    printf("  --light                启用亮色模式\n");
    printf("  -t, --test-icon        生成并使用测试图标（圆形图标）\n");
    printf("  -s, --icon-size <尺寸>  设置图标尺寸 (默认: 24)\n");
    printf("  --log-level <级别>     设置日志级别: 0-5 (0:无, 1:错误, 2:警告, 3:信息, 4:调试, 5:详细)\n");
    printf("                        或: none, error, warning, info, debug, verbose\n");
    printf("  --log-file <文件>      将日志输出到文件\n");
    printf("  --version              显示版本信息\n");
    printf("\n示例:\n");
    printf("  %s                     # 默认: 中文 + 暗色主题 + 默认图标\n", program_name);
    printf("  %s -l en               # 英文 + 暗色主题 + 默认图标\n", program_name);
    printf("  %s -t                  # 使用测试图标（圆形）\n", program_name);
    printf("  %s -t -s 32           # 使用32x32的测试图标\n", program_name);
    printf("  %s -l zh --light -t   # 中文 + 亮色主题 + 测试图标\n", program_name);
    printf("  %s --log-level debug   # 启用调试日志\n", program_name);
    printf("  %s --log-level 0       # 禁用所有日志\n", program_name);
}

// 解析命令行参数
static void x11ut__parse_args(int argc, char* argv[], 
                              bool* dark_mode, bool* english_mode,
                              bool* use_test_icon, int* icon_size,
                              x11ut__log_level_t* log_level,
                              char** log_file) {
    // 默认值
    *dark_mode = true;      // 默认暗色模式
    *english_mode = false;  // 默认中文模式
    *use_test_icon = false; // 默认使用默认图标（三条线）
    *icon_size = 24;        // 默认图标尺寸
    *log_level = X11UT_LOG_INFO;  // 默认INFO级别
    *log_file = NULL;       // 默认不记录到文件
    
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            x11ut__print_help(argv[0]);
            exit(0);
        } else if (strcmp(argv[i], "-l") == 0 || strcmp(argv[i], "--lang") == 0) {
            if (i + 1 < argc) {
                if (strcmp(argv[i + 1], "en") == 0 || strcmp(argv[i + 1], "english") == 0 || 
                    strcmp(argv[i + 1], "EN") == 0 || strcmp(argv[i + 1], "English") == 0) {
                    *english_mode = true;
                } else if (strcmp(argv[i + 1], "zh") == 0 || strcmp(argv[i + 1], "chinese") == 0 || 
                          strcmp(argv[i + 1], "ZH") == 0 || strcmp(argv[i + 1], "Chinese") == 0) {
                    *english_mode = false;
                } else {
                    fprintf(stderr, "错误: 无效的语言选项 '%s'。请使用 'en' 或 'zh'\n", argv[i + 1]);
                    x11ut__print_help(argv[0]);
                    exit(1);
                }
                i++; // 跳过参数值
            } else {
                fprintf(stderr, "错误: -l/--lang 选项需要一个参数 (en 或 zh)\n");
                x11ut__print_help(argv[0]);
                exit(1);
            }
        } else if (strcmp(argv[i], "-d") == 0 || strcmp(argv[i], "--dark") == 0) {
            *dark_mode = true;
        } else if (strcmp(argv[i], "--light") == 0) {
            *dark_mode = false;
        } else if (strcmp(argv[i], "-t") == 0 || strcmp(argv[i], "--test-icon") == 0) {
            *use_test_icon = true;
        } else if (strcmp(argv[i], "-s") == 0 || strcmp(argv[i], "--icon-size") == 0) {
            if (i + 1 < argc) {
                *icon_size = atoi(argv[i + 1]);
                if (*icon_size < 16 || *icon_size > 128) {
                    fprintf(stderr, "警告: 图标尺寸 %d 不在推荐范围 (16-128) 内，使用默认值 24\n", *icon_size);
                    *icon_size = 24;
                }
                i++; // 跳过参数值
            } else {
                fprintf(stderr, "错误: -s/--icon-size 选项需要一个参数\n");
                x11ut__print_help(argv[0]);
                exit(1);
            }
        } else if (strcmp(argv[i], "--log-level") == 0) {
            if (i + 1 < argc) {
                *log_level = x11ut__parse_log_level(argv[i + 1]);
                i++; // 跳过参数值
            } else {
                fprintf(stderr, "错误: --log-level 选项需要一个参数\n");
                x11ut__print_help(argv[0]);
                exit(1);
            }
        } else if (strcmp(argv[i], "--log-file") == 0) {
            if (i + 1 < argc) {
                *log_file = argv[i + 1];
                i++; // 跳过参数值
            } else {
                fprintf(stderr, "错误: --log-file 选项需要一个参数\n");
                x11ut__print_help(argv[0]);
                exit(1);
            }
        } else if (strcmp(argv[i], "--version") == 0) {
            printf("X11 托盘图标程序 v1.1.0\n");
            printf("支持命令行参数、主题切换、语言切换、图标选择、日志系统\n");
            exit(0);
        } else {
            fprintf(stderr, "错误: 未知选项 '%s'\n", argv[i]);
            x11ut__print_help(argv[0]);
            exit(1);
        }
    }
}

int main(int argc, char* argv[]) {
    x11ut__tray_t tray;
    
    // 解析命令行参数
    bool dark_mode, english_mode, use_test_icon;
    int icon_size;
    x11ut__log_level_t log_level;
    char* log_file = NULL;
    
    x11ut__parse_args(argc, argv, &dark_mode, &english_mode, 
                      &use_test_icon, &icon_size, &log_level, &log_file);
    
    // 设置日志系统
    x11ut__set_log_level(log_level);
    if (log_file) {
        x11ut__set_log_file(log_file);
    }
    
    // 在设置日志级别后输出启动信息
    X11UT_LOG_INFO("=== X11 托盘图标程序 (支持语言和主题切换) ===");
    X11UT_LOG_INFO("参数设置:");
    X11UT_LOG_INFO("  - 语言: %s", english_mode ? "英文" : "中文");
    X11UT_LOG_INFO("  - 主题: %s", dark_mode ? "暗色" : "亮色");
    X11UT_LOG_INFO("  - 图标: %s", use_test_icon ? "测试图标（圆形）" : "默认图标（三条线）");
    X11UT_LOG_INFO("  - 图标尺寸: %dx%d", icon_size, icon_size);
    X11UT_LOG_INFO("  - 日志级别: %d", log_level);
    X11UT_LOG_INFO("  - 日志文件: %s", log_file ? log_file : "无");
    X11UT_LOG_INFO("区域设置: %s", setlocale(LC_ALL, ""));
    
    // 初始化托盘
    if (!x11ut__tray_init(&tray, NULL)) {
        X11UT_LOG_ERROR("无法初始化托盘");
        return 1;
    }
    
    // 应用命令行参数设置
    tray.dark_mode = dark_mode;
    tray.english_mode = english_mode;
    
    // 重新初始化颜色以应用主题设置
    x11ut__init_colors(&tray);
    
    // 测试字体（如果日志级别足够高）
    if (log_level >= X11UT_LOG_DEBUG) {
        x11ut__test_fonts(&tray);
    }
    
    // 根据参数设置图标
    if (use_test_icon) {
        // 生成并设置测试图标
        X11UT_LOG_INFO("正在生成测试图标（圆形），尺寸: %dx%d", icon_size, icon_size);
        
        unsigned char* test_icon_data = x11ut__generate_test_icon(&tray, icon_size, icon_size);
        if (test_icon_data) {
            if (x11ut__tray_set_icon_with_data(&tray, icon_size, icon_size, test_icon_data)) {
                X11UT_LOG_INFO("测试图标设置成功");
            } else {
                X11UT_LOG_WARNING("测试图标设置失败，使用默认图标");
                x11ut__draw_default_icon(&tray);
            }
            free(test_icon_data);
        } else {
            X11UT_LOG_WARNING("无法生成测试图标，使用默认图标");
            x11ut__draw_default_icon(&tray);
        }
    } else {
        // 使用默认图标（三条线）
        X11UT_LOG_INFO("正在设置默认图标（三条线），尺寸: %dx%d", icon_size, icon_size);
        
        // 先设置图标尺寸
        tray.icon_width = icon_size;
        tray.icon_height = icon_size;
        
        // 重新配置窗口大小
        XResizeWindow(tray.display, tray.window, icon_size, icon_size);
        
        // 重新绘制默认图标
        x11ut__draw_default_icon(&tray);
    }
    
    // 等待系统托盘
    X11UT_LOG_INFO("等待系统托盘...");
    x11ut__msleep(1000);
    
    // 嵌入到系统托盘
    if (!x11ut__tray_embed(&tray)) {
        X11UT_LOG_WARNING("未嵌入到系统托盘，但程序继续运行");
    }
    
    // 创建菜单
    x11ut__create_menu(&tray);
    
    // 创建工具提示
    tray.tooltip = x11ut__tooltip_create(&tray);
    
    X11UT_LOG_INFO("托盘程序运行中...");
    X11UT_LOG_INFO("功能特性:");
    X11UT_LOG_INFO("  - 支持暗色/亮色主题切换");
    X11UT_LOG_INFO("  - 支持中英文语言切换");
    X11UT_LOG_INFO("  - 支持选择图标类型：默认图标（三条线）或测试图标（圆形）");
    X11UT_LOG_INFO("  - 支持自定义图标尺寸");
    X11UT_LOG_INFO("  - 统一的日志系统");
    X11UT_LOG_INFO("  - 菜单项左对齐");
    X11UT_LOG_INFO("  - 支持checkbox菜单项");
    X11UT_LOG_INFO("  - 菜单项鼠标悬停效果");
    X11UT_LOG_INFO("  - 工具提示支持");
    X11UT_LOG_INFO("  - 分隔线支持");
    X11UT_LOG_INFO("  - 使用Xft字体渲染，支持UTF-8");
    X11UT_LOG_INFO("");
    X11UT_LOG_INFO("当前图标类型: %s", use_test_icon ? "测试图标（圆形）" : "默认图标（三条线）");
    X11UT_LOG_INFO("图标尺寸: %dx%d", icon_size, icon_size);
    X11UT_LOG_INFO("");
    X11UT_LOG_INFO("鼠标悬停在托盘图标上显示工具提示");
    X11UT_LOG_INFO("点击托盘图标显示菜单");
    X11UT_LOG_INFO("菜单特性:");
    X11UT_LOG_INFO("  - 无标题栏，真正的弹出菜单外观");
    X11UT_LOG_INFO("  - 显示在托盘图标附近");
    X11UT_LOG_INFO("  - 鼠标悬停有视觉反馈");
    X11UT_LOG_INFO("  - 支持checkbox，点击可切换状态");
    X11UT_LOG_INFO("  - 支持分隔线");
    X11UT_LOG_INFO("  - 点击菜单项后菜单自动隐藏");
    X11UT_LOG_INFO("");
    X11UT_LOG_INFO("按 Ctrl+C 退出程序");
    
    // 主事件循环
    while (tray.running) {
        x11ut__tray_process_events(&tray);
        x11ut__msleep(10);
    }
    
    // 清理
    X11UT_LOG_INFO("正在清理资源...");
    x11ut__tray_cleanup(&tray);
    x11ut__log_cleanup();
    X11UT_LOG_INFO("程序退出");
    
    return 0;
}
