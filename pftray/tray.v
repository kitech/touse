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
    #flag -framework Cocoa
} $else {
    $if withqt6 ? {
        #flag @DIR/tray_linux.o
    } $else $if withgtk3 ? {
        #pkgconfig gtk+-3.0
        #flag -layatana-appindicator3
        #flag -I /usr/include/libayatana-appindicator3-0.1/
        // TODO libayatana-appindicator
        #flag @DIR/tray_linux_gtk3.o
        // TODO from getlantern/systray, go version
        // #flag @DIR/systray_linux.o
    } $else {
        // appindicator for gtk2
        #pkgconfig gtk+-2.0
        #pkgconfig appindicator-0.1
        // #flag -lappindicator
        #flag @DIR/tray_linux_gtk2.o
    }
}

#flag -DPFTRAY_INLIB -I@DIR/
#flag @DIR/example.o

const argv4c = [9]charptr{}

fn C.main_aslib(...voidptr) int
pub fn main_demo(args ... string) {
    for i, arg in args {
        if i >= 9 { break }
        argv4c[i] = arg.str
    }
	C.main_aslib(args.len, &argv4c[0])
}
