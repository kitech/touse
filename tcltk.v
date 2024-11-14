module tcltk

import  os
import vcp


// http://davesource.com/Fringe/Fringe/Computers/Languages/tcl_tk/tcl_C.html

struct Globvars {
	pub mut:
	argv []voidptr
	tclirp voidptr
	init_done_cbfn fn(voidptr) int = vnil
	varno i64 = 10
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
	return ".vtk_${pfx}_${no}"
	// return ".ttk_${pfx}_${no}"
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
pub fn Labelframe.new(txt string, parent Tkobjitf) Labelframe {
	vn := parent.name() + nextvarname('lbf')
	cmd := 'labelframe ${vn} -text "${txt}"'
	call(cmd)
	return Labelframe{varname:vn}
}

pub struct PackOptions {
	pub mut:
	side string
	fill string
	padx string
	pady string
	expend cint
	insert ?Tkobjitf
}

pub fn (opts PackOptions) toline() string {
	mut cmd := ""
	if opts.side != "" { cmd += " -side ${opts.side}" }
	if v := opts.insert {
		cmd += " -in ${v.name()}"
	}
	if opts.fill != "" { cmd += " -fill ${opts.fill}"}
	if opts.expend == 1 { cmd += " -expend 1"}
	return cmd
}

pub fn (me Labelframe) pack(tko Tkobjitf, opts PackOptions) {
	mut cmd := 'pack ${tko.name()}' // -fill x -padx 3p -pady 3p
	cmd += opts.toline()
	rc := call(cmd)
}

pub struct Button {
	Tkobject
}

pub fn Button.new(txt string, parent Tkobjitf) Button {
	vn := parent.name() + nextvarname('btn')
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

pub fn Frame.new(parent Tkobjitf) Frame{
	vn := parent.name() + nextvarname('frm')
	cmd := 'frame ${vn} -container true -width 300 -height 300'
	rc := call(cmd)
	return Frame{varname:vn}
}

pub struct Listbox {
	Tkobject
}

pub struct TkOptions {
pub mut:
	bg string
	fg string
}

pub struct ListboxOptions {
	TkOptions
	pub mut:
	selmode string
}

pub fn Listbox.new(parent Tkobjitf) Listbox {
	vn := parent.name() + nextvarname('ltbox')
	cmd := 'listbox ${vn} -width 30 -height 20'
	rc := call(cmd)
	return Listbox{varname:vn}
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

// main window
pub struct Dotwin {
}
pub fn Dotwin.conf(obj Tkobjitf) {
	mut cmd := ". configure "
	mut mated := true
	match obj {
		Menu {
			cmd += " -menu ${obj.name()}"
		}
		else{
			mated = false
			vcp.info('nocat', typeof(obj).name)
		}
	}
	if mated {
		rv := call(cmd)
	}
}

pub struct Menu {
	Tkobject
}

// ?int none noset, or set
// bool -opt, or omit
// 还是不能用?int这种字段
// 即使不用?int,还是无法通用实现
pub struct MenuOptions {
	pub mut:
	tearoff ?int // = max_int
	cascade bool
	label string
	underline ?int // = max_int
	command voidptr
}

pub struct FieldInfo {
	FieldData
pub mut:
	size  int
	offset int
	ptr voidptr
}

pub struct Optionin[T] {
	pub mut:
	state byte
	err IError = vnil
	data T
}

// 似乎v支持不了,实现不了
pub fn stfieldsof[T](opts T) string {
	mut flds := []FieldInfo{}
	mut ret := ""
	mut offset := 0
	mut offidx := -1
	mut stsize := 0
		
	C.offsetofcval(opts, C.command)

	$for f in opts.fields {
		offidx ++
		// vcp.info(f.typ)
		println("${@FILE_LINE}: ${offidx}/${offset} ${f.name}, ${f.typ}")
		mut fldinfo := FieldInfo{FieldData: f, offset: offset}
		fldinfo.ptr = voidptr(usize(voidptr(&opts)) + usize(offset))

		match f.typ {
			tkstring {
				// off := __offsetof(MenuOptions, f.name)
				fldinfo.size = sizeof("")
			}
			?int { // vbug: f.typ is int, but not ?int
				zv := Optionin[int]{}
				fldinfo.size = C.sizeofc(zv)
			}
			int {
				zv := int(0)
				fldinfo.size = sizeof(zv)
			}
			bool {
				fldinfo.size = sizeof(true)
			}
			voidptr {
				zv := vnil
				fldinfo.size = sizeof(zv)
			}
			else{
				println("${@FILE_LINE}: nocat: ${offidx}/${offset} ${f.name}, ${f.typ}")
			}
		}
		println("${fldinfo.size}, ${f.name}")
		offset += fldinfo.size
		stsize += fldinfo.size
		flds << fldinfo
	}
	stsize2 := sizeof(opts)
	assert stsize == stsize2, "rtsize not match"
	return ret
}

pub fn (opts MenuOptions) toline() string {
	mut cmd := ""

	if opts.cascade { cmd += " cascade"}
	// if opts.label.len != 0 { cmd += " -label ${opts.label}"}
	// if v := opts.underline  {
	// 	cmd += " -underline ${v}"
	// }
	if opts.command != vnil { cmd += " command" }

	if v := opts.tearoff {
		cmd += " -tearoff ${v}"
	}

	if opts.label != "" { cmd += " -label ${opts.label}"}
	if v := opts.underline  {
		cmd += " -underline ${v}"
	}
	if opts.command != vnil {
		cmd += " -command ${opts.command}"
	}
	return cmd
} 

pub fn Menu.new(opts MenuOptions) Menu {
	vn := nextvarname('menu')
	mut cmd := 'menu ${vn}'
	cmd += opts.toline()
	// if v := opts.tearoff {
	// 	cmd += " -tearoff ${v}"
	// }
	// if opts.cascade { cmd += " cascade"}
	// if opts.label.len != 0 { cmd += " -label ${opts.label}"}
	// if v := opts.underline  {
	// 	cmd += " -underline ${v}"
	// }
	// cmd += stfieldsof(opts)
	rc := call(cmd)
	return Menu{varname:vn}
}

pub fn (me Menu) add(m Menu, opts MenuOptions) {
	mut cmd := "${me.name()} add "
	cmd += opts.toline()
	cmd += " -menu ${m.name()}"
	// if opts.command != vnil { cmd += " command" }
	// if opts.label != "" { cmd += " -label \"${opts.label}\""}
	// if v := opts.underline  {
	// 	cmd += " -underline ${v}"
	// }
	// if opts.command != vnil {
	// 	cmd += " -command ${opts.command}"
	// }
	rc := call(cmd)
}