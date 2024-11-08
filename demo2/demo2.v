import time
import vcp
import  vcp.tcltk

fn main() {
	go uithproc()

	tcltk.tk_main(["helllo", "hehhe.tcl"], vnil)
	vcp.info("hehere")
}

fn uithproc() {
	for {
		time.sleep(time.second)
	tcltk.eval("package require Tk")
	tcltk.eval("tk systray exists")
	}
}