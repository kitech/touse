import vcp
import  vcp.tcltk

fn main() {
	tcltk.tk_main(["helllo world", "hehhe.tcl"], uimain)
}

fn uimain(tclirp voidptr) int {
	rc := tcltk.tk_init(tclirp)
	vcp.falseprt(rc==tcltk.tclok, "somerr", rc)
	return rc
}
