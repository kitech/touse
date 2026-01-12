module x11ut
import os

#flag @DIR/x11tray.o
#pkgconfig fontconfig
#flag -lX11 -lXft -lXrender -lXpm -ljpeg -lpng -lm
#flag -DX11UT_CCODE_ASLIB

c99 { // all return > sizeof(int) funcs
    extern void* x11ut__tray_new();
    extern void* x11ut__menu_create(void*);
}

// should block, spawn by caller
@[importc: 'x11ut_main_aslib']
pub fn main_demo(argc int, argv &charptr) int

pub type Tray = voidptr

@[importc: 'x11ut__tray_new'] pub fn Tray.new() Tray
@[importc: 'x11ut__tray_init'] pub fn (t Tray) init(display_name charptr) bool
@[importc: 'x11ut__tray_cleanup'] pub fn (t Tray) cleanup()
@[importc: 'x11ut__tray_embed'] pub fn (t Tray) embed()
@[importc: 'x11ut__tray_process_events'] pub fn (t Tray) process_events() bool

pub struct Menu  {
    pub:
    t Tray
    cm voidptr
}

@[importc: 'x11ut__menu_create'] fn menu_create(t Tray) voidptr

pub fn (t Tray) newMenu() Menu {
    m := menu_create(t)
    return Menu{t, m}
}

@[importc: 'x11ut__menu_cleanup'] fn menu_cleanup(t Tray, m voidptr)

pub fn (m Menu) cleanup() {
    menu_cleanup(m.t, m.cm)
}
