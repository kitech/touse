module ffi

import log

// error: Cannot find "libffi" pkgconfig file
// #pkgconfig linux libffi
#flag -DFFI_GO_CLOSURES=1
#flag -lffi
// #flag darwin  -lffi-trampolines //
#flag -I@DIR/
#flag @DIR/ffiv.o
#flag darwin -I/Library/Developer/CommandLineTools/SDKs/MacOSX11.sdk/usr/include/ffi
// for github CI
#flag darwin -L $env('HOME')/vcpkg/installed/arm64-osx/lib
#flag darwin -I $env('HOME')/vcpkg/installed/arm64-osx/include
#flag -L $env('HOME')/.nix-profile/lib -Wl,-rpath,$env('HOME')/.nix-profile/lib
#flag -I $env('HOME')/.nix-profile/include

// #include "@DIR/ffiv.h"
#include <ffi.h>

pub const default_abi = C.FFI_DEFAULT_ABI

pub const ok = C.FFI_OK
pub const bad_typedef = C.FFI_BAD_TYPEDEF
pub const bad_abi = C.FFI_BAD_ABI

pub const ctype_void = C.FFI_TYPE_VOID
pub const ctype_int = C.FFI_TYPE_INT
pub const ctype_float = C.FFI_TYPE_FLOAT
pub const ctype_double = C.FFI_TYPE_DOUBLE
//#if 1               =
pub const ctype_longdouble = C.FFI_TYPE_LONGDOUBLE
//#else               =
// FFI_TYPE_LONGDOUBLE = FFI_TYPE_DOUBLE
//#endif              =
pub const ctype_uint8 = C.FFI_TYPE_UINT8
pub const ctype_sint8 = C.FFI_TYPE_SINT8
pub const ctype_uint16 = C.FFI_TYPE_UINT16
pub const ctype_sint16 = C.FFI_TYPE_SINT16
pub const ctype_uint32 = C.FFI_TYPE_UINT32
pub const ctype_sint32 = C.FFI_TYPE_SINT32
pub const ctype_uint64 = C.FFI_TYPE_UINT64
pub const ctype_sint64 = C.FFI_TYPE_SINT64
pub const ctype_struct = C.FFI_TYPE_STRUCT
pub const ctype_pointer = C.FFI_TYPE_POINTER
pub const ctype_complex = C.FFI_TYPE_COMPLEX
// pub const FFI_TYPE_LAST       FFI_TYPE_COMPLEX

// type: &int
// @[c_extern]
// __global ffi_type_void voidptr
// @[c_extern]
// __global ffi_type_uint8 voidptr
// @[c_extern]
// __global ffi_type_sint8 voidptr
// @[c_extern]
// __global ffi_type_uint16 voidptr
// @[c_extern]
// __global ffi_type_sint16 voidptr
// @[c_extern]
// __global ffi_type_uint32 voidptr
// @[c_extern]
// __global ffi_type_sint32 voidptr
// @[c_extern]
// __global ffi_type_uint64 voidptr
// @[c_extern]
// __global ffi_type_sint64 voidptr
// @[c_extern]
// __global ffi_type_float voidptr
// @[c_extern]
// __global ffi_type_double voidptr
// @[c_extern]
// __global ffi_type_pointer voidptr

// todo deprecated
pub const type_void = voidptr(&C.ffi_type_void)
pub const type_uint8 = voidptr(&C.ffi_type_uint8)
pub const type_sint8 = voidptr(&C.ffi_type_sint8)
pub const type_uint16 = voidptr(&C.ffi_type_uint16)
pub const type_sint16 = voidptr(&C.ffi_type_sint16)
pub const type_uint32 = voidptr(&C.ffi_type_uint32)
pub const type_sint32 = voidptr(&C.ffi_type_sint32)
pub const type_uint64 = voidptr(&C.ffi_type_uint64)
pub const type_sint64 = voidptr(&C.ffi_type_sint64)
pub const type_float = voidptr(&C.ffi_type_float)
pub const type_double = voidptr(&C.ffi_type_double)
pub const type_pointer = voidptr(&C.ffi_type_pointer)
// pub const	type_int = $if x64 || amd64 || arm64 { type_sint64 } $else { type_sint32}
// pub const	type_uint = $if x64 || amd64 || arm64 { type_uint64 } $else { type_uint32}

@[typedef]
pub struct C.ffi_type {}

pub type Type = C.ffi_type

// pub type Type = voidptr
// fn C.ffi_get_type_obj(int) &C.ffi_type
//@[deprecated]
// fn get_type_obj(ty int) voidptr { return voidptr(C.ffi_get_type_obj(ty)) }

pub fn get_type_obj2(ty int) &Type {
	// mut tyobj := &Type{}
	// mut tyobj := &int{}
	mut tyobj := unsafe { nil }

	match ty {
		ctype_void { tyobj = type_void }
		ctype_int { tyobj = type_sint32 }
		ctype_sint16 { tyobj = type_sint16 }
		ctype_uint16 { tyobj = type_uint16 }
		ctype_sint64 { tyobj = type_sint64 }
		ctype_uint64 { tyobj = type_uint64 }
		ctype_float { tyobj = type_float }
		ctype_double { tyobj = type_double }
		ctype_pointer { tyobj = type_pointer }
		else { panic('not impled ${ty}') }
	}

	return tyobj
}

pub fn get_type_obj3(ty int) voidptr {
	vx := get_type_obj2(ty)
	return voidptr(vx)
}

@[typedef]
pub struct C.ffi_cif {}

pub type Cif = C.ffi_cif

fn C.ffi_prep_cif(&Cif, voidptr, int, voidptr, voidptr) int

pub fn prep_cif0(cif &Cif, rtype voidptr, atypes []voidptr) int {
	// log.info("${@LOCATION}, ${rtype}, ${atypes.len}")
	ret := C.ffi_prep_cif(cif, default_abi, atypes.len, rtype, atypes.data)
	return ret
}

fn C.ffi_call(&Cif, voidptr, voidptr, voidptr)

// f fn()
pub fn call(cif &Cif, f voidptr, rvalue voidptr, avalues []voidptr) voidptr {
	// mut rvalue := u64(0)
	// log.info("${@FILE_LINE}: ${avalues.len}, $f, ${avalues}")
	C.ffi_call(cif, f, rvalue, avalues.data)
	return voidptr(rvalue)
}

$if !macos {
@[typedef]
pub struct C.ffi_go_closure {}

pub type Goclos = C.ffi_go_closure

// not exist
// fun: void (*fun)(ffi_cif*,void*,void**,void*)
fn C.ffi_prep_go_closure(clos &Goclos, cif &Cif, fun voidptr) int

// fun void (*fn)(void)
fn C.ffi_call_go(cif &Cif, fun voidptr, rvalue voidptr, avalues &voidptr, clos &Goclos)

pub fn prep_go_closure(clos &Goclos, cif &Cif, fun voidptr) int {
	return C.ffi_prep_go_closure(clos, cif, fun)
}

pub fn call_go(cif &Cif, fun voidptr, rvalue voidptr, avalues &voidptr, clos &Goclos) {
	C.ffi_call_go(cif, fun, rvalue, avalues, clos)
}
}

// not exist
fn C.ffi_tramp_is_supported() int
fn C.ffi_tramp_alloc(flags int) voidptr
fn C.ffi_tramp_set_parms(tramp voidptr, data voidptr, code voidptr)
fn C.ffi_tramp_get_addr(tramp voidptr) voidptr
fn C.ffi_tramp_free(tramp voidptr)

// pub fn tramp_is_supported() bool { return C.ffi_tramp_is_supported() != 0}
// pub fn tramp_alloc(flags int) voidptr { return C.ffi_tramp_alloc(flags) }
// pub fn tramp_set_parms(tramp voidptr, data voidptr, code voidptr) {
// 	C.ffi_tramp_set_parms(tramp, data, code)
// }
// pub fn tramp_get_addr(tramp voidptr) voidptr { return C.ffi_tramp_get_addr(tramp)}
// pub fn tramp_free(tramp voidptr) { C.ffi_tramp_free(tramp)}

fn atypes2obj(atypes []int) []&Type {
	mut res := []&Type{}
	for atype in atypes {
		o := get_type_obj2(atype)
		res << o
	}
	return res
}

///// ffi easy wrap

// call in one step, by pass fnptr, arg types and values
pub fn call3(f voidptr, atypes []int, avalues []voidptr) u64 {
	assert atypes.len == avalues.len

	argc := atypes.len
	rtype := type_pointer
	atypeso := atypes2obj(atypes)
	atypesc := atypeso.data

	// prepare
	cif := Cif{}
	rv := C.ffi_prep_cif(&cif, default_abi, argc, rtype, atypesc)
	match rv {
		ok {}
		// ffi.BAD_TYPEDEF {}
		// ffi.BAD_ABI {}
		else {}
	}
	if rv == ok {
	} else if rv == bad_typedef {
	} else if rv == bad_abi {
	} else {
	}
	// invoke
	mut avalues2 := avalues.clone()
	avaluesc := avalues2.data
	mut rvalue := u64(0)
	C.ffi_call(&cif, f, &rvalue, avaluesc)
	return rvalue
}

fn init() {
    if abs0() {
        callany[int]("")
        callany[f64](voidptr(0))
    }
}

pub type Symbol = string | charptr | voidptr | usize
pub fn (symoradr Symbol) resolve() voidptr {
    mut adr := vnil 
    match symoradr {
        string { adr = C.dlsym(C.RTLD_DEFAULT, symoradr.str) }
        charptr { adr = C.dlsym(C.RTLD_DEFAULT, symoradr) }
        voidptr { adr = symoradr }
        usize { adr = voidptr(symoradr) }
    }
    if adr == vnil {log.warn("adr nil for sym $symoradr")}
    return adr
}
// call in one step, by pass fnptr or fnname, and use native args syntax
pub fn callany[T](symoradr Symbol, args ...Anyer) T {
    return callfca6[T](symoradr.resolve(), ...args)
}

pub fn callfca6[T](sym voidptr, args ...Anyer) T {
	// const array must unsafe, it's compiler's fault
	mut argctys := unsafe { [9]int{} }
	mut argotys := unsafe { [9]voidptr{} }
	mut argvals := unsafe { [9]voidptr{} }
	mut argadrs := unsafe { [9]voidptr{} }

	for i, arg in args {
		mut fficty := ffity_ofany(arg)
		argctys[i] = fficty
	}

	for idx in 0..args.len {
	    argotys[idx] = get_type_obj2(argctys[idx])
		if args[idx].isptr() {
	        assert argotys[idx]==type_pointer
			argadrs[idx] = get_anyer_data(args[idx])
			argvals[idx] = &argadrs[idx]
		}else{
		    argvals[idx] = get_anyer_data(args[idx])
		}
		// log.info("$idx ty ${argctys[idx]}, adr ${argvals[idx]} ${@FILE_LINE}")
	}
	
	///
	retoty := match typeof[T]().idx {
		typeof[f64]().idx { type_double }
		typeof[f32]().idx { type_float }
		-1 { type_pointer }
		else { type_pointer }
	}

	cif := Cif{}
	stv := prep_cif0(&cif, retoty, argotys[..args.len])
	assert stv == ok

	retval := Cif{}
	assert sizeof(retval) >= sizeof(T)
	rv := call(&cif, sym, &retval, argvals[..args.len])
	// assert rv == &retval
	if abs1() {
		return unsafe { *(&T(rv)) }
	}
	return T{}
}

// usage: slen := ffi.callfca8('strlen', 0, c'abc')
// used for manual call, not auto call
// ar is retval
pub fn callfca8[R,S,T,U,V,W,X,Y,Z](symoradr Symbol, ar R, as_ S, at_ T, au U, av V, aw W, ax X, ay Y, az Z) R {
    sym := symoradr.resolve()
        
	// const array must unsafe, it's compiler's fault
	mut argctys := unsafe { [9]int{} }
	mut argotys := unsafe { [9]voidptr{} }
	mut argvals := unsafe { [9]voidptr{} }
	mut cnter := 0
	
	argctys[cnter++] = ffity_oftmpl(as_)
	argctys[cnter++] = ffity_oftmpl(at_)
	argctys[cnter++] = ffity_oftmpl(au)
	argctys[cnter++] = ffity_oftmpl(av)
	argctys[cnter++] = ffity_oftmpl(aw)
	argctys[cnter++] = ffity_oftmpl(ax)
	argctys[cnter++] = ffity_oftmpl(ay)
	argctys[cnter++] = ffity_oftmpl(az)

	cnter = 0
	argvals[cnter++] = &as_
	argvals[cnter++] = &at_
	argvals[cnter++] = &au
	argvals[cnter++] = &av
	argvals[cnter++] = &aw
	argvals[cnter++] = &ax
	argvals[cnter++] = &ay
	argvals[cnter++] = &az
	
	for idx in 0..argctys.len {
	    argotys[idx] = get_type_obj2(argctys[idx])
		// argvals[idx] = get_anyer_data(args[idx])
		// log.info("$idx ty ${argctys[idx]}, adr ${argvals[idx]} ${@FILE_LINE}")
	}
	
	retoty := get_type_obj2(ffity_oftmpl(ar))
	
	///
	cif := Cif{}
	stv := prep_cif0(&cif, retoty, argotys[..])
	assert stv == ok

	retval := Cif{}
	assert sizeof(retval) >= sizeof(R)
	rv := call(&cif, sym, &retval, argvals[..])
	// assert rv == &retval
	if abs1() {
		return unsafe { *(&R(rv)) }
	}
	return ar
	// $if ar is $pointer { return ar } $else { return R{} }
}

pub fn ffity_oftmpl[T](t T) int {
	$if t is int {  return ctype_int
	} $else $if t is bool {	    return ctype_int
	} $else $if t is i8 {	    return ctype_sint8
	} $else $if t is u32 {	    return ctype_uint32
	} $else $if t is f32 {      return ctype_float
	} $else $if t is f64 {	    return ctype_double
	} $else $if t is usize {	    return ctype_pointer
	} $else $if t is i64 {	    return ctype_sint64
	} $else $if t is u64 {	    return ctype_uint64
	} $else $if t is $pointer {	    return ctype_pointer
	} $else {
	    println("${@FILE_LINE}: unknown ${typeof(t).name}")
	    return -1
	}
}
pub fn ffity_ofany(arg Anyer) int {
    mut fficty := ctype_int
  
	match arg {
		f32 { fficty = ctype_float }
		f64 { fficty = ctype_double }
		int { fficty = ctype_int }
		usize { fficty = ctype_pointer }
		i64 { fficty = ctype_sint64 }
		u64 { fficty = ctype_uint64 }
		u32 { fficty = ctype_sint32 }
		i16 { fficty = ctype_int }
		i8 { fficty = ctype_int }
		// C 中没有bool类型，是整数类型，所以对C函数应该可能。
		// 但是对V的bool并不适用。需要V打开开关-d 4bytebool。
		bool { fficty = ctype_int }
		voidptr { fficty = ctype_pointer }
		charptr { fficty = ctype_pointer }
		byteptr { fficty = ctype_pointer }
		string { fficty = ctype_pointer }
		else {
		    warnit := true
		    tyname := arg.tyname()
			if tyname.starts_with('[]') {
			
			} else if tyname.starts_with('map[') {
			
			} else if tyname.count('.') > 0 { // non builtin struct or ref
			    if arg.isptr() {
					warnit=false
					fficty = ctype_pointer
				}
			} else if tyname.count('.') == 0 { // builtin struct or ref
			
			}
			if warnit { log.warn('not support ${arg}, $tyname, isptr ${arg.isptr()}') }
		}
	}
    return fficty
}

// V orignal interface struct
pub struct Itfacein {
pub mut:
	ptr voidptr // union with valptrs
	typ int     // kind or index??? index in current interface, not global
}

// return ffi data
pub fn get_anyer_data(arg Anyer) voidptr {
    ptr := unsafe { &Itfacein(voidptr(&arg)) }
    return ptr.ptr
}
