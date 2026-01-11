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
} x11ut__menu_t;

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
void x11ut__menu_show(x11ut__tray_t* tray, x11ut__menu_t* menu, int x, int y);
void x11ut__menu_hide(x11ut__tray_t* tray, x11ut__menu_t* menu);
void x11ut__menu_cleanup(x11ut__tray_t* tray, x11ut__menu_t* menu);

// 工具函数
void x11ut__tray_cleanup(x11ut__tray_t* tray);
static void x11ut__draw_default_icon(x11ut__tray_t* tray);
static void x11ut__msleep(long milliseconds);

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

// ==================== 初始化函数 ====================

// 初始化托盘
bool x11ut__tray_init(x11ut__tray_t* tray, const char* display_name) {
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
    
    // 获取原子
    tray->net_system_tray_s0 = XInternAtom(tray->display, "_NET_SYSTEM_TRAY_S0", False);
    tray->net_system_tray_opcode = XInternAtom(tray->display, "_NET_SYSTEM_TRAY_OPCODE", False);
    tray->net_wm_window_type_dock = XInternAtom(tray->display, "_NET_WM_WINDOW_TYPE_DOCK", False);
    tray->net_wm_state_skip_taskbar = XInternAtom(tray->display, "_NET_WM_STATE_SKIP_TASKBAR", False);
    tray->xembed_info = XInternAtom(tray->display, "_XEMBED_INFO", False);
    
    // 创建窗口
    Window root = RootWindow(tray->display, tray->screen);
    tray->window = XCreateSimpleWindow(tray->display, root,
                                       0, 0, tray->icon_width, tray->icon_height,
                                       0, 0, 0);
    
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
    tray->gc = XCreateGC(tray->display, tray->window, 0, NULL);
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

// 绘制默认图标
static void x11ut__draw_default_icon(x11ut__tray_t* tray) {
    // 清除背景
    XSetForeground(tray->display, tray->gc, WhitePixel(tray->display, tray->screen));
    XFillRectangle(tray->display, tray->icon_pixmap, tray->gc,
                   0, 0, tray->icon_width, tray->icon_height);
    
    // 绘制边框
    XSetForeground(tray->display, tray->gc, BlackPixel(tray->display, tray->screen));
    XDrawRectangle(tray->display, tray->icon_pixmap, tray->gc,
                   0, 0, tray->icon_width - 1, tray->icon_height - 1);
    
    // 绘制图标内容
    XDrawLine(tray->display, tray->icon_pixmap, tray->gc,
              5, 5, tray->icon_width - 5, tray->icon_height - 5);
    XDrawLine(tray->display, tray->icon_pixmap, tray->gc,
              tray->icon_width - 5, 5, 5, tray->icon_height - 5);
    
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

// 创建菜单
x11ut__menu_t* x11ut__menu_create(x11ut__tray_t* tray) {
    if (!tray || !tray->display) return NULL;
    
    x11ut__menu_t* menu = malloc(sizeof(x11ut__menu_t));
    if (!menu) return NULL;
    
    memset(menu, 0, sizeof(x11ut__menu_t));
    menu->item_height = 25;
    menu->width = 150;
    
    // 创建菜单窗口
    menu->window = XCreateSimpleWindow(tray->display,
                                       RootWindow(tray->display, tray->screen),
                                       0, 0, menu->width, 100,
                                       1,
                                       BlackPixel(tray->display, tray->screen),
                                       WhitePixel(tray->display, tray->screen));
    
    if (!menu->window) {
        free(menu);
        return NULL;
    }
    
    // 选择输入事件
    XSelectInput(tray->display, menu->window,
                 ExposureMask | ButtonPressMask | ButtonReleaseMask |
                 LeaveWindowMask);
    
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

// 绘制菜单
static void x11ut__menu_draw(x11ut__tray_t* tray, x11ut__menu_t* menu) {
    if (!tray || !tray->display || !menu || !menu->window) return;
    
    GC gc = XCreateGC(tray->display, menu->window, 0, NULL);
    if (!gc) return;
    
    // 清除背景
    XSetForeground(tray->display, gc, WhitePixel(tray->display, tray->screen));
    XFillRectangle(tray->display, menu->window, gc, 0, 0, menu->width, menu->height);
    
    // 设置前景色
    XSetForeground(tray->display, gc, BlackPixel(tray->display, tray->screen));
    
    // 绘制菜单项
    x11ut__menu_item_t* item = menu->items;
    int y = 10;
    
    while (item) {
        XDrawString(tray->display, menu->window, gc, 10, y, 
                   item->label, strlen(item->label));
        y += menu->item_height;
        item = item->next;
    }
    
    // 绘制边框
    XDrawRectangle(tray->display, menu->window, gc, 0, 0, 
                  menu->width - 1, menu->height - 1);
    
    XFreeGC(tray->display, gc);
}

// 显示菜单
void x11ut__menu_show(x11ut__tray_t* tray, x11ut__menu_t* menu, int x, int y) {
    if (!tray || !tray->display || !menu || !menu->window) return;
    
    // 调整位置确保在屏幕内
    int screen_width = DisplayWidth(tray->display, tray->screen);
    int screen_height = DisplayHeight(tray->display, tray->screen);
    
    if (x + menu->width > screen_width) x = screen_width - menu->width;
    if (y + menu->height > screen_height) y = screen_height - menu->height;
    
    // 移动和调整大小
    XMoveResizeWindow(tray->display, menu->window, x, y, menu->width, menu->height);
    
    // 绘制菜单
    x11ut__menu_draw(tray, menu);
    
    // 映射窗口
    XMapWindow(tray->display, menu->window);
    XRaiseWindow(tray->display, menu->window);
    
    menu->visible = true;
    XFlush(tray->display);
}

// 隐藏菜单
void x11ut__menu_hide(x11ut__tray_t* tray, x11ut__menu_t* menu) {
    if (!tray || !tray->display || !menu || !menu->window || !menu->visible) return;
    
    XUnmapWindow(tray->display, menu->window);
    menu->visible = false;
    XFlush(tray->display);
}

// 处理菜单点击
static void x11ut__handle_menu_click(x11ut__tray_t* tray, x11ut__menu_t* menu, int x, int y) {
    if (!menu || !menu->visible) return;
    
    int item_index = (y - 10) / menu->item_height;
    if (item_index < 0 || item_index >= menu->item_count) return;
    
    x11ut__menu_item_t* item = menu->items;
    for (int i = 0; i < item_index && item; i++) {
        item = item->next;
    }
    
    if (item && item->callback) {
        printf("点击菜单项: %s\n", item->label);
        item->callback(item->user_data);
    }
    
    x11ut__menu_hide(tray, menu);
}

// 清理菜单
void x11ut__menu_cleanup(x11ut__tray_t* tray, x11ut__menu_t* menu) {
    if (!menu) return;
    
    if (tray && tray->display && menu->window) {
        x11ut__menu_hide(tray, menu);
        XDestroyWindow(tray->display, menu->window);
    }
    
    x11ut__menu_item_t* item = menu->items;
    while (item) {
        x11ut__menu_item_t* next = item->next;
        free(item->label);
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
                    printf("托盘图标被点击\n");
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
                
            case LeaveNotify:
                if (tray->menu && event.xcrossing.window == tray->menu->window) {
                    x11ut__msleep(100);
                    x11ut__menu_hide(tray, tray->menu);
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
    
    printf("=== X11 托盘图标程序 ===\n");
    
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
        x11ut__menu_add_item(tray.menu, "选项 1", x11ut__example_callback1, "测试数据");
        x11ut__menu_add_item(tray.menu, "选项 2", x11ut__example_callback2, NULL);
        x11ut__menu_add_item(tray.menu, "退出", x11ut__exit_callback, &tray);
    }
    
    printf("托盘程序运行中...\n");
    printf("点击托盘图标显示菜单\n");
    printf("按 Ctrl+C 退出程序\n\n");
    
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
