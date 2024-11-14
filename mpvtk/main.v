import time
import os

import vcp
import  vcp.tcltk
import  vcp.mpv
// 不链接libmpv 30M, 链接了之后90M,初始化后??M,播放时120M
// 单纯的 mpv 窗口 108M

struct Globvars {
	pub mut:
	lb tcltk.Labelframe
	btns []tcltk.Button
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

	create_btns()
	create_systray()
	return 0
}

fn create_systray() {
	st := tcltk.Systray.new("sty123")
	st.exists()

	tcltk.Sysnotify.send("heheh",  "notifyeddd")
}

fn create_btns() {
	lb := tcltk.Labelframe.new("labeliss")
	for i in 0..8 {
		btn := tcltk.Button.new("test btn${i}")
		lb.pack(btn)
		btn.connect(fn(cbval voidptr, args []string){
			vcp.info("hehhe", cbval, args.str())
			create_mpvobj(gvars.wid)
		}, vnil)
	}

	closebtn := tcltk.Button.new("close")
	closebtn.connect(fn(cbval voidptr, args[]string){
		vcp.info("closing...", time.since(vcp.starttime).str())
		tcltk.Systray.destroy()
		exit(0)
	}, vnil)
	lb.pack(closebtn)

	//
	frm := tcltk.Frame.new()
	lb.pack(frm)

	wid := frm.id().clone()
	vcp.info("wid", wid, frm.name())
	gv := gvars
	gv.wid = wid 

	// create_mpvobj(wid)
}

fn create_frms() {

}

fn create_mpvobj(wid string) {
	gv := gvars

	h := C.mpv_create()
	vcp.info(h)
	gv.mpvo = h
	C.mpv_set_wakeup_callback(h, mpv_wakeup_cb, voidptr(42))

	mut rv := 0

	vcp.info(gvars.wid, gvars.wid.len, gv.mpvo)
	assert gv.wid.starts_with('0x')
	rv = C.mpv_set_option_string(h, c'wid', gvars.wid.str)
	// rv = C.mpv_set_option_string(h, c'wid', c'0x180001a')
	check_mpvret(rv)

	opts := ["wid", wid] // "vo", "xv"
	for i:=0; i < opts.len; i+= 2{
		// rv = C.mpv_set_option_string(h, opts[i].str, opts[i+1].str)
		// vcp.info(i.str(), rv, opts[i], opts[i+1])
	}
	rv = C.mpv_set_option_string(h, c'vo', c'xv')
	// vcp.info(i.str(), rv, opts[i], opts[i+1])
	check_mpvret(rv)

	// time.sleep(time.second)
	rv = C.mpv_initialize(h)
	vcp.info(rv)
	check_mpvret(rv)

	// time.sleep(time.second)
	// todo 有时无图像,但有声音,
	// 播放正常,可能是无法正确嵌入tcltk窗口
	// 尝试一种可能的解决方案,用xlib创建窗口,看能不能放到tcltk的layout中
	mut loadfile := "loadfile "
	loadfile += if os.args.len>1{ os.args[1]} else {"hello.mp4"}
	// rv = C.mpv_command_string(h, loadfile.str)
	// rv = C.mpv_command_string(h, c"loadfile hello.mp4")

	cmdargs := [charptr('loadfile'.str), charptr(os.args[1].str), vnil]
	rv = C.mpv_command_async(h, 12345, cmdargs.data)
	vcp.info(rv)
	check_mpvret(rv)
}

fn C.GC_thread_is_registered() cint
fn mpv_wakeup_cb(ctx voidptr) {
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
		// println("${@FILE_LINE}, ${evo}")
		vcp.info(i.str(), evo.str().compact())
		if evo.event_id == C.MPV_EVENT_NONE {
			break
		}
	} 
}
fn check_mpvret(code int) {
	if code != C.MPV_ERROR_SUCCESS {
		msg4c := C.mpv_error_string(code)
		vcp.info(code, tosbca(msg4c))
	}
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
