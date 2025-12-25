module fswatch

import log
import time
import vcp
import vcp.venv

// fswatch-1.18.3
// patch, inotify_monitor.cpp:236, add flow line
/*
    if (event->mask & IN_MOVED_TO) flags.push_back(fsw_event_flag::MovedTo);
	if (event->mask & IN_MOVED_FROM) flags.push_back(fsw_event_flag::MovedFrom);
	
	if ((event->mask & IN_MOVED_TO) || (event->mask & IN_MOVED_FROM)) {
		impl->events.clear();
	} */

// #pkgconfig libfswatch
#flag -lfswatch
#flag -I /opt/devsys/include/libfswatch/c/
// #flag -I $env('DEVSYS_DIR')/include/libfswatch/c/

#include "libfswatch.h"

pub type Handle = voidptr

// not need manual call, libfswatch would call auto
pub fn init_library() int {
    c99 { int rv = fsw_init_library(); }
    return C.rv
}

pub enum MonitorType {
    system_default_monitor_type = 0 /**< System default monitor. */
    fsevents_monitor_type           /**< macOS FSEvents monitor. */
    kqueue_monitor_type             /**< BSD `kqueue` monitor. */
    inotify_monitor_type            /**< Linux `inotify` monitor. */
    windows_monitor_type            /**< Windows monitor. */
    poll_monitor_type               /**< `stat()`-based poll monitor. */
    fen_monitor_type                 /**< Solaris/Illumos monitor. */
}

pub fn new_with_type(monty MonitorType) Handle {
    c99 { void* rv = fsw_init_session(monty); }
    h := Handle(C.rv)
    rv2 := h.set_callback()
    assert rv2 == ok
    return h
}
pub fn new() Handle {
    return new_with_type(.system_default_monitor_type)
}

pub enum Flag {
    noop = 0
    platform_specific = C.PlatformSpecific
    created = C.Created
    updated = C.Updated
    removed = C.Removed
    renamed = C.Renamed
    owner_modified = C.OwnerModified
    attribute_modified = C.AttributeModified
    moved_from = C.MovedFrom
    moved_to = C.MovedTo
    is_file = C.IsFile
    is_dir = C.IsDir
    is_symlink = C.IsSymLink
    link = C.Link
    overflow = C.Overflow
    close_write = C.CloseWrite
}

pub const (
    ok = C.FSW_OK
)

@[typedef]
pub struct C.fsw_cevent {
    pub mut:
    path charptr
    // evt_time C.time_t
    evt_time usize
    flags &Flag = vnil
    flags_num int
}

pub type CEvent = C.fsw_cevent


pub struct Event {
    pub:
    orig string
    name string
    mask Flag
    flags []Flag
    // ctime time.Time
}

fn c2v_event(evt &CEvent, wtdirs []string) &Event {
    res := &Event{}
    path := evt.path.tosdup()
    for wtdir in wtdirs {
        if path.starts_with(wtdir) {
            res.orig = wtdir
            res.name = if path==wtdir {""} else { path[wtdir.len+1..] }
            break
        }
    }
    assert res.orig != ""
    // assert res.name != ""
        
    if evt.flags_num > 1 {
        res.flags = carr2varr[Flag](evt.flags, evt.flags_num)
    }
    res.mask = evt.flags[0]

    ctime := time.unix(i64(evt.evt_time))
    if time.since(ctime) > 5*time.second {
        vcp.warn("solong???", ctime)
        //     res.ctime = ctime
    }
    // if res.name == "" {vcp.warn(evt.str(), res.str())}
    return res
}

type CEventCallback4c = fn(&CEvent, int, voidptr)
pub type CEventCallback = fn(Event, voidptr)

struct Globvars {
    pub mut:
    watch_dirs map[string]int
    callbacks map[Handle][]Tuple3[Handle,voidptr,voidptr] // => (Handle, cbdata, cbfn)
}
const gvs = &Globvars{}

// evts is a array of len evnum!!!
fn on_cevent_callback(evts &CEvent, evnum int, data voidptr) {
    // vcp.info('evnum', evnum, data)
    wtdirs := gvs.watch_dirs.keys()
    arr1 := carr2varr[CEvent](evts, evnum)
    arr2 := []Event{}
    for e in arr1 { arr2 << c2v_event(e, wtdirs) }
    
    h := Handle(data)
    lst := gvs.callbacks[h]
    for t in lst {
        f := CEventCallback(t.third)
        for ev in arr2 {
            f(ev, t.second)
        }
    }
}

pub fn (h Handle) add_callback(cbfn CEventCallback, data voidptr) int {
    gvs.callbacks[h] << Tuple3.new(h, data, voidptr(cbfn))
    return ok
}
fn (h Handle) set_callback() int {
    cbfn4c := on_cevent_callback
    c99 { int rv = fsw_set_callback(h, cbfn4c, h); }
    return C.rv
}

pub fn (h Handle) add_path(path string) int {
    // path4c := path.str
    c99 { int rv = fsw_add_path(h, path.str); }
    gvs.watch_dirs[path] = C.rv
    return C.rv
}
pub fn (h Handle) add_property(name string, value string) int {
    // path4c := path.str
    c99 { int rv = fsw_add_property(h, name.str, value.str); }
    return C.rv
}

pub fn (h Handle) start_monitor() int {
    c99 { int rv = fsw_start_monitor(h); }
    return C.rv
}
pub fn (h Handle) stop_monitor() int {
    c99 { int rv = fsw_stop_monitor(h); }
    return C.rv
}
pub fn (h Handle) is_running() bool {
    c99 { int rv = fsw_is_running(h); }
    return C.rv != 0
}

pub fn (h Handle) destroy() int {
    // path4c := path.str
    c99 { int rv = fsw_destroy_session(h); }
    return C.rv
}

pub fn last_error() int {
    c99 { int rv = fsw_last_error(); }
    return C.rv
}

pub fn flag_name(flag Flag) string {
    c99 { char* name = fsw_get_event_flag_name(flag); }
    return charptr(C.name).tosref()
}

pub fn (h Handle) set_follow_symlinks(v bool) int {
    c99 { int rv = fsw_set_follow_symlinks(h, v); }
    return C.rv
}
pub fn (h Handle) set_recursive(v bool) int {
    c99 { int rv = fsw_set_recursive(h, v); }
    return C.rv
}
pub fn (h Handle) set_directory_only(v bool) int {
    c99 { int rv = fsw_set_directory_only(h, v); }
    return C.rv
}
pub fn (h Handle) set_latency(v f64) int {
    c99 { int rv = fsw_set_latency(h, v); }
    return C.rv
}
