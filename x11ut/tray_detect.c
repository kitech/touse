#define _POSIX_C_SOURCE 199309L

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

// X11错误处理函数 - 必须返回int
static int x11ut__error_handler(Display* display, XErrorEvent* error) {
    char error_text[256];
    XGetErrorText(display, error->error_code, error_text, sizeof(error_text));
    fprintf(stderr, "X11错误 [代码: %d, 请求: %d, 小代码: %d]: %s\n",
            error->error_code, error->request_code, error->minor_code, error_text);
    return 0;
}

// 通用错误处理宏
#define X11UT__CHECK_ERROR(cond, msg) \
    do { \
        if (!(cond)) { \
            fprintf(stderr, "错误 [%s:%d]: %s\n", __FILE__, __LINE__, msg); \
            return false; \
        } \
    } while(0)

#define X11UT__CHECK_NULL(ptr, msg) \
    do { \
        if ((ptr) == NULL) { \
            fprintf(stderr, "错误 [%s:%d]: %s\n", __FILE__, __LINE__, msg); \
            return false; \
        } \
    } while(0)

// ==================== 类型定义 ====================

// 菜单项结构
typedef struct x11ut__menu_item {
    char* label;
    void (*callback)(void*);
    void* user_data;
    int id;
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
    // X11相关
    Display* display;
    int screen;
    Window window;
    Window tray_window;
    GC gc;
    Pixmap icon_pixmap;
    Visual* visual;
    
    // 原子
    Atom net_system_tray_s0;
    Atom net_system_tray_opcode;
    Atom net_wm_window_type;
    Atom net_wm_window_type_dock;
    Atom net_wm_state;
    Atom net_wm_state_skip_taskbar;
    Atom xembed_info;
    Atom manager;
    
    // 状态
    bool embedded;
    bool running;
    unsigned long bg_color;
    unsigned long fg_color;
    
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
void x11ut__tray_handle_button(x11ut__tray_t* tray, XButtonEvent* event);

// 菜单函数
x11ut__menu_t* x11ut__menu_create(x11ut__tray_t* tray);
bool x11ut__menu_add_item(x11ut__menu_t* menu, const char* label, void (*callback)(void*), void* user_data);
void x11ut__menu_show(x11ut__tray_t* tray, x11ut__menu_t* menu, int x, int y);
void x11ut__menu_hide(x11ut__tray_t* tray, x11ut__menu_t* menu);
void x11ut__menu_draw(x11ut__tray_t* tray, x11ut__menu_t* menu);
void x11ut__menu_cleanup(x11ut__tray_t* tray, x11ut__menu_t* menu);

// 工具函数
void x11ut__tray_cleanup(x11ut__tray_t* tray);
static void x11ut__draw_default_icon(x11ut__tray_t* tray);
static void x11ut__msleep(long milliseconds);

// ==================== 初始化函数 ====================

// 初始化托盘
bool x11ut__tray_init(x11ut__tray_t* tray, const char* display_name) {
    X11UT__CHECK_NULL(tray, "托盘指针为空");
    
    // 初始化结构体
    memset(tray, 0, sizeof(x11ut__tray_t));
    tray->icon_width = 64;
    tray->icon_height = 64;
    tray->running = true;
    
    // 设置错误处理
    XSetErrorHandler(x11ut__error_handler);
    
    // 打开X11显示连接
    tray->display = XOpenDisplay(display_name);
    X11UT__CHECK_NULL(tray->display, "无法打开X显示连接");
    
    tray->screen = DefaultScreen(tray->display);
    tray->visual = DefaultVisual(tray->display, tray->screen);
    
    // 获取颜色
    tray->bg_color = WhitePixel(tray->display, tray->screen);
    tray->fg_color = BlackPixel(tray->display, tray->screen);
    
    // 获取原子
    tray->net_system_tray_s0 = XInternAtom(tray->display, "_NET_SYSTEM_TRAY_S0", False);
    tray->net_system_tray_opcode = XInternAtom(tray->display, "_NET_SYSTEM_TRAY_OPCODE", False);
    tray->net_wm_window_type = XInternAtom(tray->display, "_NET_WM_WINDOW_TYPE", False);
    tray->net_wm_window_type_dock = XInternAtom(tray->display, "_NET_WM_WINDOW_TYPE_DOCK", False);
    tray->net_wm_state = XInternAtom(tray->display, "_NET_WM_STATE", False);
    tray->net_wm_state_skip_taskbar = XInternAtom(tray->display, "_NET_WM_STATE_SKIP_TASKBAR", False);
    tray->xembed_info = XInternAtom(tray->display, "_XEMBED_INFO", False);
    tray->manager = XInternAtom(tray->display, "MANAGER", False);
    
    // 创建窗口属性
    XSetWindowAttributes attrs;
    attrs.background_pixel = tray->bg_color;
    attrs.border_pixel = tray->fg_color;
    attrs.event_mask = ExposureMask | ButtonPressMask | ButtonReleaseMask | 
                       StructureNotifyMask | PropertyChangeMask;
    attrs.override_redirect = True;  // 跳过窗口管理器
    
    // 创建窗口
    tray->window = XCreateWindow(
        tray->display,
        RootWindow(tray->display, tray->screen),
        0, 0, tray->icon_width, tray->icon_height,
        1,  // 边框宽度
        CopyFromParent,  // 深度
        CopyFromParent,  // 类
        CopyFromParent,  // 视觉
        CWBackPixel | CWBorderPixel | CWEventMask | CWOverrideRedirect,
        &attrs
    );
    
    X11UT__CHECK_ERROR(tray->window != 0, "无法创建窗口");
    
    // 设置窗口类型为DOCK
    XChangeProperty(tray->display, tray->window, tray->net_wm_window_type,
                   XA_ATOM, 32, PropModeReplace,
                   (unsigned char*)&tray->net_wm_window_type_dock, 1);
    
    // 设置跳过任务栏
    XChangeProperty(tray->display, tray->window, tray->net_wm_state,
                   XA_ATOM, 32, PropModeReplace,
                   (unsigned char*)&tray->net_wm_state_skip_taskbar, 1);
    
    // 设置XEmbed信息
    unsigned long xembed_info[2] = {0, 0};  // 版本0，映射后嵌入
    XChangeProperty(tray->display, tray->window, tray->xembed_info,
                   tray->xembed_info, 32, PropModeReplace,
                   (unsigned char*)xembed_info, 2);
    
    // 创建图形上下文
    XGCValues gc_vals;
    gc_vals.foreground = tray->fg_color;
    gc_vals.background = tray->bg_color;
    gc_vals.line_width = 2;
    
    tray->gc = XCreateGC(tray->display, tray->window, 
                        GCForeground | GCBackground | GCLineWidth, &gc_vals);
    X11UT__CHECK_NULL(tray->gc, "无法创建图形上下文");
    
    // 创建图标pixmap
    tray->icon_pixmap = XCreatePixmap(tray->display, tray->window,
                                     tray->icon_width, tray->icon_height,
                                     DefaultDepth(tray->display, tray->screen));
    X11UT__CHECK_ERROR(tray->icon_pixmap != 0, "无法创建图标pixmap");
    
    // 绘制默认图标
    x11ut__draw_default_icon(tray);
    
    printf("托盘初始化成功，窗口ID: 0x%lx\n", tray->window);
    return true;
}

// 绘制默认图标
static void x11ut__draw_default_icon(x11ut__tray_t* tray) {
    // 清除背景
    XSetForeground(tray->display, tray->gc, tray->bg_color);
    XFillRectangle(tray->display, tray->icon_pixmap, tray->gc,
                   0, 0, tray->icon_width, tray->icon_height);
    
    // 绘制边框
    XSetForeground(tray->display, tray->gc, tray->fg_color);
    XDrawRectangle(tray->display, tray->icon_pixmap, tray->gc,
                   2, 2, tray->icon_width - 5, tray->icon_height - 5);
    
    // 绘制X
    XDrawLine(tray->display, tray->icon_pixmap, tray->gc,
              10, 10, tray->icon_width - 10, tray->icon_height - 10);
    XDrawLine(tray->display, tray->icon_pixmap, tray->gc,
              tray->icon_width - 10, 10, 10, tray->icon_height - 10);
    
    // 设置窗口背景为pixmap
    XSetWindowBackgroundPixmap(tray->display, tray->window, tray->icon_pixmap);
    XClearWindow(tray->display, tray->window);
}

// 设置自定义图标
bool x11ut__tray_set_icon(x11ut__tray_t* tray, int width, int height, const unsigned char* data) {
    X11UT__CHECK_NULL(tray, "托盘指针为空");
    X11UT__CHECK_NULL(tray->display, "显示连接未初始化");
    X11UT__CHECK_ERROR(width > 0 && height > 0, "无效的图标尺寸");
    
    // 更新尺寸
    tray->icon_width = width;
    tray->icon_height = height;
    
    // 重新配置窗口
    XResizeWindow(tray->display, tray->window, width, height);
    
    // 释放旧的pixmap
    if (tray->icon_pixmap != 0) {
        XFreePixmap(tray->display, tray->icon_pixmap);
    }
    
    // 创建新的pixmap
    tray->icon_pixmap = XCreatePixmap(tray->display, tray->window,
                                     width, height,
                                     DefaultDepth(tray->display, tray->screen));
    X11UT__CHECK_ERROR(tray->icon_pixmap != 0, "无法创建图标pixmap");
    
    if (data != NULL) {
        // 从数据创建图像
        XImage* image = XCreateImage(tray->display, tray->visual,
                                    DefaultDepth(tray->display, tray->screen),
                                    ZPixmap, 0, (char*)data,
                                    width, height, 32, 0);
        if (image != NULL) {
            XPutImage(tray->display, tray->icon_pixmap, tray->gc, image,
                      0, 0, 0, 0, width, height);
            XDestroyImage(image);
        } else {
            // 如果创建图像失败，使用默认图标
            fprintf(stderr, "警告: 无法从数据创建图像，使用默认图标\n");
            x11ut__draw_default_icon(tray);
        }
    } else {
        // 使用默认图标
        x11ut__draw_default_icon(tray);
    }
    
    // 强制重绘
    XClearWindow(tray->display, tray->window);
    XFlush(tray->display);
    
    return true;
}

// 嵌入到系统托盘
bool x11ut__tray_embed(x11ut__tray_t* tray) {
    X11UT__CHECK_NULL(tray, "托盘指针为空");
    X11UT__CHECK_NULL(tray->display, "显示连接未初始化");
    
    printf("正在查找系统托盘...\n");
    
    // 获取系统托盘窗口
    tray->tray_window = XGetSelectionOwner(tray->display, tray->net_system_tray_s0);
    
    if (tray->tray_window == None) {
        fprintf(stderr, "错误: 未找到系统托盘窗口 (_NET_SYSTEM_TRAY_S0 未设置)\n");
        
        // 尝试查找管理器窗口
        tray->tray_window = XGetSelectionOwner(tray->display, tray->manager);
        if (tray->tray_window != None) {
            printf("找到管理器窗口: 0x%lx\n", tray->tray_window);
        } else {
            return false;
        }
    } else {
        printf("找到系统托盘窗口: 0x%lx\n", tray->tray_window);
    }
    
    // 发送嵌入消息
    XEvent ev;
    memset(&ev, 0, sizeof(ev));
    
    ev.xclient.type = ClientMessage;
    ev.xclient.window = tray->tray_window;
    ev.xclient.message_type = tray->net_system_tray_opcode;
    ev.xclient.format = 32;
    ev.xclient.data.l[0] = CurrentTime;
    ev.xclient.data.l[1] = 0;  // SYSTEM_TRAY_REQUEST_DOCK
    ev.xclient.data.l[2] = tray->window;
    ev.xclient.data.l[3] = 0;
    ev.xclient.data.l[4] = 0;
    
    printf("发送嵌入请求到窗口 0x%lx...\n", tray->tray_window);
    
    // 发送事件
    Status result = XSendEvent(tray->display, tray->tray_window, False, NoEventMask, &ev);
    X11UT__CHECK_ERROR(result != 0, "无法发送嵌入事件");
    
    XFlush(tray->display);
    
    // 等待一小段时间让托盘处理请求
    x11ut__msleep(100);
    
    // 现在映射窗口
    XMapWindow(tray->display, tray->window);
    XFlush(tray->display);
    
    tray->embedded = true;
    printf("已发送嵌入请求，窗口已映射\n");
    
    return true;
}

// ==================== 菜单函数 ====================

// 创建菜单
x11ut__menu_t* x11ut__menu_create(x11ut__tray_t* tray) {
    X11UT__CHECK_NULL(tray, "托盘指针为空");
    
    x11ut__menu_t* menu = malloc(sizeof(x11ut__menu_t));
    X11UT__CHECK_NULL(menu, "无法分配菜单内存");
    
    memset(menu, 0, sizeof(x11ut__menu_t));
    menu->item_height = 25;
    menu->width = 150;
    
    // 创建菜单窗口
    XSetWindowAttributes attrs;
    attrs.background_pixel = tray->bg_color;
    attrs.border_pixel = tray->fg_color;
    attrs.override_redirect = True;  // 跳过窗口管理器
    attrs.event_mask = ExposureMask | ButtonPressMask | ButtonReleaseMask | 
                       LeaveWindowMask | FocusChangeMask;
    
    menu->window = XCreateWindow(
        tray->display,
        RootWindow(tray->display, tray->screen),
        0, 0, menu->width, 0,  // 高度稍后设置
        1,
        CopyFromParent,
        CopyFromParent,
        CopyFromParent,
        CWBackPixel | CWBorderPixel | CWEventMask | CWOverrideRedirect,
        &attrs
    );
    
    if (menu->window == 0) {
        free(menu);
        fprintf(stderr, "错误: 无法创建菜单窗口\n");
        return NULL;
    }
    
    printf("菜单创建成功，窗口ID: 0x%lx\n", menu->window);
    return menu;
}

// 添加菜单项
bool x11ut__menu_add_item(x11ut__menu_t* menu, const char* label, 
                         void (*callback)(void*), void* user_data) {
    X11UT__CHECK_NULL(menu, "菜单指针为空");
    X11UT__CHECK_NULL(label, "标签为空");
    
    // 创建新菜单项
    x11ut__menu_item_t* new_item = malloc(sizeof(x11ut__menu_item_t));
    X11UT__CHECK_NULL(new_item, "无法分配菜单项内存");
    
    new_item->label = strdup(label);
    if (new_item->label == NULL) {
        free(new_item);
        fprintf(stderr, "错误: 无法复制标签字符串\n");
        return false;
    }
    
    new_item->callback = callback;
    new_item->user_data = user_data;
    new_item->id = menu->item_count;
    new_item->next = NULL;
    
    // 添加到链表末尾
    if (menu->items == NULL) {
        menu->items = new_item;
    } else {
        x11ut__menu_item_t* current = menu->items;
        while (current->next != NULL) {
            current = current->next;
        }
        current->next = new_item;
    }
    
    menu->item_count++;
    menu->height = menu->item_count * menu->item_height;
    
    printf("添加菜单项: %s (ID: %d)\n", label, new_item->id);
    return true;
}

// 绘制菜单
void x11ut__menu_draw(x11ut__tray_t* tray, x11ut__menu_t* menu) {
    if (!tray || !tray->display || !menu || menu->window == 0) return;
    
    // 创建临时GC
    GC gc = XCreateGC(tray->display, menu->window, 0, NULL);
    if (!gc) return;
    
    // 设置颜色
    XSetForeground(tray->display, gc, tray->bg_color);
    XFillRectangle(tray->display, menu->window, gc, 0, 0, menu->width, menu->height);
    
    XSetForeground(tray->display, gc, tray->fg_color);
    XSetBackground(tray->display, gc, tray->bg_color);
    
    // 绘制菜单项
    x11ut__menu_item_t* item = menu->items;
    int y = 2;
    
    while (item != NULL) {
        // 绘制文本
        XDrawString(tray->display, menu->window, gc, 10, y + 15, item->label, strlen(item->label));
        
        // 绘制分隔线
        if (item->next != NULL) {
            XDrawLine(tray->display, menu->window, gc, 5, y + menu->item_height - 1, 
                     menu->width - 5, y + menu->item_height - 1);
        }
        
        y += menu->item_height;
        item = item->next;
    }
    
    // 绘制边框
    XDrawRectangle(tray->display, menu->window, gc, 0, 0, menu->width - 1, menu->height - 1);
    
    XFreeGC(tray->display, gc);
}

// 显示菜单
void x11ut__menu_show(x11ut__tray_t* tray, x11ut__menu_t* menu, int x, int y) {
    if (!tray || !tray->display || !menu || menu->window == 0) return;
    
    // 调整位置（确保在屏幕内）
    int screen_width = DisplayWidth(tray->display, tray->screen);
    int screen_height = DisplayHeight(tray->display, tray->screen);
    
    if (x + menu->width > screen_width) {
        x = screen_width - menu->width - 10;
    }
    if (y + menu->height > screen_height) {
        y = screen_height - menu->height - 10;
    }
    
    // 移动和调整大小
    XMoveWindow(tray->display, menu->window, x, y);
    XResizeWindow(tray->display, menu->window, menu->width, menu->height);
    
    // 绘制菜单
    x11ut__menu_draw(tray, menu);
    
    // 映射窗口
    XMapWindow(tray->display, menu->window);
    XRaiseWindow(tray->display, menu->window);
    
    menu->visible = true;
    XFlush(tray->display);
    
    printf("显示菜单于 (%d, %d)\n", x, y);
}

// 隐藏菜单
void x11ut__menu_hide(x11ut__tray_t* tray, x11ut__menu_t* menu) {
    if (!tray || !tray->display || !menu || menu->window == 0 || !menu->visible) return;
    
    XUnmapWindow(tray->display, menu->window);
    menu->visible = false;
    XFlush(tray->display);
    
    printf("隐藏菜单\n");
}

// 处理菜单点击
static void x11ut__handle_menu_click(x11ut__tray_t* tray, x11ut__menu_t* menu, int x, int y) {
    if (!menu || !menu->visible) return;
    
    // 计算点击的菜单项
    int item_index = y / menu->item_height;
    
    x11ut__menu_item_t* item = menu->items;
    int current_index = 0;
    
    while (item != NULL && current_index < item_index) {
        item = item->next;
        current_index++;
    }
    
    if (item != NULL && item->callback != NULL) {
        printf("点击菜单项: %s\n", item->label);
        item->callback(item->user_data);
    }
    
    // 隐藏菜单
    x11ut__menu_hide(tray, menu);
}

// 清理菜单
void x11ut__menu_cleanup(x11ut__tray_t* tray, x11ut__menu_t* menu) {
    if (!menu) return;
    
    // 隐藏并销毁窗口
    if (tray && tray->display && menu->window != 0) {
        x11ut__menu_hide(tray, menu);
        XDestroyWindow(tray->display, menu->window);
    }
    
    // 释放菜单项
    x11ut__menu_item_t* item = menu->items;
    while (item != NULL) {
        x11ut__menu_item_t* next = item->next;
        free(item->label);
        free(item);
        item = next;
    }
    
    free(menu);
}

// ==================== 事件处理 ====================

// 处理按钮事件
void x11ut__tray_handle_button(x11ut__tray_t* tray, XButtonEvent* event) {
    if (!tray || !event) return;
    
    printf("按钮事件: 窗口 0x%lx, 按钮 %d, 位置 (%d, %d)\n",
           event->window, event->button, event->x, event->y);
    
    if (event->window == tray->window) {
        // 托盘图标被点击
        if (event->button == Button1 || event->button == Button3) {
            // 显示菜单
            if (tray->menu != NULL) {
                x11ut__menu_show(tray, tray->menu, event->x_root, event->y_root);
            }
        }
    } else if (tray->menu != NULL && event->window == tray->menu->window) {
        // 菜单被点击
        if (event->button == Button1) {
            x11ut__handle_menu_click(tray, tray->menu, event->x, event->y);
        }
    }
}

// 处理事件
bool x11ut__tray_process_events(x11ut__tray_t* tray) {
    X11UT__CHECK_NULL(tray, "托盘指针为空");
    X11UT__CHECK_NULL(tray->display, "显示连接未初始化");
    
    while (XPending(tray->display) > 0) {
        XEvent event;
        XNextEvent(tray->display, &event);
        
        switch (event.type) {
            case Expose:
                if (event.xexpose.window == tray->window) {
                    // 重绘托盘图标
                    XCopyArea(tray->display, tray->icon_pixmap, tray->window, tray->gc,
                              0, 0, tray->icon_width, tray->icon_height, 0, 0);
                } else if (tray->menu && event.xexpose.window == tray->menu->window) {
                    // 重绘菜单
                    x11ut__menu_draw(tray, tray->menu);
                }
                break;
                
            case ButtonPress:
                x11ut__tray_handle_button(tray, &event.xbutton);
                break;
                
            case LeaveNotify:
                // 鼠标离开菜单窗口时隐藏菜单
                if (tray->menu && event.xcrossing.window == tray->menu->window) {
                    x11ut__msleep(100);  // 短暂延迟
                    x11ut__menu_hide(tray, tray->menu);
                }
                break;
                
            case ClientMessage:
                // 处理客户端消息
                if (event.xclient.message_type == tray->net_system_tray_opcode) {
                    printf("收到系统托盘操作码消息\n");
                }
                break;
                
            case DestroyNotify:
                if (event.xdestroywindow.window == tray->window) {
                    printf("托盘窗口被销毁\n");
                    tray->running = false;
                }
                break;
                
            case MapNotify:
                if (event.xmap.window == tray->window) {
                    printf("托盘窗口已映射\n");
                }
                break;
                
            case UnmapNotify:
                if (event.xunmap.window == tray->window) {
                    printf("托盘窗口已取消映射\n");
                }
                break;
                
            default:
                // 忽略其他事件
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
            tray->menu = NULL;
        }
        
        // 清理资源
        if (tray->gc) {
            XFreeGC(tray->display, tray->gc);
        }
        
        if (tray->icon_pixmap != 0) {
            XFreePixmap(tray->display, tray->icon_pixmap);
        }
        
        if (tray->window != 0) {
            XDestroyWindow(tray->display, tray->window);
        }
        
        XFlush(tray->display);
        XCloseDisplay(tray->display);
    }
    
    memset(tray, 0, sizeof(x11ut__tray_t));
}

// ==================== 示例回调函数 ====================

// 退出回调
static void x11ut__exit_callback(void* data) {
    x11ut__tray_t* tray = (x11ut__tray_t*)data;
    if (tray) {
        printf("退出程序\n");
        tray->running = false;
    }
}

// 示例回调1
static void x11ut__example_callback1(void* data) {
    printf("示例回调1: %s\n", (char*)data);
}

// 示例回调2
static void x11ut__example_callback2(void* data) {
    printf("示例回调2\n");
}

// ==================== 主函数 ====================

int main(int argc, char* argv[]) {
    x11ut__tray_t tray;
    
    printf("=== X11 托盘图标程序 ===\n");
    
    // 初始化托盘
    if (!x11ut__tray_init(&tray, NULL)) {
        fprintf(stderr, "无法初始化托盘\n");
        return 1;
    }
    
    // 设置图标
    if (!x11ut__tray_set_icon(&tray, 64, 64, NULL)) {
        fprintf(stderr, "无法设置图标\n");
        x11ut__tray_cleanup(&tray);
        return 1;
    }
    
    // 等待系统托盘准备
    printf("等待系统托盘...\n");
    x11ut__msleep(1000);
    
    // 嵌入到系统托盘
    if (!x11ut__tray_embed(&tray)) {
        fprintf(stderr, "警告: 无法嵌入到系统托盘，继续运行...\n");
    }
    
    // 创建菜单
    tray.menu = x11ut__menu_create(&tray);
    if (tray.menu) {
        x11ut__menu_add_item(tray.menu, "选项 1", x11ut__example_callback1, "测试数据1");
        x11ut__menu_add_item(tray.menu, "选项 2", x11ut__example_callback2, NULL);
        x11ut__menu_add_item(tray.menu, "分隔线", NULL, NULL);
        x11ut__menu_add_item(tray.menu, "退出", x11ut__exit_callback, &tray);
    }
    
    printf("托盘程序运行中...\n");
    printf("点击托盘图标显示菜单\n");
    printf("按 Ctrl+C 退出程序\n\n");
    
    // 主事件循环
    int retry_count = 0;
    
    while (tray.running) {
        // 如果未嵌入，定期重试
        if (!tray.embedded && retry_count < 5) {
            static time_t last_retry = 0;
            time_t now = time(NULL);
            
            if (now - last_retry > 3) {  // 每3秒重试一次
                printf("尝试重新嵌入到系统托盘 (尝试 %d/5)...\n", retry_count + 1);
                if (x11ut__tray_embed(&tray)) {
                    printf("成功嵌入到系统托盘\n");
                }
                last_retry = now;
                retry_count++;
            }
        }
        
        // 处理事件
        if (!x11ut__tray_process_events(&tray)) {
            break;
        }
        
        // 短暂休眠
        x11ut__msleep(10);
        
        // 刷新显示
        XFlush(tray.display);
    }
    
    // 清理资源
    printf("正在清理资源...\n");
    x11ut__tray_cleanup(&tray);
    
    printf("程序退出\n");
    return 0;
}
