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
const cfgfile = "mpvtk.toml"

fn main() {
	// C.GC_allow_register_threads()
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

// if run in home dir, then find theme file in exe dir
// if run in system dir, then find theme in ../share/exename/
pub fn cfgdir_resolve() string {
	dir := vcp.exedir
	if dir.starts_with(vcp.homedir) {
		return dir
	}else{
		return os.join_path("", vcp.homedir, ".config/mpvtk")
	}
}

pub fn path_reverse(file string) string {
	arr := file.split('/')
	arr2 := arr.reverse()
	return arr2.join('/')
}
pub fn path_escape_fortk(v string) string {
	if v.contains('[') {
		v = v.replace('[', '\\[')
		v = v.replace(']', '\\]')
	}
	return v
}

pub fn load_playlist_toui() {
	gvars.plst.load()

	plst := gvars.plst
	for e in plst.list {
		v := path_reverse(e)
		v = path_escape_fortk(v)
		gvars.plstvw.add(v)
	}
	// for i in 10..29 {
	// 	gvars.plstvw.add('fakeit5${i}')
	// }
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
