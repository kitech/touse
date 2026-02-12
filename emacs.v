@[has_globals]
module emacs

import dl
import flag
import time
import os

import vcp
import vcp.reflect as refl

#include <emacs-module.h>
#include "@DIR/emacsx.h"

// this #flag fix v -shared result symbol not found
// #flag @VEXEROOT/thirdparty/tcc/lib/tcc/libtcc1.a
// #flag @VEXEROOT/thirdparty/tcc/lib/tcc/bcheck.o
// tcc_backtrace symbol here
#flag @VEXEROOT/thirdparty/tcc/lib/tcc/bt-log.o
// bt_init symbol here
#flag @VEXEROOT/thirdparty/tcc/lib/tcc/bt-exe.o
// need __rt_exit???
// #flag @VEXEROOT/thirdparty/tcc/lib/tcc/runmain.o

// 这篇文档讲的详细, https://phst.eu/emacs-modules.html

@[markused]
__global plugin_is_GPL_compatible = 1

fn init() {
	// C.infolm(c'...')
}

// this is first called, even before emacs.init()

// noexcept: orcrash
@[export: 'emacs_module_init']
fn eminit4c(rtx &C.emacs_runtime) int {
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
	cfg, nomats := parse_flags[Config](env) or { vcp.error(err.str()) }
	ref2mut(emvs).cfg = cfg

	refvar2mut(emvs).elnil = env.globref(env.intern('nil'))
	refvar2mut(emvs).eltrue = env.globref(env.intern('t'))
	refvar2mut(emvs).elvoid = env.globref(env.intern('void'))
	// refvar2mut(emvs).rt = rt
	// refvar2mut(emvs).env = env
	sockfile := os.join_path(env.getvar('server-socket-dir').tostr(env), 'server')
	ref2mut(emvs).servsockfile = sockfile
	env.defun('emacs-runon-uithread', emacs_runon_uithread, '')

	if cfg.basett {
		basictt(env)
	}

	if emvs.emuser_init != vnil {
		emvs.emuser_init(env)
	}
	return 0
}

fn emcheckenv(e &Env) {
	expsz := u32(0)
	if MAJOR_VERION == 30 {
		expsz = sizeof(Env30)
	}else if MAJOR_VERION == 29 {
		expsz = sizeof(Env29)
	} else if MAJOR_VERION == 25 {
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

// args from emacs command-line-args
pub fn parse_flags[T](e &Env) !(T, []string) {
	argevs := e.symbol_value('command-line-args').cons2arr(e)
	if argevs.len <= 1 {
		// only ./exe
		// return // sofork of vlang syntax, cannot dirrect return
	}

	args := []string{len: argevs.len}
	for idx, ev in argevs {
		args[idx] = ev.tostr(e)
	}

	cfg, nomats := flag.to_struct[T](args) or { return err }
	// ref2mut(emcvs).cfg = cfg
	return cfg, nomats
}

// https://www.gnu.org/software/emacs/manual/html_node/elisp/Command_002dLine-Arguments.html
struct Config {
	// sofork, emacs: Option '-t' requires an argument
	// use -t=on for short
	basett   bool   @[desc: 'if call basictt test func'; short: t]
	relayout bool   @[desc: 're layout ui'; short: y]
	asyncbkd string @[desc: 'sptaskd, emacs process'] //
	loglvl   string @[desc: 'warn,info,debug,error']
	vemver   bool
}

// todo what will happend if load to .so use this library
const emvs = &Emvars{}

struct Emvars {
pub mut:
	cfg Config

	callcnt i64 = 0 // maybe call multiple times by emacs???
	elnil   Value
	eltrue  Value
	elvoid  Value

	// dont save any emacs Runtime/Env's reference
	// rt  &Runtime = vnil
	// env &Env     = vnil
	emuser_init fn (e &Env) = vnil

	elclostmpno i64 = 10

	lasterr   string
	errdupcnt int
	lasterrtm time.Time

	servsockfile string
}

///
pub const MAJOR_VERION = C.EMACS_MAJOR_VERSION

// should be voidptr, but voidptr has some special
pub type Value = usize // = &ValueTag
pub type LispObject = usize // LispWord

pub fn (me Value) asptr() voidptr {
	return voidptr(usize(me))
}

pub struct ValueTag {
pub mut:
	v LispObject // Lisp_Object v;
}

pub struct LispString {
pub mut:
	size      isize
	size_byte isize
	intervals voidptr // todo
	data      charptr
	// unioned next &LispString
	// unioned GCALIGNED_UNION_MEMBER
}

const value_frame_size = 512

pub struct ValueFrame {
pub mut:
	objects [512]ValueTag
	offset  cint
	next    &ValueFrame = vnil
}

pub struct ValueStorage {
pub mut:
	initial ValueFrame
	current &ValueFrame = vnil
}

pub struct Envpriv {
pub mut:
	// enum emacs_funcall_exit
	pending_non_local_exit FcallExit

	non_local_exit_symbol voidptr
	non_local_exit_data   voidptr

	storage ValueStorage
}

@[typedef]
struct C.emacs_runtime {}

pub type RuntimePrivate = usize

pub struct RuntimePriv {
pub:
	init_env &Env = vnil
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

pub type Funcin = fn (env &Env, nargs isize, args &Value, data voidptr) Value

pub type Funcur = fn (env &Env, args []Value) Value

pub type FuncurNoret = fn (env &Env, args []Value)

pub type FuncurNoarg = fn (env &Env)

pub type FuncurAll = Funcin | Funcur | FuncurNoret | FuncurNoarg

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
pub type ElsymType = Symbol | Value | string

pub union Env {
pub mut:
	vh  Envheader
	v25 Env25
	v29 Env29
	vm  Env29 // note: this need change to max version when major upgrade
}

pub fn (me &Env) asptr() voidptr {
	return voidptr(me)
}

pub fn elnil() Value {
	return emvs.elnil
}

pub fn eltrue() Value {
	return emvs.eltrue
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

pub fn (me &Env) nle_clear() {
	me.vm.non_local_exit_clear(me)
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

pub fn (me &Env) eq(a Value, b Value) bool {
	return me.vm.eq(me, a, b)
}

pub fn (me &Env) fcall(fun Value, args ...Value) Value {
	nargs := isize(args.len)
	rv := me.vm.funcall(me, fun, nargs, args.data)
	me.nle_check()
	return rv
}

pub fn (me &Env) fcall2(funame string, args ...Value) Value {
	fun := me.intern(funame)
	nargs := isize(args.len)
	rv := me.vm.funcall(me, fun, nargs, args.data)
	me.nle_check()
	return rv
}

// todo return value, or return Value?
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
	me.chkret()
	// vcp.info(funame, rv.strfy(me))
	// 	return rv
	return zeroof[Anyer]()
}

pub fn (me &Env) toel(arg Anyer) Value {
	itfin := refl.itface2struct(&arg)
	rv := emvs.elnil
	match arg {
		string {
			rv = me.strval(arg)
		}
		// seems v not correct deref, when multiple match items
		// wait v fix this
		int, isize, usize, i32, i64, u64 {
			dptr := usize(arg)
			tv := isize(arg)
			tv2 := derefvar[isize](itfin.ptr)
			if tv != tv2 {
				assert dptr == itfin.ptr
				// vcp.info(tv, itfin.typ, tv2)
				tv = tv2
			}
			rv = me.intval(tv)
		}
		f64 {
			rv = me.realval(arg)
		}
		f32 {
			// dptr := usize(arg)
			// tv := f64(arg)
			tv2 := derefvar[f32](itfin.ptr)
			// if tv != tv2 {
			// 	// assert dptr == itfin.ptr
			// 	// vcp.info(tv, itfin.typ, tv2)
			// 	tv = tv2
			// }
			rv = me.realval(tv2)
		}
		// ???
		bool {
			rv = bool2el(arg)
		}
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

// elisp的类型太多,似乎不容易转
pub fn (me &Env) fromel(arg Value) Anyer {
	tyo := arg.typof(me)
	tystr := tyo.strfy(me)

	rv := Anyer(arg)
	match tystr {
		// 什么也不是类型
		// '' {}
		'string' {
			rv = arg.tostr(me)
		}
		'symbol' { // get symbol name???
			// tv := me.symbol_value2(arg)
			// vcp.info(111)
			// rv = Symbol(tv.strfy(me)) // == arg.symbol_name(me)
			// vcp.info(222, arg.symbol_name(me), '/')
		}
		'integer' {
			tv := arg.toint(me)
			rv = tv
			// vcp.info(222, tv, rv as isize) // correct
			assert rv as isize == tv
		}
		'float' {
			rv = arg.toreal(me)
		}
		// 还没有构造出来过elisp的boolean value
		// 'boolean' {}
		else {
			vcp.info('nocat', tystr, '/')
		}
	}
	return rv
}

// strfy
pub fn (me Value) strfy(env &Env) string {
	return env.strfy(me)
}

pub fn (env &Env) strfy(me Value) string {
	// ty := env.vm.type_of(env, me)
	// env.nle_check()
	// if ty.isnil(env) {
	// 	return 'tynil'
	// }
	// tystr := env.fcall2('prin1-to-string', ty).tostr(env)
	// vcp.info(me, tystr, '/', me.isnil(env), ty.isnil(env))
	// if tystr == 'symbol' {
	// 	symstr := env.fcall2('prin1-to-string', me).tostr(env)
	// 	return 'symbol(${symstr})'
	// }
	// symbol cannot print1-to-string
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
	env.nle_check()
	return rv
}

pub fn (me Value) toint(env &Env) isize {
	return env.toint(me)
}

pub fn (env &Env) toint(me Value) isize {
	rv := env.vm.extract_integer(env, me)
	return rv
}

pub fn (me Value) toreal(env &Env) f64 {
	return env.toreal(me)
}

pub fn (env &Env) toreal(me Value) f64 {
	rv := env.vm.extract_float(env, me)
	return rv
}

pub fn (me Value) tostr(env &Env) string {
	return env.tostr(me)
}

pub const evtostr_nil0 = 'elvtostr(nil0)'

// must string type or fail
pub fn (env &Env) tostr(me Value) string {
	if me.isnil(env) { // check avoid report error
		return 'elvtostr(nil0)'
	}
	// bvx := env.vm.funcall(env, env.intern('stringp'), 1, &me)
	// if bvx.isnil(env) {
	// 	vcp.warn('notstr, should', me.typof(env).strfy(env), me)
	// 	return 'elvtostr(notstr)'
	// }

	size := isize(0)
	bv := env.vm.copy_string_contents(env, me, vnil, &size)
	if bv == false {
		return 'elvtostr(nil1)'
	}
	// vcp.info('needlen', size, bv)
	buf := []i8{len: int(size)}
	bv = env.vm.copy_string_contents(env, me, buf.data, &size)
	// assert bv == true
	// env.nle_check()
	env.chkret()

	assert size > 0
	rv := tosbca(buf.data, int(size) - 1)
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

// data is real callback fnptr
fn elmodfunfwder(e &Env, nargs isize, args &Value, data voidptr) Value {
	if data == vnil {
		vcp.warn(e, nargs, data)
	}
	vcp.warnif(nargs > 0, nargs, 'use funvalx instead')
	for idx in 0 .. nargs {
		item := args[idx]
		aty := item.typof(e)
		// vcp.info(idx.str(), item, aty.strfy(e), item.strfy(e))
	}
	cb := funcof(data, fn (_ &Env) {})
	cb(e)
	return emvs.elnil
}

pub fn (me &Env) funval(cb fn (e &Env)) Value {
	elfn := me.vm.make_function_(me, 0, 16, elmodfunfwder, vnil, voidptr(cb))
	me.nle_check()
	return elfn
}

// data is real callback fnptr
fn elmodfunfwderx(e &Env, nargs isize, args &Value, data voidptr) Value {
	if data == vnil {
		vcp.warn(e, nargs, data)
	}
	argv := []Value{len: int(nargs)}
	for idx in 0 .. nargs {
		item := args[idx]
		aty := item.typof(e)
		argv[idx] = item
		// vcp.info(idx.str(), item, aty.strfy(e), item.strfy(e))
	}

	cb := derefvar[FuncurAll](data) //  work
	rv := emvs.elnil
	matval := ''
	match cb {
		Funcin {
			matval = 'Funcin'
			rv = cb(e, nargs, args, data)
		}
		Funcur {
			matval = 'Funcur'
			rv = cb(e, argv)
		}
		FuncurNoret {
			matval = 'FuncurNoret'
			cb(e, argv)
		}
		FuncurNoarg {
			matval = 'FuncurNoarg'
			cb(e)
		}
		// else {}
	}
	if matval == '' {
		itfin := castptr[Itfacein](data)
		vcp.warn('nomat', matval, cb.str(), data, itfin.itfidx)
	}
	return rv
}

// todo when remove item in this refs
// elisp cannot correct ref native pointer
// native gc will collect that only in elisp,
// so this fixsom
struct Refvars {
mut:
	refs map[string]voidptr // ptr.str()=>ptr
}

const refvars = &Refvars{}

pub fn (me &Env) funvalx(cb FuncurAll) Value {
	adr := &cb // stack addr, invalid when use
	adr = vardup(cb)
	itfin := refl.itface2struct(&cb)
	itfin = castptr[Itfacein](adr)
	vcp.info(voidptr(adr), itfin.itfidx)
	// avoid gc adr
	ref2mut(refvars).refs['${voidptr(adr)}'] = adr

	elfn := me.vm.make_function_(me, 0, 16, elmodfunfwderx, vnil, voidptr(adr))
	me.nle_check()
	// wrong-type-argument: (user-ptrp)
	// me.vm.set_user_finalizer_(me, elfn, fn (val voidptr) {
	// 	vcp.info('emvalfin', val)
	// })
	return elfn
}

// pub fn (me &Env) nle_get() FcallExit {
// 	return me.vm.non_local_exit_check(me)
// }

/*
https://archive.fosdem.org/2019/schedule/event/extend_emacs_2019/attachments/slides/3357/export/events/attachments/extend_emacs_2019/slides/3357/FOSDEM19_emacs_modules.pdf
All API operations may fail and set a pending per-env exit
state
– Similar to errno in concept
*/

pub fn (me &Env) nle_clear_indeep() {
	insym := me.vm.private_members.non_local_exit_symbol
	indata := me.vm.private_members.non_local_exit_data
	me.vm.private_members.pending_non_local_exit = .return_
	me.vm.private_members.non_local_exit_symbol = vnil
	me.vm.private_members.non_local_exit_data = vnil
	// vcp.info(me.vh.str())
}

// todo cannot get errmsg
pub fn (me &Env) chkret() {
	sym := emvs.eltrue
	data := emvs.eltrue // emvs.elnil

	tv := me.vm.non_local_exit_get(me, &sym, &data)
	assert tv == me.vm.private_members.pending_non_local_exit
	me.vm.non_local_exit_clear(me) // 这是一个技巧,拿到错误信息就清除,然后再解析错误

	if tv != .return_ {
		// vcp.info(tv.str(), sym.isnil(me), data.isnil(me))
		errmsg := sym.strfy(me) + ': ' + data.strfy(me)
		if errmsg != emvs.lasterr {
			vcp.warn(errmsg)
			refvar2mut(emvs).lasterr = errmsg
		} else {
			refvar2mut(emvs).errdupcnt += 1
		}
		refvar2mut(emvs).lasterrtm = time.now()

		// peek mode, restore it
		me.vm.private_members.pending_non_local_exit = tv
	}
}

pub fn (me &Env) vecget(vec Value, idx isize) Value {
	return me.vm.vec_get(me, vec, idx)
}

pub fn (me &Env) vecset(vec Value, idx isize, newval Value) {
	me.vm.vec_set(me, vec, idx, newval)
}

pub fn (me &Env) veclen(vec Value) int {
	rv := me.vm.vec_size(me, vec)
	return int(rv)
}

pub fn (me &Env) should_quit() bool {
	return me.vm.should_quit_(me)
}

pub fn (me &Env) set_user_ptr(v Value, ptr voidptr) {
	me.vm.set_user_ptr_(me, v, ptr)
}

pub fn (me &Env) get_user_ptr(v Value) voidptr {
	return me.vm.get_user_ptr_(me, v)
}

pub fn (v Value) set_user_ptr(me &Env, ptr voidptr) {
	me.set_user_ptr(v, ptr)
}

pub fn (v Value) get_user_ptr(me &Env) voidptr {
	return me.get_user_ptr(v)
}

///

pub struct Envheader {
pub mut:
	size            isize
	private_members &Envpriv
}

pub struct Env30 {
	Env29
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

	get_user_ptr_ fn (env voidptr, arg Value) voidptr      = vnil
	set_user_ptr_ fn (env voidptr, arg Value, ptr voidptr) = vnil

	get_user_finalizer_ fn (env voidptr, arg Value) voidptr = vnil

	set_user_finalizer_ fn (env voidptr, arg Value, fin fn (voidptr)) = vnil

	vec_get fn (env voidptr, vector Value, index isize) Value = vnil

	vec_set fn (env voidptr, vector Value, index isize, value Value) = vnil

	vec_size fn (env voidptr, vector Value) isize = vnil

	should_quit_ fn (env voidptr) bool = vnil

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

pub struct Env25 {
	Envheader //
	// pub:
	// ...
}
