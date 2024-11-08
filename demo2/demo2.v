import time
import os

import vcp
import  vcp.tcltk

struct Globvars {
	pub mut:
	lb tcltk.Labelframe
	btns []tcltk.Button
}
const gvars = &Globvars{}

fn main() {
	// go uithproc()

	tcltk.tk_main(["helllo", "hehhe.tcl"], initui_done)
	vcp.info("hehere")
}

fn initui_done(irp voidptr) int {
	vcp.info("done", irp)
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
		}, vnil)
	}

	closebtn := tcltk.Button.new("close")
	closebtn.connect(fn(cbval voidptr, args[]string){
		vcp.info("closing...", time.since(vcp.starttime).str())
		tcltk.Systray.destroy()
		exit(0)
	}, vnil)
	lb.pack(closebtn)
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
