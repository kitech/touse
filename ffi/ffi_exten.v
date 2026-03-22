module ffi

import log
import math

#flag @DIR/ffi_exten.o


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

const sret_minsize = 2*sizeof(usize)

pub fn callfca6[T](sym voidptr, args ...Anyer) T {
	// const array must unsafe, it's compiler's fault
	mut argctys := unsafe { [16]int{} }
	mut argotys := unsafe { [16]voidptr{} }
	mut argvals := unsafe { [16]voidptr{} }
	mut argadrs := unsafe { [16]voidptr{} }
	mut argitfs := unsafe { [16]&Itfacein{} }

	for i, arg in args {
		mut fficty := ffity_ofany(arg)
		argctys[i] = fficty
        argitfs[i] = &Itfacein(&args[i])
	}

	for idx in 0..args.len {
		if argctys[idx] == ctype_string {
			argotys[idx] = create_struct_ffitype('')
			argvals[idx] = get_anyer_data(args[idx])
			continue
		}
		else if argctys[idx] == ctype_array {
			argotys[idx] = create_struct_ffitype(Arrayin{})
            argvals[idx] = get_anyer_data(args[idx])
            continue
		}
	    argotys[idx] = get_type_obj2(argctys[idx])
		if args[idx].isptr() {
	        assert argotys[idx]==type_pointer
			argadrs[idx] = get_anyer_data(args[idx])
			argvals[idx] = &argadrs[idx]
            assert false // seem not reachable cond branch
		}else{
		    argvals[idx] = get_anyer_data(args[idx])
		}
		// log.info("$idx ty ${argctys[idx]}, adr ${argvals[idx]} ${@FILE_LINE}")
	}

	///
	retoty := match typeof[T]().idx {
		typeof[f64]().idx { type_double }
		typeof[f32]().idx { type_float }
		-1 { type_uint64 }
		else { type_uint64 }
	}

	tysz, tystr := sizeof(T), typeof(T{}).name
	// dump('${tysz}, ${tystr}')
	if tysz >= sret_minsize {
        $if T.unaliased_typ is string {
            retoty = create_struct_ffitype_nu8(int(tysz))
        } $else $if T.unaliased_typ is $array {
            retoty = create_struct_ffitype_nu8(int(tysz))
        } $else $if T.unaliased_typ is $map {
            retoty = create_struct_ffitype_nu8(int(tysz))
        } $else {
            retoty = create_struct_ffitype_nu8(int(sret_minsize))
        }
    }

	cif := Cif{}
	stv := prep_cif0(&cif, retoty, argotys[..args.len])
	assert stv == ok

	struct DerefMem {data0 [32]u8} // max 32, or return value invalid
	retval := DerefMem {}
	assert sizeof(retval) >= sizeof(T), tystr

	rv := call(&cif, sym, &retval, argvals[..args.len])
	assert rv == &retval

	if abs1() {
		return unsafe { *(&T(rv)) }
	}
	return T{}
}

fn create_struct_ffitype_nu8(len int) &C.ffi_type {
    tyobj := &C.ffi_type{}
    tyobj.type = u16(ctype_struct)
	elems := []voidptr{len: len*2+1}
	for i in 0..len { elems[i] = type_uint8 }
	tyobj.elements = elems.data

    return tyobj
}
fn create_struct_ffitype[T](v T) &C.ffi_type {

	$if T.unaliased_typ is string {

		// tyobj := &C.ffi_type{}
		// tyobj.type = u16(ctype_struct)
		// elems := []voidptr{len: 8}
		// elems[0] = type_pointer
		// elems[1] = type_uint32
		// elems[2] = type_uint32
		// tyobj.elements = elems.data

        tyobj := create_struct_ffitype_nu8(int(sizeof(v)))
		return tyobj
	} $else $if T.unaliased_typ is $array {
        tyobj := create_struct_ffitype_nu8(int(sizeof(v)))
        return tyobj

	} $else $if T.unaliased_typ is $struct {
		tyobj := &C.ffi_type{}
		tyobj.type = u16(ctype_struct)
		elems := []voidptr{}

		$for fld in T.fields {
			tyi := ffity_oftmpl(v.$fld.name)
            tyo := get_type_obj2(tyi)
            elems << tyo
		}
		tyobj.elements = elems.data

		return tyobj

	} $else {
		assert false, typeof(v).name
	}

	return nil
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
    isalias := $if T is $alias { true } $else { false }
    ispointer := $if T is $pointer { true } $else { false }
    tyidx0 := typeof(t).idx
    tyidx1 := T.unaliased_typ // int value like typeof(0).idx

	$if T.unaliased_typ is int {  return ctype_int
	} $else $if T.unaliased_typ is bool {	    return ctype_int
	} $else $if T.unaliased_typ is i8 {	    return ctype_sint8
	} $else $if T.unaliased_typ is u32 {	    return ctype_uint32
	} $else $if T.unaliased_typ is $enum {	    return ctype_uint32
	} $else $if T.unaliased_typ is f32 {      return ctype_float
	} $else $if T.unaliased_typ is f64 {	    return ctype_double
	} $else $if T.unaliased_typ is usize {	return ctype_pointer
	} $else $if T.unaliased_typ is i64 {	    return ctype_sint64
	} $else $if T.unaliased_typ is u64 {	    return ctype_uint64
	} $else $if T.unaliased_typ is $pointer {	return ctype_pointer
	} $else {
	    $if T is $alias {
			// return ffity_oftmpl[T.unaliased_typ]() // elegant but not working
			match tyidx1 {
			    typeof(int(0)).idx { return ctype_int }
			    typeof(usize(0)).idx { return ctype_pointer }
			    typeof(voidptr(0)).idx { return ctype_pointer }
				else {}
			}
		}
	    log.warn("${@FILE_LINE}: unknown ${typeof(t).name}, alias=$isalias, pointer=$ispointer")
	    return -1
	}

}

pub const ctype_string = 64
pub const ctype_array  = 65

pub fn ffity_ofany(arg Anyer) int {
    mut fficty := ctype_int

	match arg{
		string {
			return ctype_string
		}
		else{}
	}

	match arg {
		f32 { fficty = ctype_float }
		f64 { fficty = ctype_double }
		int { fficty = ctype_int }
		usize { fficty = ctype_pointer }
		i64 { fficty = ctype_sint64 }
		u64 { fficty = ctype_uint64 }
		u32 { fficty = ctype_sint32 }
		i16 { fficty = ctype_sint16 }
		i8 { fficty = ctype_sint8 }
		// C 中没有bool类型，是整数类型，所以对C函数应该可能。
		// 但是对V的bool并不适用。需要V打开开关-d 4bytebool。
		bool { fficty = ctype_int }
		voidptr { fficty = ctype_pointer }
		charptr { fficty = ctype_pointer }
		byteptr { fficty = ctype_pointer }
		// string { fficty = ctype_pointer }
		string { fficty = ctype_string }
		else {
		    warnit := true
		    tyname := arg.tyname()
			if tyname.starts_with('[]') {
                warnit = false
                fficty = ctype_array
			} else if tyname.starts_with('map[') {

			} else if tyname.count('.') > 0 { // non builtin struct or ref
			    if arg.isptr() {
					warnit = false
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
	itfidx int     // kind or index??? index in current interface, not global
}

// return ffi data
pub fn get_anyer_data(arg Anyer) voidptr {
    ptr := unsafe { &Itfacein(voidptr(&arg)) }
    if arg is string {
      //  return arg.str
    }
    return ptr.ptr
}
