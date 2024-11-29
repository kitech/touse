module emacs

import dl
import vcp

#include <emacs-module.h>
#include "@VMODROOT/emacs/emacs.h"

// this #flag fix v -shared result symbol not found
// #flag @VEXEROOT/thirdparty/tcc/lib/libtcc.a
// #flag @VEXEROOT/thirdparty/tcc/lib/tcc/bcheck.o
// tcc_backtrace symbol here
#flag @VEXEROOT/thirdparty/tcc/lib/tcc/bt-log.o
// bt_init symbol here
#flag @VEXEROOT/thirdparty/tcc/lib/tcc/bt-exe.o
// need __rt_exit???
// #flag @VEXEROOT/thirdparty/tcc/lib/tcc/runmain.o

// 这篇文档讲的详细, https://phst.eu/emacs-modules.html

__global plugin_is_GPL_compatible = 1

fn init() {
	// C.infolm(c'...')
}

// this is first called, even before emacs.init()

@[export: 'emacs_module_init']
fn eminitc(rtx &C.emacs_runtime) int {
	// C.infolm(c'...')
	vcp.fixvsogc()
	vcp.fixvsoinit()

	rt := castptr[Runtime](rtx)
	rv := eminit(rt)
	return rv
}

fn eminit(rt &Runtime) int {
	vcp.info('emver:', MAJOR_VERION, rt.str().compact())
	env := rt.getenv()
	emcheckenv(env)
	assert env.nle_check() == .return_

	refvar2mut(emvs).elnil = env.globref(env.intern('nil'))
	refvar2mut(emvs).eltrue = env.globref(env.intern('t'))
	// refvar2mut(emvs).rt = rt
	// refvar2mut(emvs).env = env

	basictt(env)

	if emvs.emuser_init != vnil {
		emvs.emuser_init(env)
	}
	return 0
}

fn emcheckenv(e &Env) {
	expsz := 0
	if MAJOR_VERION == 29 {
		expsz = sizeof(Env29)
	} else if MAJOR_VERION == 29 {
		expsz = sizeof(Env25)
	}
	if e.vh.size != expsz {
		// it's really fatal error
		vcp.error('envst size not match, v/c: ${expsz}/${e.vh.size}')
	}
}

pub fn reginiter(cb fn (e &Env)) {
	refvar2mut(emvs).emuser_init = cb
}

// todo what will happend if load to .so use this library
const emvs = &Emvars{}

struct Emvars {
pub mut:
	callcnt int = 0 // maybe call multiple times by emacs???
	elnil   Value
	eltrue  Value

	// dont save any emacs Runtime/Env's reference
	// rt  &Runtime = vnil
	// env &Env     = vnil
	emuser_init fn (e &Env) = vnil

	elclostmpno i64 = 10
}

///
pub const MAJOR_VERION = C.EMACS_MAJOR_VERSION

// should be voidptr, but voidptr has some special
pub type Value = usize

pub fn (me Value) asptr() voidptr {
	return voidptr(usize(me))
}

@[typedef]
struct C.emacs_runtime {}

pub type RuntimePrivate = usize

pub struct Runtime {
pub mut:
	size   isize
	privmb RuntimePrivate

	// emacs_env *(*get_environment) (struct emacs_runtime *runtime)
	// EMACS_ATTRIBUTE_NONNULL (1);
	getenv_ fn (rt &Runtime) &Env = vnil
}

pub fn (me &Runtime) getenv() &Env {
	return me.getenv_(me)
}

// extern int emacs_module_init (struct emacs_runtime *runtime)
pub type ModInitin = fn (rt voidptr) int

pub type Funcin = fn (env voidptr, nargs usize, args voidptr, data voidptr) voidptr

pub type Finalin = fn (data voidptr)

pub enum FcallExit {
	return_
	signal_
	throw_
}

pub enum ProcInputResult {
	continue_
	quit_
}

pub type Limb = isize
pub type Symbol = string
pub type ElfuncType = Symbol | Value | string

pub union Env {
pub mut:
	vh  Envheader
	v25 Env25
	v29 Env29
	vm  Env29 // note: this need change to max version when major upgrade
}

pub fn (me &Env) chkeq(o &Env) {
	eq := voidptr(me) == unsafe { nil }
	if !eq {
		vcp.info('eq', eq, 'me', voidptr(me), 'o', voidptr(o))
	}
}

pub fn (me &Env) nle_check() FcallExit {
	return me.vm.non_local_exit_check(me)
}

pub fn (me &Env) intern(name string) Value {
	return me.vm.intern_(me, name.str)
}

pub fn (me Value) globref(env &Env) Value {
	return env.globref(me)
}

pub fn (me &Env) globref(v Value) Value {
	return me.vm.make_global_ref(me, v)
}

pub fn (me Value) unglobref(env &Env) {
	env.unglobref(me)
}

pub fn (me &Env) unglobref(v Value) {
	me.vm.free_global_ref(me, v)
}

pub fn (me &Env) fcall(fun Value, args ...Value) Value {
	nargs := isize(args.len)
	rv := me.vm.funcall(me, fun, nargs, args.data)
	return rv
}

pub fn (me &Env) fcall2(funame string, args ...Value) Value {
	fun := me.intern(funame)
	nargs := isize(args.len)
	rv := me.vm.funcall(me, fun, nargs, args.data)
	return rv
}

// todo
pub fn (me &Env) fcall3(funame string, args ...Anyer) Anyer {
	fun := me.intern(funame)
	nargs := isize(args.len)
	arr := []Value{len: args.len + 1}
	for i := 0; i < args.len; i++ {
		arg := args[i]
		v := me.toel(arg)
		arr[i] = v
	}
	rv := me.vm.funcall(me, fun, nargs, arr.data)
	vcp.info(funame, rv.strfy(me))
	// 	return rv
	return zeroof[Anyer]()
}

pub fn (me &Env) toel(arg Anyer) Value {
	rv := emvs.elnil
	match arg {
		string {
			rv = me.strval(arg)
		}
		int, isize, usize, i32, i64, u64 {
			rv = me.intval(isize(arg))
		}
		f64, f32 {
			rv = me.realval(f64(arg))
		}
		// ???
		bool {}
		Value {
			rv = arg
		}
		Symbol {
			rv = me.intern(arg)
		}
		voidptr {
			rv = arg
		}
		else {
			vcp.warn('nocat', arg)
		}
	}
	return rv
}

pub fn (me &Env) fromel(arg Value) Anyer {
	tyo := arg.typof(me)
	tystr := tyo.strfy(me)
	match tystr {
		// 'string' {}
		// 'symbol' {}
		// 'integer' {}
		// 'float' {}
		'boolean' {}
		else {
			vcp.info('nocat', tystr)
		}
	}
	return zeroof[Anyer]()
}

// strfy
pub fn (me Value) strfy(env &Env) string {
	return env.strfy(me)
}

pub fn (env &Env) strfy(me Value) string {
	nargs := isize(1)
	rv := env.fcall2('prin1-to-string', me)
	s := rv.tostr(env)
	return s
}

pub fn (me Value) isnil(env &Env) bool {
	return env.isnil(me)
}

pub fn (env &Env) isnil(me Value) bool {
	if me.asptr() == vnil {
		return true
	}
	rv := env.vm.is_not_nil(env, me)
	return !rv
}

pub fn (me Value) typof(env &Env) Value {
	return env.typof(me)
}

pub fn (env &Env) typof(me Value) Value {
	rv := env.vm.type_of(env, me)
	return rv
}

pub fn (me Value) toint(env &Env) isize {
	return env.toint(me)
}

pub fn (env &Env) toint(me Value) isize {
	rv := env.vm.extract_integer(env, me)
	return rv
}

pub fn (me Value) tostr(env &Env) string {
	return env.tostr(me)
}

// must string type or fail
pub fn (env &Env) tostr(me Value) string {
	size := isize(0)
	bv := env.vm.copy_string_contents(env, me, vnil, &size)
	// assert bv == true
	if bv == false {
		env.nle_check()
		return ''
	}
	// vcp.info('needlen', size, bv)
	buf := []i8{len: int(size)}
	bv = env.vm.copy_string_contents(env, me, buf.data, &size)
	// assert bv == true
	env.nle_check()

	rv := tosbca(buf.data, int(size))
	return rv
}

pub fn (me &Env) intval(v isize) Value {
	rv := me.vm.make_integer(me, v)
	return rv
}

pub fn (me &Env) strval(v string) Value {
	rv := me.vm.make_string(me, v.str, isize(v.len))
	me.chkret()
	return rv
}

pub fn (me &Env) realval(v f64) Value {
	rv := me.vm.make_float(me, v)
	return rv
}

fn elmodfunfwder(e &Env, nargs isize, args &Value, data voidptr) Value {
	vcp.info(e, nargs, data)
	cb := funcof(data, fn (_ &Env) {})
	cb(e)
	return emvs.elnil
}

pub fn (me &Env) funval(cb fn (e &Env)) Value {
	elfn := me.vm.make_function_(me, 0, 0, elmodfunfwder, vnil, voidptr(cb))
	me.nle_check()
	return elfn
}

// pub fn (me &Env) nle_get() FcallExit {
// 	return me.vm.non_local_exit_check(me)
// }

// todo cannot get errmsg
pub fn (me &Env) chkret() {
	sym := emvs.elnil
	data := emvs.elnil
	tv := me.vm.non_local_exit_get(me, &sym, &data)
	if tv != .return_ {
		vcp.info(tv.str(), sym.isnil(me), data.isnil(me))
	}
}

///

pub struct Envheader {
pub:
	size            isize
	private_members voidptr
}

pub struct Env25 {
	Envheader //
	// pub:
	// ...
}

pub struct Env29 {
	Envheader
pub:
	make_global_ref fn (env voidptr, value Value) Value  = vnil
	free_global_ref fn (env voidptr, global_value Value) = vnil

	non_local_exit_check fn (env voidptr) FcallExit = vnil

	non_local_exit_clear fn (env voidptr) = vnil

	non_local_exit_get fn (env voidptr, symbol voidptr, data voidptr) FcallExit = vnil

	non_local_exit_signal fn (env voidptr, symbol voidptr, data voidptr) = vnil

	non_local_exit_throw fn (env voidptr, tag voidptr, value voidptr) = vnil

	make_function_ fn (env voidptr, min_arity isize, max_arity isize, fun fn (e voidptr, nargs isize, args &Value, data voidptr) Value, docstr charptr, data voidptr) Value = vnil

	funcall fn (env voidptr, fun Value, nargs isize, args &Value) Value = vnil

	intern_ fn (env voidptr, name charptr) Value = vnil

	type_of fn (env voidptr, arg Value) Value = vnil

	is_not_nil fn (env voidptr, arg Value) bool = vnil

	eq fn (env voidptr, a Value, b Value) bool = vnil

	extract_integer fn (env voidptr, arg Value) isize = vnil

	make_integer fn (env voidptr, n isize) Value = vnil

	extract_float fn (env voidptr, arg Value) f64 = vnil

	make_float fn (env voidptr, d f64) Value = vnil

	copy_string_contents fn (env voidptr, value Value, buf byteptr, len &isize) bool = vnil

	make_string fn (env voidptr, str charptr, len isize) Value = vnil

	make_user_ptr fn (env voidptr, fin fn (voidptr), ptr voidptr) voidptr = vnil

	get_user_ptr fn (env voidptr, arg voidptr) voidptr      = vnil
	set_user_ptr fn (env voidptr, arg voidptr, ptr voidptr) = vnil

	get_user_finalizer_ fn (env voidptr, arg Value) voidptr = vnil

	set_user_finalizer_ fn (env voidptr, arg Value, fin fn (voidptr)) = vnil

	vec_get fn (env voidptr, vector Value, index isize) Value = vnil

	vec_set fn (env voidptr, vector Value, index isize, value Value) = vnil

	vec_size fn (env voidptr, vector Value) isize = vnil

	should_quit fn (env voidptr) bool = vnil

	process_input fn (env voidptr) ProcInputResult = vnil

	extract_time_ fn () = vnil
	// struct timespec (*extract_time) (emacs_env *env, emacs_value arg)
	// EMACS_ATTRIBUTE_NONNULL (1);
	make_time_ fn () = vnil
	// emacs_value (*make_time) (emacs_env *env, struct timespec time)
	// EMACS_ATTRIBUTE_NONNULL (1);
	extract_big_integer fn (env voidptr, arg voidptr, sign &int, count &isize, magnitude &Limb) bool = vnil

	make_big_integer fn (env voidptr, sign int, count isize, magnitude &Limb) voidptr = vnil

	// return should be fn(voidptr)
	get_function_finalizer_ fn (env voidptr, arg Value) voidptr = vnil
	// void (*(*EMACS_ATTRIBUTE_NONNULL (1)
	//           get_function_finalizer) (emacs_env *env,
	//                                    emacs_value arg)) (void *) EMACS_NOEXCEPT;

	set_function_finalizer_ fn (env voidptr, arg Value, fin fn (voidptr)) = vnil

	open_channel fn (env voidptr, pipe_process voidptr) int = vnil

	make_interactive fn (env voidptr, function voidptr, spec voidptr) = vnil

	make_unibyte_string fn (env voidptr, str charptr, len isize) voidptr = vnil
}
