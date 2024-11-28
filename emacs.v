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

__global plugin_is_GPL_compatible = 1

@[export: 'emacs_module_init']
fn eminitc(rtx &C.emacs_runtime) int {
	vcp.fixvsogc()
	vcp.fixvsoinit()

	rt := castptr[Runtime](rtx)
	rv := eminit(rt)
	return rv
}

fn eminit(rt &Runtime) int {
	vcp.info('emver:', MAJOR_VERION, rt.str().compact())
	env := rt.getenv()
	refvar2mut(emvs).rt = rt
	refvar2mut(emvs).env = env

	vcp.info('envinfo:', env.vh.size, sizeof(Env))
	emcheckenv(env)
	vcp.info('envfn:', env.nle_check().str())
	tv2 := env.intern('hehehe')
	tv := env.intval(123)
	vcp.info('envfn:', tv)
	vcp.info(tv.isnil(), tv2.isnil())
	vcp.info(tv.toint(), tv2.toint())
	vcp.info(tv.toint(), tv2.toint()) // why zero

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

// todo what will happend if load to .so use this library
const emvs = &Emvars{}

struct Emvars {
pub mut:
	rt  &Runtime = vnil
	env &Env     = vnil
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

pub fn getrt() &Runtime {
	return emvs.rt
}

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

pub union Env {
pub mut:
	vh  Envheader
	v25 Env25
	v29 Env29
	vm  Env29 // note: this need change to max version when major upgrade
}

pub fn (me &Env) nle_check() FcallExit {
	return me.vm.non_local_exit_check(me)
}

pub fn (me &Env) intern(name string) Value {
	return me.vm.intern_(me, name.str)
}

pub fn (me Value) toint() isize {
	env := emvs.env
	rv := env.vm.extract_integer(env, me)
	return rv
}

pub fn (me &Env) intval(v isize) Value {
	rv := me.vm.make_integer(me, v)
	return rv
}

pub fn (me Value) isnil() bool {
	env := emvs.env
	rv := env.vm.is_not_nil(env, me)
	return !rv
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
	make_global_ref fn (env voidptr, value Value) voidptr  = vnil
	free_global_ref fn (env voidptr, global_value voidptr) = vnil

	non_local_exit_check fn (env voidptr) FcallExit = vnil

	non_local_exit_clear fn (env voidptr) = vnil

	non_local_exit_get fn (env voidptr, symbol voidptr, data voidptr) FcallExit = vnil

	non_local_exit_signal fn (env voidptr, symbol voidptr, data voidptr) = vnil

	non_local_exit_throw fn (env voidptr, tag voidptr, value voidptr) = vnil

	make_function_ fn () = vnil
	// make_function fn (env voidptr, min_arity isize, max_arity isize,
	//                func fn(e voidptr, nargs isize, args voidptr, data voidptr) voidptr,
	//                docstring charptr, data voidptr) voidptr = vnil
	funcall fn (env voidptr, func voidptr, nargs isize, args voidptr) voidptr = vnil

	intern_ fn (env voidptr, name charptr) Value = vnil

	type_of fn (env voidptr, arg Value) Value = vnil

	is_not_nil fn (env voidptr, arg Value) bool = vnil

	eq fn (env voidptr, a voidptr, b voidptr) bool = vnil

	extract_integer fn (env voidptr, arg Value) isize = vnil

	make_integer fn (env voidptr, n isize) Value = vnil

	extract_float fn (env voidptr, arg Value) f64 = vnil

	make_float fn (env voidptr, d f64) Value = vnil

	copy_string_contents fn (env voidptr, value voidptr, buf byteptr, len &isize) bool = vnil

	make_string fn (env voidptr, str charptr, len isize) Value = vnil

	make_user_ptr fn (env voidptr, fin fn (voidptr), ptr voidptr) voidptr = vnil

	get_user_ptr fn (env voidptr, arg voidptr) voidptr      = vnil
	set_user_ptr fn (env voidptr, arg voidptr, ptr voidptr) = vnil

	get_user_finalizer_ fn () = vnil
	// get_user_finalizer fn (env voidptr, uptr voidptr)
	// void (*(*get_user_finalizer) (emacs_env *env, emacs_value uptr))
	//   (void *) EMACS_NOEXCEPT EMACS_ATTRIBUTE_NONNULL(1);
	set_user_finalizer_ fn () = vnil
	// void (*set_user_finalizer) (emacs_env *env, emacs_value arg,
	//   		      void (*fin) (void *) EMACS_NOEXCEPT)
	//   EMACS_ATTRIBUTE_NONNULL(1);
	vec_get fn (env voidptr, vector voidptr, index isize) voidptr = vnil

	vec_set fn (env voidptr, vector isize, index isize, value voidptr) = vnil

	vec_size fn (env voidptr, vector voidptr) isize = vnil

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

	get_function_finalizer_ fn () = vnil
	// void (*(*EMACS_ATTRIBUTE_NONNULL (1)
	//           get_function_finalizer) (emacs_env *env,
	//                                    emacs_value arg)) (void *) EMACS_NOEXCEPT;
	set_function_finalizer_ fn () = vnil
	// void (*set_function_finalizer) (emacs_env *env, emacs_value arg,
	//                                 void (*fin) (void *) EMACS_NOEXCEPT)
	//   EMACS_ATTRIBUTE_NONNULL (1);
	open_channel fn (env voidptr, pipe_process voidptr) int = vnil

	make_interactive fn (env voidptr, function voidptr, spec voidptr) = vnil

	make_unibyte_string fn (env voidptr, str charptr, len isize) voidptr = vnil
}
