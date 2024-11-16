module tcltk

import vcp


pub struct Inputdia {
	Tkobject
}

pub fn Inputdia.run() string {
	cmds := 'set foo "This is some text."
	set foo ""
toplevel .t
pack [label .t.l0 -text "Input Url:"]
pack [entry .t.e -textvariable foo]
pack [button .t.b -text "OK" -command {destroy .t}]
pack [button .t.b2 -text "Cancel" -command {set foo ""; destroy .t}]
bind .t <Return> {.t.b invoke}
bind .t <Escape> {.t.b2 invoke}
focus .t.e

tkwait window .t
'
// puts "The variable contains \'\$foo\'"

	rv := call(cmds)
	val := getvar(gvars.tclirp, "foo")
	// vcp.info(val)
	unsetvar(gvars.tclirp, "foo")
	return val
}

pub fn choose_files() []string {
	cmd := 'tk_getOpenFile -multiple 1'
	res := call2(cmd) or {panic(err)}
	// vcp.info(res)
	arr0 := split_tcl_strlist(res)
	return arr0
}

// 有空格的会用 {} 包括,没有空格的不包括
pub fn split_tcl_strlist(res string) []string{
	arr0 := res.split(' ')
	lcidx := res.index_u8(`{`)
	if lcidx >= 0 { // fixsome
		arr2 := []string{}
		incurly := false
		buf := ''

		for c in res.runes() {
			if c == `{` {
				incurly = true
				continue
			}
			if c == `}` {
				arr2 << buf
				buf = ''
				continue
			}

			if c == ` ` {
				if !incurly {
					arr2 << buf
					buf = ''
					continue
				}
			}
			buf += c.str()
		}
		if buf.len > 0 { arr2 << buf }

		assert arr2.len>0 && arr2.len <= arr0.len
		// vcp.info('len', arr0.len, '=>', arr2.len)
		arr0 = arr2.clone()
	}
	return arr0
}
// 有空格的会用 {} 包括,没有空格的不包括
@[depcreated: 'has bug']
pub fn split_tcl_strlist2(res string) []string{
	arr0 := res.split(' ')
	lcidx := res.index_u8(`{`)
	if lcidx >= 0 { // fixsome
		arr2 := []string{}
		incurly := false
		buf := []string{}
		for e in arr0 {
			if !incurly {
				if !e.contains('{') {
					arr2 << e
				}else{
					buf << e[1..]
					incurly = true
				}
			} else {
				if e.contains('}') {
					buf << e[..e.len-1]
					incurly = false
					arr2 << buf.join(' ')
					buf.clear()
				}else{
					buf << e
				}
			}
		}
		vcp.info('len', arr0.len, '=>', arr2.len)
		arr0 = arr2.clone()
	}
	return arr0
}