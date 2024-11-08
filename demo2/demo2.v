import time
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
	return 0
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
}

fn uithproc() {
	for {
		time.sleep(time.second)
	// tcltk.eval("package require Tk")
	// tcltk.eval("tk systray exists")
	tcltk.Button.new("test but111")
	}
}
