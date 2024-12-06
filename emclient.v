module emacs

import net
import net.unix
import vcp
import os
import time

#flag @VMODROOT/emacs/emclient.o

fn C.emacs_quote_argument(...voidptr) cint
fn C.emacs_unquote_argument(...voidptr) cint
pub fn quote(v string) string {
	rv := []u8{len: v.len * 2 + 1}
	rc := C.emacs_quote_argument(v.str, rv.data)

	return rv[..int(rc)].bytestr()
}

pub fn unquote(v string) string {
	rc := C.emacs_unquote_argument(v.str)
	return v[..(int(rc) - 1)]
}

/* In STR, insert a & before each &, each space, each newline, and
any initial -.  Change spaces to underscores, too, so that the
return value never contains a space.

Does not change the string.  Outputs the result to S.  */
pub fn quote_(v string) string {
	if v.len == 0 {
		return v
	}
	rv := ''
	if v[0] == `-` {
		rv += '&-'
	}
	for idx, c in v {
		if c == ` ` {
			rv += '&_'
		} else if c == `\n` {
			rv += '&n'
		} else if c == `&` {
			rv += '&&'
		} else {
			rv += rune(c).str()
		}
	}
	return rv
	// rv = v.replace(' ', '&')
	// return rv.replace(' ', '&_')
}

pub fn unquote_(v string) string {
	rv := ''
	for idx := 0; idx < v.len; idx++ {
		c := v[idx]
		if c == `&` {
			if v[idx + 1] == `_` {
				rv += ' '
				idx++
			} else if v[idx + 1] == `n` {
				rv += '\n'
				idx++
			}
		} else {
			rv += rune(c).str()
		}
	}
	return rv
	// return v.replace('&_', ' ')
}

pub type UifuncType = string | Funcur | voidptr

//  proc can also be elisp symbol
pub fn runon_uithread_nowait(proc UifuncType, args ...Anyer) ! {
	runon_uithread(proc, false, ...args)!
}

// function addr not need deref, arg need deref!!!
// 1ms-30ms+
// also means emacs main thread
pub fn runon_uithread(proc UifuncType, nowait bool, args ...Anyer) ! {
	btime := time.now()
	mypid := os.getpid() // sender
	sockfile := emvs.servsockfile
	if sockfile == '' {
		sockfile = '/run/user/1000/emacsv/server'
	}
	c := unix.connect_stream(sockfile) or {
		vcp.error(err.str(), sockfile, '/')
		return err
	}
	defer { c.close() or { panic(err) } }

	cmd := 'print server-socket-dir'
	cmd = 'emacs-runon-uithread 12345678'
	// cmd = 'emacs-runon-uithread ${mypid} ${usize(proc)} ${args.len}'
	cmd = 'emacs-runon-uithread ${mypid}'
	match proc {
		string {
			cmd += ' "${proc}"'
		}
		// 	Funcur {
		// 		cmd += ' "0x${voidptr(proc)}"'
		// 		vcp.info(proc, voidptr(proc).str())
		// 		vcp.info(cmd)
		// 	}
		// 	voidptr {
		// 		cmd += ' "0x${voidptr(proc)}"'
		// 	}
		else {
			procin := itface2struct(&proc)
			// vcp.info(proc.str(), procin.ptr, derefvar[voidptr](procin.ptr))
			// vcp.info(proc.str(), itfptrof(&proc), derefvar[voidptr](itfptrof(&proc)))
			cmd += ' "0x${procin.ptr}"'
		}
	}
	cmd += ' ${args.len}'
	for idx, arg in args {
		itfin := itface2struct(&args[idx])
		val := anyer_strfy(arg)
		// match arg { }
		cmd += ' ${val}'
	}

	cmd = quote(cmd)
	prm := ifelse(nowait, '-nowait', '')
	vcp.info(prm, cmd)
	n := c.write_string('${prm} -eval (${cmd})\n') or { panic(err) }
	// vcp.info(n, cmd, voidptr(proc))

	// vcp.info('write used', time.since(btime).str()) // 150us
	// todo how
	if nowait {
		vcp.info('todo -nowait', nowait)
		// return
	}

	res := ''
	btime = time.now()
	c.set_read_timeout(time.millisecond * 500)
	for {
		mut buf := []u8{len: 128}
		n = c.read(mut buf) or {
			if err.str() != 'none' {
				vcp.error(err.str())
			}
			break
		}
		// vcp.info(n, buf[..n].bytestr(), '/')
		res += buf[..n].bytestr()
	}
	etime := time.now()
	// parse result
	lines := res.split('\n')
	for idx, line in lines {
		if line.len == 0 {
			break
		}
		kv := line.split(' ')
		k, v := kv[0], unquote(kv[1])

		vcp.info('<<<', idx.str(), 'k', k, 'v', v, time.since(btime).str())
	}
}

pub fn anyer_strfy(arg Anyer) string {
	itfin := itface2struct(&arg)
	val := match arg {
		int {
			'${arg}'
		}
		i32 {
			'${arg}'
		}
		usize {
			'${arg}'
		}
		isize {
			'${arg}'
		}
		i64 {
			'${arg}'
		}
		u64 {
			'${arg}'
		}
		f32 {
			if arg.str().contains('.') {
				'${arg}'
			} else {
				'${arg}.'
			}
		}
		f64 {
			if arg.str().contains('.') {
				'${arg}'
			} else {
				'${arg}.'
			}
		}
		string {
			'"${arg}"'
		}
		// Funcur{}
		voidptr {
			tv := derefvar[voidptr](itfin.ptr)
			'"0x${tv}"'
		}
		else {
			'"${arg}"' // Anyer(foo)
		}
	}
	return val
}

// must 0x12345abc format
pub fn ofptrstr(s string) voidptr {
	ptrx := s[2..].parse_uint(16, 64) or { 0 }
	assert ptrx != 0, s
	ptr := voidptr(usize(ptrx))
	return ptr
}

pub fn toptrstr(v voidptr) string {
	return '0x${v}'
}

fn tt_runonth(e &Env, args []Value) Value {
	vcp.info('ehehe', e.asptr(), args.len, args.str())
	return emvs.eltrue
}

// defalis: emacs-runon-uithread
fn emacs_runon_uithread(e &Env, argc isize, args &Value, data voidptr) Value {
	fixcnt := 3 // pid, fnptr, argc
	arr := []Value{len: int(argc) - fixcnt}
	for i := 0; i < argc; i++ {
		tv := args[i]
		// vcp.info(i.str(), tv.typof(e).strfy(e), tv.strfy(e))
		if i >= fixcnt {
			arr[i - fixcnt] = tv
		}
	}

	mypid := os.getpid()
	a0 := args[0].toint(e)
	a1 := args[1].tostr(e)

	isfnptr := a1.starts_with('0x')
	rv := emvs.elnil
	if isfnptr {
		// overflow-error: (11595785290660792405)
		// a1 := voidptr(usize(args[1].toint(e)))
		if a0 != mypid {
			// a1 = voidptr(tt_runonth)
			a1 = '0x${voidptr(tt_runonth)}'
		}

		fnptrx := a1[2..].parse_uint(16, 64) or { 0 }
		assert fnptrx != 0, a1
		fnptr := voidptr(usize(fnptrx))
		fnv := Funcur(fnptr)
		// vcp.info('calling from/mypid', a0, mypid, argc, a1)
		rv = fnv(e, arr)
		// vcp.info('done', argc, a1)
	} else {
		// vcp.info('calling', a1, arr.len)
		rv = e.fcall2(a1, ...arr)
	}

	// vcp.info('argc=${argc}, data=${data}, rv=${rv.strfy(e)}')
	return rv
}
