module pftray

import os

// some code from:
// https://github.com/zserge/tray
// https://github.com/dmikushin/tray
// https://github.com/getlantern/systray

$if windows {
    $flag @DIR/tray_windows.o
} $else $if macos {
    // need manual compile this .o
    // cc -c tray_darwin.m
    #flag @DIR/tray_darwin.o
    $if tinyc {
        #flag -L @DIR/macsys/lib
        // #flag -lCocoa
        #flag -lAppKit
        #flag -lFoundation
    } $else {
        #flag -framework Cocoa
    }
} $else {
    $if withqt6 ? {
        #flag @DIR/tray_linux.o
    } $else $if withgtk3 ? {
        // #pkgconfig gtk+-3.0
        #flag -layatana-appindicator3 -lgtk-3 -lgobject-2.0
        #flag -I /usr/include/libayatana-appindicator3-0.1/
        // TODO libayatana-appindicator
        #flag @DIR/tray_linux_gtk3.o
        // TODO from getlantern/systray, go version
        // #flag @DIR/systray_linux.o
    } $else $if withgtk3_appindicator3 ? {
        // on my system, appindicator3 depend gtk3
        #pkgconfig --cflags gtk-3
        #pkgconfig --cflags appindicator3-0.1
        #flag -lappindicator3 -lgtk-3 -lgobject-2.0
        // TODO
    } $else $if withgtk2_appindicator3 ? {
        #pkgconfig --cflags gtk+-2.0
        #pkgconfig --cflags appindicator3-0.1
        #flag -lappindicator3 -lgtk-x11-2.0 -lgobject-2.0
        // TODO
    } $else {
        // appindicator1 for gtk2
        #pkgconfig --cflags gtk+-2.0
        #pkgconfig --cflags appindicator-0.1
        #flag -lappindicator -lgtk-x11-2.0 -lgobject-2.0
        #flag @DIR/tray_linux_gtk2.o
    }
}

#flag -DPFTRAY_MAIN_ASLIB -DVCPMODPFX=touse__pftray
#flag @DIR/example.o
#include "@DIR/tray.h"

////////////

pub type Tray = C.tray
pub struct C.tray {
    pub mut:
    icon_filepath charptr
    tooltip charptr
    cb  fn(Tray) = nil
    menu &Item = nil // C array of Item, last item must zeroed
}

pub type Item = C.tray_menu_item
pub struct C.tray_menu_item {
    text charptr = nil
    disabled int
    checked  int
    cb  fn(&Item) = nil
    submenu  &Item = nil // C array of Item, last item must zeroed
}

// example Tray instance in V
// see example.c
const tray = &Tray {
    icon_filepath: c'icon2.png', tooltip: c'Pftray',
    cb: nil,
    menu: [Item{}, Item{}].data
    // menu: menu.data // if created other place
}
const menu = [Item{}, Item{}]

fn C.tray_init(&Tray)
fn C.tray_loop(blocking int) int
fn C.tray_update(&Tray)
fn C.tray_exit()
fn C.tray_get_instance() &Tray

pub fn (t &Tray) init() { C.tray_init(t) }
pub fn (t &Tray) loop(blocking bool) bool {
    return C.tray_loop(blocking.toc()) == 0
}
pub fn (t &Tray) update() { C.tray_update(t) }
pub fn (t &Tray) exit() { C.tray_exit() }

pub fn (t &Tray) set_icon(iconpath string) {
    t.icon_filepath = iconpath.str
}
pub fn (t &Tray) set_tooltip(tip string) {
    t.tooltip = tip.str
}
pub fn get_instance() &Tray { return C.tray_get_instance() }

@[unsafe]
pub fn get_demo_tray() &Tray

// usage: t := &Tray{...}
// t.init()
// for t.loop(false) { time.sleep(100*time.millisecond) }
// or in other loop, call with timer 100ms, t.loop(false)

////////////
const argv4c = [9]charptr{}

fn C.main_aslib(...voidptr) int
// must run on main thread on macos
pub fn main_demo(args ... string) {
    for i, arg in args {
        if i >= 9 { break }
        argv4c[i] = arg.str
    }
	C.main_aslib(args.len, &argv4c[0])
}
