module emacs

import net
import net.unix
import vcp
import os

#flag @VMODROOT/emacs/emclient.o

fn C.emacs_quote_argument(...voidptr) cint
fn C.emacs_unquote_argument(...voidptr) cint
pub fn quote(v string) string {
	rv := []u8{len: v.len * 2 + 1}
	rc := C.emacs_quote_argument(v.str, rv.data)
	vcp.info(int(rc), v.len)
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

// todo proc can also be elisp symbol
pub fn runon_uithread_nowait(proc Funcur, args ...Anyer) {
	runon_uithread(proc, false, ...args)
}

// also means emacs main thread
pub fn runon_uithread(proc Funcur, nowait bool, args ...Anyer) {
	mypid := os.getpid() // sender
	c := unix.connect_stream('/run/user/1000/emacsv/server') or { panic(err) }
	defer { c.close() or { panic(err) } }

	cmd := 'print server-socket-dir'
	cmd = 'emacs-runon-uithread 12345678'
	cmd = 'emacs-runon-uithread ${mypid} ${usize(proc)} ${args.len}'
	for idx, arg in args {
		itfin := itface2struct(&arg)
		val := match arg {
			int, i32, usize, isize, i64, u64 {
				tv := derefvar[u64](itfin.ptr)
				'${tv}'
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
			else {
				'"${arg}"'
			}
		}
		cmd += ' ${val}'
	}
	// vcp.info(cmd)
	cmd = quote(cmd)
	n := c.write_string('-eval (${cmd})\n') or { panic(err) }
	// vcp.info(n, cmd, voidptr(proc))
	res := ''
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
	// parse result
	lines := res.split('\n')
	for idx, line in lines {
		if line.len == 0 {
			break
		}
		kv := line.split(' ')
		k, v := kv[0], unquote(kv[1])
		vcp.info('<<<', idx.str(), 'k', k, 'v', v)
	}
}

fn tt_runonth(e &Env, args []Value) Value {
	vcp.info('ehehe', e.asptr(), args.len, args.str())
	return emvs.eltrue
}

// defalis: emacs-runon-uithread
fn emacs_runon_uithread(e &Env, argc isize, args &Value, data voidptr) Value {
	arr := []Value{len: int(argc) - 3}
	for i := 3; i < argc; i++ {
		tv := args[i]
		// vcp.info(i.str(), tv.typof(e).strfy(e), tv.strfy(e))
		arr[i - 3] = tv
	}

	mypid := os.getpid()
	a0 := args[0].toint(e)
	a1 := voidptr(usize(args[1].toint(e)))
	if a0 != mypid {
		a1 = voidptr(tt_runonth)
	}
	fnv := Funcur(a1)
	// vcp.info('calling from/mypid', a0, mypid, argc, a1)
	rv := fnv(e, arr)
	// vcp.info('done', argc, a1)
	return e.strval('argc=${argc}, data=${data}, rv=${rv.strfy(e)}')
}
