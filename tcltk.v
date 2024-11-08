module tcltk

import  os
import vcp

struct Globvars {
	pub mut:
	argv []voidptr
	tclirp voidptr
	init_done_cbfn fn(voidptr) int = vnil
	varno i64 = 100
}
const gvars = &Globvars{}

pub fn tk_main2(init_tcl_file string) {
		args := [os.base(init_tcl_file), init_tcl_file]
		tk_main(args, vnil)
}

// ui event look, will block forever
pub fn tk_main(args []string, init_done fn(ir voidptr) int) {
	mut gvs := refvar2mut(gvars)
	for arg in args {
		gvs.argv << (arg.clone().str)
	}
	if !os.exists(args[1]) {
		tmpfile := os.join_path(os.temp_dir(), os.base(args[1]))
		initcode := "package require Tk\ntk systray exists;"
		os.write_file(tmpfile, "")or{panic(err)}
		vcp.warn("file404", args[1], "=>", tmpfile)		
		gvs.argv[1] = tmpfile.str
	}

	gvs.init_done_cbfn = init_done
	init_proc2 := tk_init

	argv4c := castptr[&charptr](gvs.argv.data)
	C.Tk_Main(args.len, argv4c, init_proc2)
	assert false, "unreachable"
}

// like wish9.0 init, see tkAppInit.c: Tcl_AppInit
pub fn tk_init(p voidptr) int {
	mut gvs := refvar2mut(gvars)
	gvs.tclirp = p

	rc1 := C.Tcl_Init(p)
	rc := C.Tk_Init(p)

	tk_create_error_handler()
	// C.Tcl_StaticLibrary(p, "tk2".str, C.Tk_Init, pnil)

	if gvs.init_done_cbfn != vnil {
		gvs.init_done_cbfn(p)
	}
	return rc
}

// call and eval are the same indeed
pub fn eval(s string) {
	rc := C.Tcl_Eval(gvars.tclirp, s.str)
	vcp.info(rc, s)
}
pub fn call(s string) int {
	// vcp.info("calling", s)
	rc := C.Tcl_Eval(gvars.tclirp, s.str)
	if rc != tclok {
		// emsg := posix_error()
		emsg2 := get_errnomsg0()
		vcp.info("called", rc, emsg2, s)
	}
	return rc
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

fn C.Tcl_PosixError(... voidptr) charptr
pub fn posix_error() string {
	rv := C.Tcl_PosixError(gvars.tclirp)
	return tosbca(rv)
}
fn C.Tcl_GetErrno() int
pub fn get_errno() int { return C.Tcl_GetErrno() }
fn C.Tcl_ErrnoMsg(... voidptr) charptr
pub fn get_errnomsg(eno int) string { return tosbca(C.Tcl_ErrnoMsg(eno))}
pub fn get_errnomsg0() string { return tosbca(C.Tcl_ErrnoMsg(C.Tcl_GetErrno()))}

fn C.Tk_MainWindow(voidptr) usize
fn tk_main_window(irp voidptr) usize { return C.Tk_MainWindow(irp) }

fn C.Tk_Screen()
fn C.Tk_WindowId(voidptr) usize
pub fn tk_windowid() usize { return C.Tk_WindowId(tk_main_window(gvars.tclirp)) }
fn C.Tk_Display(usize) usize
pub fn tk_display() usize { return C.Tk_Display(tk_main_window(gvars.tclirp)) }

fn C.Tk_CreateErrorHandler(... voidptr) usize
pub fn tk_create_error_handler() {
	dsp := tk_display()
	C.Tk_CreateErrorHandler(dsp, -1, -1, -1, fn(cbval voidptr, eeptr voidptr) {
		vcp.info(111, cbval, eeptr)
	}, vnil)
}

///
fn nextvarname(pfx string) string {
	mut gvs := refvar2mut(gvars)
	no := gvs.varno++
	return ".ttk_${pfx}_${no}"
}

///
pub struct Tkobject {
	pub mut:
	varname string
}
pub fn (me Tkobject) name() string { return me.varname }
pub interface Tkobjitf {
	name() string
}

pub struct Button {
	Tkobject
}

pub fn Button.new(txt string) Button {
	vn := nextvarname('btn')
	cmd := 'button ${vn} -text "${txt}"' //  -command create
	call(cmd)
	return Button{varname:vn}
}

pub struct Labelframe {
	Tkobject
}
pub fn Labelframe.new(txt string) Labelframe {
	vn := nextvarname('lbf')
	cmd := 'labelframe ${vn} -text "${txt}"'
	call(cmd)
	return Labelframe{varname:vn}
}

pub fn (me Labelframe) pack(tko Tkobjitf) {
	cmd := 'pack ${me.varname} ${tko.name()} -fill x -padx 3p -pady 3p'
	call(cmd)
}
