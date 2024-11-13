module tcltk

import  os
import vcp


// http://davesource.com/Fringe/Fringe/Computers/Languages/tcl_tk/tcl_C.html

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
pub fn eval(s string) int {
	rc := C.Tcl_Eval(gvars.tclirp, s.str)
	vcp.info(rc, s)
	return rc
}
pub fn call(s string) int {
	// vcp.info("calling", s)
	rc := C.Tcl_Eval(gvars.tclirp, s.str)
	if rc != tclok {
		// emsg := posix_error()
		emsg2 := get_errnomsg0()
		vcp.info("called", rc, emsg2, ":", s)
	}
	res := C.Tcl_GetStringResult(gvars.tclirp)
	// vcp.info("res:", tosbca(res), ": ${s}")
	return rc
}
pub fn call2(s string) !string {
	// vcp.info("calling", s)
	rc := C.Tcl_Eval(gvars.tclirp, s.str)
	if rc != tclok {
		// emsg := posix_error()
		emsg2 := get_errnomsg0()
		vcp.info("called", rc, emsg2, ":", s)
		return error(emsg2)
	}
	resc := C.Tcl_GetStringResult(gvars.tclirp)
	res := tosbca(resc)
	vcp.info("res:", res, ": ${s}")
	return res
}

pub type TclcmdFunc = fn(cbval voidptr, ir voidptr, argv []string) int

pub fn create_command(ir voidptr, name string, fnp TclcmdFunc, cbval voidptr)  usize {
	// vcp.info(name, fnp)
	fn4c := fn[fnp](cbv voidptr, ir voidptr, argc int, argv &charptr) int {
		// vcp.info(@FILE_LINE, cbv, argc)
		// arr := vcp.carr2varr_sized(argv, sizeof(usize), argc)
		arr := vcp.csarr2vsarr(argv, argc-1)
		return fnp(cbv, ir, arr)
	}
	rc := C.Tcl_CreateCommand(ir, name.str, fn4c, cbval, pnil)
	// vcp.info(rc, name)
	return rc
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
	rc := call(cmd)
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

pub fn (me Button) connect(fnx fn(voidptr, []string), cbval voidptr) {
	slotname := "${me.name()[1..]}_oncmd"
	create_command(gvars.tclirp, slotname,
			fn[fnx](a0 voidptr, a1 voidptr, args []string) int {
		// vcp.info(@FILE_LINE, a0, a1, args.str())
		fnx(a0, args)
		return 0
	}, cbval)
	cmd := '${me.name()} configure -command ${slotname}'
	call(cmd)
}

pub enum ImageType {
	bitmap
	photo
	nsimage
}

pub struct Image {
	Tkobject
}

pub fn Image.new(name string, data string) Image {
	vn := nextvarname('img')
	cmd := 'image create photo ${name} -data "${data}"'
	rc := call(cmd)
	return Image{varname:vn}
}

pub struct Systray {
	Tkobject
}

pub fn Systray.new(txt string) Systray {
	imgname := "styimg"
	imgo := Image.new(imgname, "R0lGODlhCwAPAKIAAP//////AMDAwICAgAAA/wAAAAAAAAAAACwAAAAACwAPAAADMzi6CzAugiAgDGE68aB0RXgRJBFVX0SNpQlUWfahQOvSsgrX7eZJMlQMWBEYj8iQchlKAAA7")

	vn := nextvarname('sty')
	cmd := 'tk systray create -image ${imgname} -text "${txt}"'
	rc := call(cmd)
	return Systray{varname:vn}
}

pub fn (me Systray) connect(whichbtn int, fnx fn(voidptr, []string), cbval voidptr) {
	slotname := "${me.name()[1..]}_oncmd"
	create_command(gvars.tclirp, slotname,
			fn[fnx](a0 voidptr, a1 voidptr, args []string) int {
		// vcp.info(@FILE_LINE, a0, a1, args.str())
		fnx(a0, args)
		return 0
	}, cbval)

	assert whichbtn==1||whichbtn==3
	cmd := '${me.name()} configure -command${whichbtn} ${slotname}'
	call(cmd)
}

pub fn (me Systray) exists() bool {
	return Systray.exists()
}
pub fn Systray.exists() bool {
	cmd := 'tk systray exists'
	rc := call(cmd)
	return false
}


pub fn Systray.destroy() {
	cmd := 'tk systray destroy'
	rc := call(cmd)
}

pub struct Sysnotify {
	Tkobject
}

pub fn Sysnotify.send(title string, txt string) {
	// vn := nextvarname('sny')
	cmd := 'tk sysnotify "${title}" "${txt}"'
	rc := call(cmd)
}

// todo 移动窗口位置
// todo 窗口背景/前景/theme

pub struct Frame {
	Tkobject
}

pub fn Frame.new() Frame{
	vn := nextvarname('frm')
	cmd := 'frame ${vn} -container true -width 300 -height 200'
	rc := call(cmd)
	return Frame{varname:vn}
}

pub struct Winfo {
	// Tkobject
}
// pub fn Winfo.id()

pub fn (me Tkobject) id() string {
	cmd := 'winfo id ${me.name()}'
	res := call2(cmd) or {panic(err)}
	vcp.info(res)
	return res
}
