module libnotify

// seems gnotification is successor of libnotify

import time
// import mkuse.vpp.xlog
import vcp

#flag -lgio-2.0
// #include "gio/gnotification.h"
#include "gio/gio.h"

fn C.g_notification_new(title byteptr) voidptr
fn C.g_notification_set_title(voidptr, byteptr)
fn C.g_notification_set_body(voidptr, byteptr)
fn C.g_notification_set_icon(voidptr, byteptr)
fn C.g_notification_set_urgent(voidptr, byte)
fn C.g_notification_set_priority(voidptr, int)
fn C.g_notification_add_button(voidptr, byteptr, byteptr)
fn C.g_notification_set_default_action(voidptr, byteptr)
fn C.g_notification_set_default_action_and_target_value(voidptr, byteptr, byteptr)
fn C.g_application_new(... voidptr) voidptr
fn C.g_application_register(... voidptr) bool
fn C.g_application_send_notification(... voidptr)

struct Gnotification {
mut:
	gapp voidptr
	notion voidptr
	ctime time.Time
	timeoutms int
	title string
	body string
	icon string
	urgent bool
}
fn gnotification_fromptr(ptr voidptr) &Gnotification{
    return unsafe {&Gnotification(ptr)}
}
fn new_gnotification(gapp voidptr) &Gnotification{
	mut nter := &Gnotification{}
	nter.gapp = gapp
	nter.ctime = time.now()
    str1 := 'toast'
	nter.notion = C.g_notification_new(str1.str)
	return nter
}
fn (nter mut Gnotification) set_timeout(timeoutms int) {
	nter.timeoutms = timeoutms
}
fn (nter mut Gnotification) set_title(title string) {
	nter.title = title
	C.g_notification_set_title(nter.notion, title.str)
}
fn (nter mut Gnotification) set_body(body string) {
	nter.body = body
	C.g_notification_set_body(nter.notion, body.str)
}
fn (nter mut Gnotification) set_icon(icon string) {
	nter.icon = icon
}
fn (nter mut Gnotification) close() {
	nter.notion = vnil
}
fn (nter mut Gnotification) show() {
	C.g_application_send_notification(nter.gapp, 0, nter.notion)
}

// 问题
// 需要g_main_loop
// 可能是 相应 fd没有hook到，并且是阻塞的，不能用于corona fiber
pub struct Gnotify {
mut:
	gapp voidptr
	nters []u64
	timeoutms int
}

pub fn newgnotify(timeoutms int) &Gnotify {
	mut nty := &Gnotify{}
	nty.timeoutms = timeoutms
	nty.gapp = C.g_application_new(0, 0)
	bv := C.g_application_register(nty.gapp, 0, 0)
	return nty
}

pub fn (nty mut Gnotify) add(summary string, body string, icon string, timeoutms int) {
	mut nter := new_gnotification(nty.gapp)
	nty.nters << u64(nter)
	nter.set_timeout(timeoutms)
	nter.set_title(summary)
	nter.set_body(body)
	nter.set_icon(icon)
	nter.show()

	nty.clear_expires()
}

pub fn (nty mut Gnotify) replace(summary string, body string, icon string, timeoutms int) {
	if nty.nters.len <= 0 {
		nty.add(summary, body, icon, timeoutms)
		return
	}
	nterx := nty.nters[nty.nters.len-1]
	mut nter := gnotification_fromptr (nterx)
	nter.set_title(summary)
	nter.set_body(body)
	nter.set_icon(icon)

	nty.clear_expires()
}

fn (nty mut Gnotify) clear_expires() {
	if abs0_ {
		nty.timeoutms = nty.timeoutms
	}
	n := nty.nters.len
	vcp.info('totn=$n')
	nowt := time.now()

	mut news := []u64{}
	for nterx in nty.nters {
        mut nter := gnotification_fromptr (nterx)
		if nowt.unix() - nter.ctime.unix() > 2*nter.timeoutms/1000 {
			nter.close()
			free(nter)
		}else{
			news << nterx
		}
	}
	if news.len != nty.nters.len {
		olds := nty.nters
		nty.nters = news
		deln := olds.len - news.len
		vcp.info('deln=$deln')
		olds.free()
	}else{
		news.free()
	}
}
