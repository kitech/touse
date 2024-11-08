module tcltk

import  os
import vcp

struct Globvars {
	pub mut:
	argv []voidptr
	tclir voidptr
}
const gvars = &Globvars{}

pub fn tk_main2(init_tcl_file string, init_proc fn(ir voidptr) int) {
		args := [os.base(init_tcl_file), init_tcl_file]
		tk_main(args, init_proc)
}
pub fn tk_main(args []string, init_proc fn(ir voidptr) int) {
	mut gvs := refvar2mut(gvars)
	for arg in args {
		gvs.argv << (arg.clone().str)
	}
	if !os.exists(args[1]) {
		tmpfile := os.join_path(os.temp_dir(), os.base(args[1]))
		os.write_file(tmpfile, "")or{panic(err)}
		vcp.warn("file404", args[1], "=>", tmpfile)		
		gvs.argv[1] = tmpfile.str
	}

	argv4c := castptr[&charptr](gvs.argv.data)
	C.Tk_Main(args.len, argv4c, init_proc)
	assert false, "unreachable"
}

pub fn tk_init(p voidptr) int {
	return C.Tk_Init(p)
}

pub type TclcmdFunc = fn(cbval voidptr, ir voidptr, argv []string) int

pub fn create_command(ir voidptr, name string, fnp TclcmdFunc, cbval voidptr) {
	vcp.info(name, fnp)
	fn4c := fn[fnp](cbv voidptr, ir voidptr, argc int, argv &charptr) int {
		// arr := vcp.carr2varr_sized(argv, sizeof(usize), argc)
		arr := vcp.csarr2vsarr(argv, argc)
		return fnp(cbv, ir, arr)
	}
	C.Tcl_CreateCommand(ir, name.str, fnp, cbval, pnil)
}

pub fn getvar(ir voidptr, name string) {
	rv := C.Tcl_GetVar(ir, name.str, 0)
	vcp.info(rv)
}

pub fn setvar(ir voidptr, name string, val voidptr) {
	rv := C.Tcl_SetVar(ir, name.str, val, 0)
	vcp.info(rv)
}