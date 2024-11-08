module tcltk

#flag  -I/opu/tcltk9/include/
#flag  -L/opu/tcltk9/lib -Wl,-rpath=/opu/tcltk9/lib
#flag  -ltcl9tk9.0
#flag  -ltcl9.0
#flag  -lX11

#include "tcl.h"
#include "tk.h"

// fn C.Tk_Main(int, voidptr, voidptr)
// 通用 C 函数声明，vlang's feat/bug???
fn C.Tk_Main(... voidptr)
fn C.Tk_Init(voidptr) int

fn C.Tcl_Eval(... voidptr) int
fn C.Tcl_EvalFile(... voidptr) int
fn C.Tcl_CreateCommand(... voidptr) usize
fn C.Tcl_GetVar(... voidptr) voidptr
fn C.Tcl_SetVar(... voidptr) voidptr
fn C.Tcl_Init(...voidptr) int
fn C.Tcl_StaticLibrary(...voidptr) int

pub const tclok = C.TCL_OK
pub const tclerr = C.TCL_ERROR
