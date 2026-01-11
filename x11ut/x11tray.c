#define _POSIX_C_SOURCE 199309L
#define _XOPEN_SOURCE 500

#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <signal.h>
#include <unistd.h>
#include <time.h>
#include <locale.h>

// ==================== 错误处理 ====================

// X11错误处理函数
static int x11ut__error_handler(Display* display, XErrorEvent* error) {
    char error_text[256];
    XGetErrorText(display, error->error_code, error_text, sizeof(error_text));
    fprintf(stderr, "X11错误 [代码: %d, 请求: %d, 小代码: %d]: %s\n",
            error->error_code, error->request_code, error->minor_code, error_text);
    return 0;
}

// ==================== 类型定义 ====================

// 菜单项结构
typedef struct x11ut__menu_item {
    char* label;
    void (*callback)(void*);
    void* user_data;
    bool is_separator;  // 是否是分隔线
    struct x11ut__menu_item* next;
} x11ut__menu_item_t;

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
    XFontStruct* font;   // X11字体
    GC text_gc;          // 文本图形上下文
    GC hover_gc;         // 悬停图形上下文
    GC separator_gc;     // 分隔线图形上下文
} x11ut__menu_t;

// 颜色结构（暗色主题）
typedef struct {
    unsigned long bg_color;        // 背景色
    unsigned long fg_color;        // 前景色（文本）
    unsigned long border_color;    // 边框色
    unsigned long hover_bg_color;  // 悬停背景色
    unsigned long hover_fg_color;  // 悬停前景色
    unsigned long separator_color; // 分隔线颜色
} x11ut__colors_t;

// 托盘图标结构
typedef struct {
    Display* display;
    int screen;
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
    Atom xembed_info;
    
    // 状态
    bool embedded;
    bool running;
    
    // 菜单
    x11ut__menu_t* menu;
    
    // 图标尺寸
    int icon_width;
    int icon_height;
    
    // 颜色
    x11ut__colors_t colors;
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
bool x11ut__menu_add_item(x11ut__menu_t* menu, const char* label, void (*callback)(void*), void* user_data);
bool x11ut__menu_add_separator(x11ut__menu_t* menu);
void x11ut__menu_show(x11ut__tray_t* tray, x11ut__menu_t* menu, int x, int y);
void x11ut__menu_hide(x11ut__tray_t* tray, x11ut__menu_t* menu);
void x11ut__menu_cleanup(x11ut__tray_t* tray, x11ut__menu_t* menu);

// 工具函数
void x11ut__tray_cleanup(x11ut__tray_t* tray);
static void x11ut__draw_default_icon(x11ut__tray_t* tray);
static void x11ut__msleep(long milliseconds);
static void x11ut__init_colors(x11ut__tray_t* tray);
static bool x11ut__load_font(x11ut__tray_t* tray, x11ut__menu_t* menu);

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

// 初始化颜色（暗色主题）
static void x11ut__init_colors(x11ut__tray_t* tray) {
    // 暗色主题颜色
    tray->colors.bg_color = x11ut__rgb_to_color(tray, 45, 45, 45);        // #2D2D2D
    tray->colors.fg_color = x11ut__rgb_to_color(tray, 224, 224, 224);     // #E0E0E0
    tray->colors.border_color = x11ut__rgb_to_color(tray, 68, 68, 68);    // #444444
    tray->colors.hover_bg_color = x11ut__rgb_to_color(tray, 58, 58, 58);  // #3A3A3A
    tray->colors.hover_fg_color = x11ut__rgb_to_color(tray, 255, 255, 255); // #FFFFFF
    tray->colors.separator_color = x11ut__rgb_to_color(tray, 68, 68, 68); // #444444
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
        fprintf(stderr, "无法打开X显示连接\n");
        return false;
    }
    
    tray->screen = DefaultScreen(tray->display);
    tray->icon_width = 24;
    tray->icon_height = 24;
    tray->running = true;
    tray->embedded = false;
    
    // 初始化颜色
    x11ut__init_colors(tray);
    
    // 获取原子
    tray->net_system_tray_s0 = XInternAtom(tray->display, "_NET_SYSTEM_TRAY_S0", False);
    tray->net_system_tray_opcode = XInternAtom(tray->display, "_NET_SYSTEM_TRAY_OPCODE", False);
    tray->net_wm_window_type_dock = XInternAtom(tray->display, "_NET_WM_WINDOW_TYPE_DOCK", False);
    tray->net_wm_window_type_menu = XInternAtom(tray->display, "_NET_WM_WINDOW_TYPE_MENU", False);
    tray->net_wm_state_skip_taskbar = XInternAtom(tray->display, "_NET_WM_STATE_SKIP_TASKBAR", False);
    tray->xembed_info = XInternAtom(tray->display, "_XEMBED_INFO", False);
    
    // 创建颜色映射
    Colormap colormap = DefaultColormap(tray->display, tray->screen);
    
    // 为自定义颜色分配颜色单元
    XColor bg_color, fg_color, border_color, hover_bg_color, hover_fg_color, separator_color;
    
    // 背景色
    bg_color.red = 45 * 256;
    bg_color.green = 45 * 256;
    bg_color.blue = 45 * 256;
    bg_color.flags = DoRed | DoGreen | DoBlue;
    XAllocColor(tray->display, colormap, &bg_color);
    tray->colors.bg_color = bg_color.pixel;
    
    // 前景色
    fg_color.red = 224 * 256;
    fg_color.green = 224 * 256;
    fg_color.blue = 224 * 256;
    fg_color.flags = DoRed | DoGreen | DoBlue;
    XAllocColor(tray->display, colormap, &fg_color);
    tray->colors.fg_color = fg_color.pixel;
    
    // 边框色
    border_color.red = 68 * 256;
    border_color.green = 68 * 256;
    border_color.blue = 68 * 256;
    border_color.flags = DoRed | DoGreen | DoBlue;
    XAllocColor(tray->display, colormap, &border_color);
    tray->colors.border_color = border_color.pixel;
    
    // 悬停背景色
    hover_bg_color.red = 58 * 256;
    hover_bg_color.green = 58 * 256;
    hover_bg_color.blue = 58 * 256;
    hover_bg_color.flags = DoRed | DoGreen | DoBlue;
    XAllocColor(tray->display, colormap, &hover_bg_color);
    tray->colors.hover_bg_color = hover_bg_color.pixel;
    
    // 悬停前景色
    hover_fg_color.red = 255 * 256;
    hover_fg_color.green = 255 * 256;
    hover_fg_color.blue = 255 * 256;
    hover_fg_color.flags = DoRed | DoGreen | DoBlue;
    XAllocColor(tray->display, colormap, &hover_fg_color);
    tray->colors.hover_fg_color = hover_fg_color.pixel;
    
    // 分隔线颜色
    separator_color.red = 68 * 256;
    separator_color.green = 68 * 256;
    separator_color.blue = 68 * 256;
    separator_color.flags = DoRed | DoGreen | DoBlue;
    XAllocColor(tray->display, colormap, &separator_color);
    tray->colors.separator_color = separator_color.pixel;
    
    // 创建窗口
    Window root = RootWindow(tray->display, tray->screen);
    tray->window = XCreateSimpleWindow(tray->display, root,
                                       0, 0, tray->icon_width, tray->icon_height,
                                       0, 
                                       tray->colors.border_color,  // 边框颜色
                                       tray->colors.bg_color);     // 背景颜色
    
    if (!tray->window) {
        fprintf(stderr, "无法创建窗口\n");
        XCloseDisplay(tray->display);
        return false;
    }
    
    // 选择输入事件
    XSelectInput(tray->display, tray->window,
                 ExposureMask | ButtonPressMask | ButtonReleaseMask |
                 StructureNotifyMask);
    
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
        fprintf(stderr, "无法创建图形上下文\n");
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
    
    printf("托盘初始化成功，窗口ID: 0x%lx\n", tray->window);
    return true;
}

// 绘制默认图标（暗色主题风格）
static void x11ut__draw_default_icon(x11ut__tray_t* tray) {
    // 清除背景（使用暗色背景）
    XSetForeground(tray->display, tray->gc, tray->colors.bg_color);
    XFillRectangle(tray->display, tray->icon_pixmap, tray->gc,
                   0, 0, tray->icon_width, tray->icon_height);
    
    // 绘制边框
    XSetForeground(tray->display, tray->gc, tray->colors.fg_color);
    XDrawRectangle(tray->display, tray->icon_pixmap, tray->gc,
                   0, 0, tray->icon_width - 1, tray->icon_height - 1);
    
    // 绘制图标内容（三条线，类似菜单图标）
    int center_x = tray->icon_width / 2;
    int center_y = tray->icon_height / 2;
    
    // 顶部横线
    XDrawLine(tray->display, tray->icon_pixmap, tray->gc,
              center_x - 6, center_y - 3,
              center_x + 6, center_y - 3);
    
    // 中间横线
    XDrawLine(tray->display, tray->icon_pixmap, tray->gc,
              center_x - 6, center_y,
              center_x + 6, center_y);
    
    // 底部横线
    XDrawLine(tray->display, tray->icon_pixmap, tray->gc,
              center_x - 6, center_y + 3,
              center_x + 6, center_y + 3);
    
    // 设置窗口背景
    XSetWindowBackgroundPixmap(tray->display, tray->window, tray->icon_pixmap);
    XClearWindow(tray->display, tray->window);
}

// 设置图标
bool x11ut__tray_set_icon(x11ut__tray_t* tray, int width, int height, const unsigned char* data) {
    if (!tray || !tray->display) return false;
    
    tray->icon_width = width;
    tray->icon_height = height;
    
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
    
    // 绘制图标
    x11ut__draw_default_icon(tray);
    
    XFlush(tray->display);
    return true;
}

// 嵌入到系统托盘
bool x11ut__tray_embed(x11ut__tray_t* tray) {
    if (!tray || !tray->display) return false;
    
    printf("查找系统托盘...\n");
    
    // 获取系统托盘窗口
    tray->tray_window = XGetSelectionOwner(tray->display, tray->net_system_tray_s0);
    
    if (tray->tray_window == None) {
        printf("未找到系统托盘，将在普通窗口中显示\n");
        XMapWindow(tray->display, tray->window);
        XFlush(tray->display);
        return false;
    }
    
    printf("找到系统托盘窗口: 0x%lx\n", tray->tray_window);
    
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
    
    printf("已发送嵌入请求\n");
    
    // 等待一下然后映射窗口
    x11ut__msleep(100);
    XMapWindow(tray->display, tray->window);
    XFlush(tray->display);
    
    tray->embedded = true;
    printf("窗口已映射\n");
    
    return true;
}

// ==================== 菜单函数 ====================

// 加载字体（支持中文）
static bool x11ut__load_font(x11ut__tray_t* tray, x11ut__menu_t* menu) {
    if (!tray || !tray->display || !menu) return false;
    
    // 尝试加载中文字体，使用字体列表
    const char* font_names[] = {
        "-*-*-medium-r-normal-*-14-*-*-*-*-*-*-*",  // X逻辑字体描述
        "fixed",
        "6x13",
        "9x15",
        NULL
    };
    
    // 尝试加载字体
    for (int i = 0; font_names[i] != NULL; i++) {
        menu->font = XLoadQueryFont(tray->display, font_names[i]);
        if (menu->font) {
            printf("成功加载字体: %s\n", font_names[i]);
            return true;
        }
    }
    
    fprintf(stderr, "警告: 无法加载任何字体，使用默认字体\n");
    menu->font = XLoadQueryFont(tray->display, "fixed");
    return (menu->font != NULL);
}

// 创建菜单
x11ut__menu_t* x11ut__menu_create(x11ut__tray_t* tray) {
    if (!tray || !tray->display) return NULL;
    
    x11ut__menu_t* menu = malloc(sizeof(x11ut__menu_t));
    if (!menu) return NULL;
    
    memset(menu, 0, sizeof(x11ut__menu_t));
    menu->item_height = 28;  // 稍高以容纳中文
    menu->width = 180;       // 稍宽以容纳中文
    menu->hover_index = -1;  // 初始无悬停
    
    // 加载字体
    if (!x11ut__load_font(tray, menu)) {
        free(menu);
        return NULL;
    }
    
    // 创建菜单窗口属性
    XSetWindowAttributes attrs;
    attrs.override_redirect = True;  // 重要：使菜单窗口跳过窗口管理器
    attrs.background_pixel = tray->colors.bg_color;
    attrs.border_pixel = tray->colors.border_color;
    attrs.event_mask = ExposureMask | ButtonPressMask | ButtonReleaseMask |
                       LeaveWindowMask | FocusChangeMask | PointerMotionMask;  // 添加鼠标移动事件
    
    // 创建菜单窗口 - 使用override_redirect
    menu->window = XCreateWindow(tray->display,
                                 RootWindow(tray->display, tray->screen),
                                 0, 0, menu->width, 100,
                                 1,  // 边框宽度
                                 CopyFromParent,  // 深度
                                 CopyFromParent,  // 类
                                 CopyFromParent,  // 视觉
                                 CWOverrideRedirect | CWBackPixel | 
                                 CWBorderPixel | CWEventMask,
                                 &attrs);
    
    if (!menu->window) {
        if (menu->font) XFreeFont(tray->display, menu->font);
        free(menu);
        return NULL;
    }
    
    // 创建图形上下文
    XGCValues gc_vals;
    
    // 文本图形上下文
    gc_vals.foreground = tray->colors.fg_color;
    gc_vals.background = tray->colors.bg_color;
    gc_vals.font = menu->font->fid;
    menu->text_gc = XCreateGC(tray->display, menu->window,
                             GCForeground | GCBackground | GCFont, &gc_vals);
    
    // 悬停图形上下文
    gc_vals.foreground = tray->colors.hover_fg_color;
    gc_vals.background = tray->colors.hover_bg_color;
    gc_vals.font = menu->font->fid;
    menu->hover_gc = XCreateGC(tray->display, menu->window,
                              GCForeground | GCBackground | GCFont, &gc_vals);
    
    // 分隔线图形上下文
    gc_vals.foreground = tray->colors.separator_color;
    gc_vals.background = tray->colors.bg_color;
    gc_vals.line_width = 1;
    menu->separator_gc = XCreateGC(tray->display, menu->window,
                                  GCForeground | GCBackground | GCLineWidth, &gc_vals);
    
    // 设置窗口类型为菜单（无装饰）
    Atom window_type = XInternAtom(tray->display, "_NET_WM_WINDOW_TYPE", False);
    XChangeProperty(tray->display, menu->window, window_type,
                   XA_ATOM, 32, PropModeReplace,
                   (unsigned char*)&tray->net_wm_window_type_menu, 1);
    
    return menu;
}

// 添加菜单项
bool x11ut__menu_add_item(x11ut__menu_t* menu, const char* label, 
                         void (*callback)(void*), void* user_data) {
    if (!menu || !label) return false;
    
    x11ut__menu_item_t* item = malloc(sizeof(x11ut__menu_item_t));
    if (!item) return false;
    
    item->label = x11ut__strdup(label);
    item->callback = callback;
    item->user_data = user_data;
    item->is_separator = false;
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
    
    return true;
}

// 添加分隔线
bool x11ut__menu_add_separator(x11ut__menu_t* menu) {
    if (!menu) return false;
    
    x11ut__menu_item_t* item = malloc(sizeof(x11ut__menu_item_t));
    if (!item) return false;
    
    item->label = NULL;
    item->callback = NULL;
    item->user_data = NULL;
    item->is_separator = true;
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
    
    return true;
}

// 计算文本宽度
static int x11ut__text_width(x11ut__menu_t* menu, const char* text) {
    if (!menu || !menu->font || !text) return 0;
    return XTextWidth(menu->font, text, strlen(text));
}

// 绘制菜单
static void x11ut__menu_draw(x11ut__tray_t* tray, x11ut__menu_t* menu) {
    if (!tray || !tray->display || !menu || !menu->window) return;
    
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
                XSetForeground(tray->display, bg_gc, tray->colors.hover_bg_color);
                XFillRectangle(tray->display, menu->window, bg_gc, 1, y, 
                             menu->width - 2, menu->item_height);
            }
            
            // 绘制文本
            if (item->label) {
                int text_width = x11ut__text_width(menu, item->label);
                int text_x = (menu->width - text_width) / 2;
                int text_y = y + menu->item_height/2 + menu->font->ascent/2;
                
                // 使用适当的GC绘制文本
                GC text_gc = is_hover ? menu->hover_gc : menu->text_gc;
                XDrawString(tray->display, menu->window, text_gc,
                           text_x, text_y, item->label, strlen(item->label));
            }
        }
        
        y += menu->item_height;
        item_index++;
        item = item->next;
    }
    
    // 绘制边框
    XSetForeground(tray->display, bg_gc, tray->colors.border_color);
    XDrawRectangle(tray->display, menu->window, bg_gc, 0, 0, 
                  menu->width - 1, menu->height - 1);
    
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
    
    // 调整菜单位置 - 在点击位置附近显示
    // 默认显示在点击位置下方
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
    if (item && !item->is_separator && item->callback) {
        printf("点击菜单项: %s\n", item->label);
        item->callback(item->user_data);
    }
    
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
    }
}

// 清理菜单
void x11ut__menu_cleanup(x11ut__tray_t* tray, x11ut__menu_t* menu) {
    if (!menu) return;
    
    if (tray && tray->display && menu->window) {
        x11ut__menu_hide(tray, menu);
        
        // 释放资源
        if (menu->font) XFreeFont(tray->display, menu->font);
        if (menu->text_gc) XFreeGC(tray->display, menu->text_gc);
        if (menu->hover_gc) XFreeGC(tray->display, menu->hover_gc);
        if (menu->separator_gc) XFreeGC(tray->display, menu->separator_gc);
        
        XDestroyWindow(tray->display, menu->window);
    }
    
    x11ut__menu_item_t* item = menu->items;
    while (item) {
        x11ut__menu_item_t* next = item->next;
        if (item->label) free(item->label);
        free(item);
        item = next;
    }
    
    free(menu);
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
                } else if (tray->menu && event.xexpose.window == tray->menu->window) {
                    x11ut__menu_draw(tray, tray->menu);
                }
                break;
                
            case ButtonPress:
                if (event.xbutton.window == tray->window) {
                    printf("托盘图标被点击 (位置: %d, %d)\n", 
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
                
            case FocusOut:
                // 当菜单失去焦点时隐藏
                if (tray->menu && event.xfocus.window == tray->menu->window) {
                    x11ut__msleep(50);
                    x11ut__menu_hide(tray, tray->menu);
                }
                break;
                
            case LeaveNotify:
                // 鼠标离开菜单窗口时隐藏菜单
                if (tray->menu && event.xcrossing.window == tray->menu->window) {
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
                
            case DestroyNotify:
                if (event.xdestroywindow.window == tray->window) {
                    printf("托盘窗口被销毁\n");
                    tray->running = false;
                }
                break;
                
            case ClientMessage:
                if (event.xclient.message_type == tray->net_system_tray_opcode) {
                    printf("收到系统托盘消息\n");
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
    
    if (tray->display) {
        // 清理菜单
        if (tray->menu) {
            x11ut__menu_cleanup(tray, tray->menu);
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

static void x11ut__example_callback1(void* data) {
    printf("选项1被点击: %s\n", (char*)data);
}

static void x11ut__example_callback2(void* data) {
    printf("选项2被点击\n");
}

static void x11ut__test_callback(void* data) {
    printf("测试功能被点击\n");
}

static void x11ut__settings_callback(void* data) {
    printf("设置被点击\n");
}

static void x11ut__exit_callback(void* data) {
    x11ut__tray_t* tray = (x11ut__tray_t*)data;
    if (tray) {
        printf("退出程序\n");
        tray->running = false;
    }
}

// ==================== 主函数 ====================

int main(int argc, char* argv[]) {
    x11ut__tray_t tray;
    
    printf("=== X11 托盘图标程序 (暗色主题) ===\n");
    printf("区域设置: %s\n", setlocale(LC_ALL, ""));
    
    // 初始化
    if (!x11ut__tray_init(&tray, NULL)) {
        fprintf(stderr, "无法初始化托盘\n");
        return 1;
    }
    
    // 设置图标
    if (!x11ut__tray_set_icon(&tray, 24, 24, NULL)) {
        fprintf(stderr, "无法设置图标\n");
        x11ut__tray_cleanup(&tray);
        return 1;
    }
    
    // 等待系统托盘
    printf("等待系统托盘...\n");
    x11ut__msleep(1000);
    
    // 嵌入到系统托盘
    if (!x11ut__tray_embed(&tray)) {
        printf("注意: 未嵌入到系统托盘，但程序继续运行\n");
    }
    
    // 创建菜单
    tray.menu = x11ut__menu_create(&tray);
    if (tray.menu) {
        // 添加菜单项（包含中文）
        x11ut__menu_add_item(tray.menu, "Option 1", x11ut__example_callback1, "Test Data");
        x11ut__menu_add_item(tray.menu, "Option 2", x11ut__example_callback2, NULL);
        x11ut__menu_add_separator(tray.menu);
        x11ut__menu_add_item(tray.menu, "Test Function", x11ut__test_callback, NULL);
        x11ut__menu_add_item(tray.menu, "Settings", x11ut__settings_callback, NULL);
        x11ut__menu_add_separator(tray.menu);
        x11ut__menu_add_item(tray.menu, "Exit Program", x11ut__exit_callback, &tray);
    }
    
    printf("\n托盘程序运行中...\n");
    printf("功能特性:\n");
    printf("  - 暗色主题界面\n");
    printf("  - 菜单项鼠标悬停效果\n");
    printf("  - 分隔线支持\n");
    printf("  - 简单的字体渲染\n");
    printf("\n点击托盘图标显示菜单\n");
    printf("菜单特性:\n");
    printf("  - 无标题栏，真正的弹出菜单外观\n");
    printf("  - 显示在托盘图标附近\n");
    printf("  - 鼠标悬停有视觉反馈\n");
    printf("  - 支持分隔线\n");
    printf("  - 暗色主题配色\n");
    printf("\n按 Ctrl+C 退出程序\n\n");
    
    // 主事件循环
    while (tray.running) {
        x11ut__tray_process_events(&tray);
        x11ut__msleep(10);
    }
    
    // 清理
    printf("正在清理资源...\n");
    x11ut__tray_cleanup(&tray);
    printf("程序退出\n");
    
    return 0;
}
