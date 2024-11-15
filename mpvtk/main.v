import time
import os

import vcp
import  vcp.tcltk
import  vcp.mpv
// 不链接libmpv 30M, 链接了之后89M,初始化后93M,播放时120M
// 单纯的 mpv 窗口 108M

struct Globvars {
	/// ui
	Uicomp
	Bkdlibmpv

	pub mut:
	wid string
	mpvo voidptr

	mtid u64
	mpvcbtid u64

	logch chan voidptr = chan voidptr {cap: 128}
	savch chan int = chan int{cap: 8}
	plst &Playlist = &Playlist{}
}
const gvars = &Globvars{}

fn main() {
	C.GC_allow_register_threads()
	if true {
		rv := C.mpv_client_api_version()
		vcp.info(rv)
	}
	// go uithproc()
	go mpvlog_fwdproc()

	tcltk.tk_main(["helllo", "hehhe.tcl"], initui_done)
	vcp.info("hehere")
}

fn initui_done(irp voidptr) int {
	vcp.info("done", irp, vcp.gettid())
	gv := gvars
	gv.mtid = vcp.gettid()

	load_theme()

	create_top_menus()
	create_winlo_begin()
	create_toolbar()	
	create_video_area()
	create_bottom_bar()
	create_playlist_view()
	create_winlo_end()
	create_systray()		

	load_playlist_toui()
	return 0
}

// if run in home dir, then find theme file in exe dir
// if run in system dir, then find theme in ../share/exename/
pub fn load_theme() {
	themedir := vcp.exedir
	themefile := themedir + "/forest-dark.tcl"
	if !os.exists(themefile) {
		themefile = themedir + "../share/mpvtk/forest-dark.tcl"
	}
	if !os.exists(themefile) {
		vcp.warn("Cannot find theme file", os.base(themefile))
		return
	}
	tcltk.eval('source ${themefile}')
	// https://github.com/rdbende/Forest-ttk-theme
	// tcltk.eval('source ${vcp.homedir}/aprog/tkBreeze/breeze-dark/breeze-dark.tcl')
	// tcltk.eval('source ${vcp.homedir}/aprog/Forest-ttk-theme/forest-dark.tcl')
}

pub fn path_reverse(file string) string {
	arr := file.split('/')
	arr2 := arr.reverse()
	return arr2.join('/')
}

pub fn load_playlist_toui() {
	gvars.plst.load()

	plst := gvars.plst
	for e in plst.list {
		v := path_reverse(e)
		gvars.plstvw.add(v)
	}
	// for i in 10..29 {
	// 	gvars.plstvw.add('fakeit5${i}')
	// }
}

fn C.GC_thread_is_registered() cint
fn mpv_wakeup_cbproc(ctx voidptr) {
	if true {mpv_wakeup_cb1(ctx)}
}
// 难道是这个函数处理太复杂,导致经常播放无响应??? 确实
// dont malloc memory useing gc
// only use C.printf
fn mpv_wakeup_cb1(ctx voidptr) {
	isgcth := C.GC_thread_is_registered() == 1 
	if !isgcth {
		// C.printf(c'thread not gc managed %d\n', vcp.gettid())
	}
	// vcp.gcreg_mythread()

	mpvo := gvars.mpvo
	for i:=0; i < 50000; i++ {
		evox := C.mpv_wait_event(mpvo, 0)
		evo := castptr[mpv.Event](evox)
		if evo.event_id == C.MPV_EVENT_NONE {
			break
		}
		// evox2 := cmemdup(evox, sizeof(mpv.Event))
		// evo2 := castptr[mpv.Event](evox2)
		// evo2.data = vnil

		evid := int(evo.event_id)
		evname := C.mpv_event_name(evo.event_id)
		// match evid {
		// use vbug works, const == var, but not var == const
		if mpv.EVENT_LOG_MESSAGE == evid {
			msgo := castptr[mpv.EventLogMessage](evo.data)
			// C.printf(c'mpv_wakeup_cb:77: %d %s: %s', i, evname, msgo.text)
			// evo2.data = cmemdup(evo.data, sizeof(mpv.EventLogMessage))	
			// vcp.freerc(ptr)
			// println('${@FILE_LINE}: ${tosbca(evname)}, ${tosbca(msgo.text)}')
			// x := '${@FILE_LINE}: ${tosbca(evname)}, ${tosbca(msgo.text)}'
		}
		else {
			// C.printf(c'mpv_wakeup_cb:80: %d %s ...\n', i, evname)	
		}
		// }

		gvars.logch <- evox
	}
			
}

fn check_mpvret(code int, what ... string) bool {
	if code != C.MPV_ERROR_SUCCESS {
		msg4c := C.mpv_error_string(code)
		vcp.info(code, tosbca(msg4c), what.str())
		return false
	}
	return true
}

fn uithproc() {
	for idx:=0;; idx++ {
		time.sleep(time.second)
	// tcltk.eval("package require Tk")
	// tcltk.eval("tk systray exists")
	// tcltk.Button.new("test but111")
	// 非UI线程crash，似乎不能这么用
	// tcltk.Sysnotify.send("heheh${idx}", "notfyed 通知 dd ${idx}")
	}
}
