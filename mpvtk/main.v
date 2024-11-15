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

	pub mut:
	wid string
	mpvo voidptr

	mtid u64
	mpvcbtid u64

}
const gvars = &Globvars{}

fn main() {
	C.GC_allow_register_threads()
	if true {
		rv := C.mpv_client_api_version()
		vcp.info(rv)
	}
	// go uithproc()

	tcltk.tk_main(["helllo", "hehhe.tcl"], initui_done)
	vcp.info("hehere")
}

fn initui_done(irp voidptr) int {
	vcp.info("done", irp, vcp.gettid())
	gv := gvars
	gv.mtid = vcp.gettid()

	create_top_menus()
	create_winlo_begin()
	create_toolbar()	
	create_video_area()
	create_bottom_bar()
	create_playlist_view()
	create_winlo_end()
	create_systray()		
	return 0
}

fn create_mpvobj(wid string) {
	gv := gvars

	h := C.mpv_create()
	vcp.info(h)
	gv.mpvo = h
	C.mpv_request_event(h, C.MPV_EVENT_LOG_MESSAGE, 1)
	C.mpv_request_log_messages(h, c'info')
	C.mpv_set_wakeup_callback(h, mpv_wakeup_cb, voidptr(42))

	mut rv := 0

	vcp.info("VideoOutWin", gvars.wid, gvars.wid.len, gv.mpvo)
	assert gv.wid.starts_with('0x')
	// rv = C.mpv_set_option_string(h, c'wid', gvars.wid.str)
	// check_mpvret(rv)

	mut opts := []string{}
	opts << "wid"; opts << gvars.wid
	// opts << "x11-bypass-compositor"; opts << "no"
	// opts << "input-default-bindings"; opts << "no"
	// opts << "input-vo-keyboard"; opts << "no"
	// opts << "load-scripts" << "no"
	// opts << "player-operation-mode"; opts << "pseudo-gui"
	// opts << "vo"; opts << "gpu" // "gpu,libmpv,x11,xv"
	for i:=0; i < opts.len; i+= 2{
		rv = C.mpv_set_option_string(h, opts[i].str, opts[i+1].str)
		vcp.info(i.str(), rv, opts[i], opts[i+1])
		check_mpvret(rv, opts[i], opts[i+1])
	}

	// time.sleep(time.second)
	rv = C.mpv_initialize(h)
	vcp.info(rv)
	check_mpvret(rv)

	// time.sleep(time.second)
	// todo 有时无图像,但有声音,
	// 播放正常,可能是无法正确嵌入tcltk窗口
	// 尝试一种可能的解决方案,用xlib创建窗口,看能不能放到tcltk的layout中
	// mut loadfile := "loadfile "
	// loadfile += if os.args.len>1{ os.args[1]} else {"hello.mp4"}
	// rv = C.mpv_command_string(h, loadfile.str)
	// rv = C.mpv_command_string(h, c"loadfile hello.mp4")

	// cmdargs := [charptr('loadfile'.str), charptr(os.args[1].str), vnil]
	// rv = C.mpv_command_async(h, 12345, cmdargs.data)
	// vcp.info(rv)
	// check_mpvret(rv)
}

fn mpv_play_one(file string) {
	gv := gvars
	h := gvars.mpvo
	mut rv := 0
	
	// todo 有时无图像,但有声音,
	// 播放正常,可能是无法正确嵌入tcltk窗口
	// 尝试一种可能的解决方案,用xlib创建窗口,看能不能放到tcltk的layout中
	mut loadfile := "loadfile "
	loadfile += if os.args.len>1{ os.args[1]} else {"hello.mp4"}
	// rv = C.mpv_command_string(h, loadfile.str)
	// rv = C.mpv_command_string(h, c"loadfile hello.mp4")

	cmdargs := [charptr('loadfile'.str), charptr(os.args[1].str), vnil]
	cmdargs.firstz()
	vcp.info(cmdargs.len, cmdargs.str(), os.args[1])
	rv = C.mpv_command_async(h, 12345, cmdargs.clone().data)
	// rv = C.mpv_command_string(h, loadfile.clone().str)
	vcp.info(rv)
	check_mpvret(rv)
}

fn C.GC_thread_is_registered() cint
fn mpv_wakeup_cb(ctx voidptr) {
	if true {mpv_wakeup_cb1(ctx)}
	else {mpv_wakeup_cb2(ctx)}
}
fn mpv_wakeup_cb1(ctx voidptr) {
	mpvo := gvars.mpvo
	for i:=0; i < 50000; i++ {
		evox := C.mpv_wait_event(mpvo, 0)
		evo := castptr[mpv.Event](evox)
		if evo.event_id == C.MPV_EVENT_NONE {
			break
		}
	}
}
// 难道是这个函数处理太复杂,导致经常播放无响应???
fn mpv_wakeup_cb2(ctx voidptr) {
	if true {return}
	gv := gvars
	ctid := vcp.gettid()
	// assert ctid == gvars.mtid
	if ctid != gvars.mpvcbtid {
		gv.mpvcbtid = ctid
		if C.GC_thread_is_registered() != 1 {
		sb := C.GC_stack_base{}
		C.GC_get_stack_base(&sb)
		C.GC_register_my_thread(&sb)
		}
	}

	// println("mpvcb ${ctx}") // no crash
	// related to GC??? Collecting from unknown thread
	// vcp.info(ctx) // all vcp.info crash
	for i:=0; i < 50000; i++ {
		evox := C.mpv_wait_event(gvars.mpvo, 0)
		evo := castptr[mpv.Event](evox)
		evname := tosbca(C.mpv_event_name(evo.event_id))
		// println("${@FILE_LINE}, ${evo}")
		// vcp.info(i.str(), evo.str().compact())
		if evo.event_id == C.MPV_EVENT_NONE {
			break
		} else if evo.event_id == C.MPV_EVENT_LOG_MESSAGE {
			msgo := castptr[mpv.EventLogMessage](evo.data)
			vcp.info(i.str(), tosbca(msgo.prefix), tosbca(msgo.level), tosbca(msgo.text))
		}else{
			vcp.info(i.str(),evname, evo.str().compact())
		}
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
