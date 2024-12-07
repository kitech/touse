// module main
import dl
import os
import sync
import time
import arrays
import rand
import vcp
import mkuse.emacs
import mkuse.xlibv

// 不影响任何emacs第三方包的部分
pub fn emcore_init(e &emacs.Env) {
	emcore_set_hotkeys(e)
	frm := e.getframe(vnil)
	rv := frm.frame_parameter(e, 'window-id')
	rv2 := frm.frame_parameter(e, 'outer-window-id')
	vcp.info(rv.strfy(e), rv2.strfy(e))
	ref2mut(emcvs).emwinid = rv.strfy(e)
	ref2mut(emcvs).emoutwinid = rv2.strfy(e)

	go vemcore_x11proc()
}

const emcvs = &EmcoreVars{}
const tsstk = &TabswiStack{}

struct EmcoreVars {
pub mut:
	x11proconce sync.Once
	name        string

	emwinid    string
	emoutwinid string

	metaheld  u32
	shiftheld u32

	// swito state
	ctrlheld       u32
	onectrl_runcnt u32

	tsstk &TabswiStack = vnil
}

// emulate firefox's tabswitch logic
pub struct TabswiStack {
pub mut:
	tabs []string
	m    map[string]int
}

pub fn (me &TabswiStack) add(v string) {
	stk := me
	if _ := stk.m[v] {
		return
	}
	stk.tabs << v
}

pub fn emcore_set_hotkeys(e &emacs.Env) {
	nextname := 'vemacs/switch-to-next-buffer'
	prevname := 'vemacs/switch-to-prev-buffer'
	e.defcmd(nextname, vemcore_swito_next_buffer, '')
	e.defcmd(prevname, vemcore_swito_prev_buffer, '')

	// default 'switch-to-next-buffer
	e.global_set_key('<C-tab>', nextname)
	// defualt 'switch-to-prev-buffer
	e.global_set_key('C-S-<iso-lefttab>', prevname)
}

fn vemcore_swito_next_buffer(e &emacs.Env) {
	// vcp.info(111)
	// e.fcall2('switch-to-next-buffer')

	// but ctrlheld always true when here called
	ctrlheld := vcp.atomic_load(&emcvs.ctrlheld) == 1
	runcnt := vcp.atomic_load(&emcvs.onectrl_runcnt)
	// vcp.info(111, ctrlheld, runcnt)
	eltv := e.fcall2('current-idle-time')
	// vcp.info(eltv.strfy(e)) // nil most time nil here

	// 0.07s-0.2s
	dlyfn := 'run-with-idle-timer'
	// dlyfn = 'run-with-timer'
	e.fcall2(dlyfn, e.realval(0.095), emacs.elnil(), e.funvalx(vemcore_swito_next_buffer_s2))

	// state machine
	// if ctrl still hold,
	// if first, then popmenu/float tab select window
	// if not first, popmenu switch next
	//
	// if ctrl not hold, just to next in stack
}

fn vemcore_swito_next_buffer_s2(e &emacs.Env) {
	vemcore_swito_buffer_s3(e, false)
}

fn vemcore_swito_buffer_s3(e &emacs.Env, prev bool) {
	ctrlheld := vcp.atomic_load(&emcvs.ctrlheld) == 1
	runcnt := vcp.atomic_load(&emcvs.onectrl_runcnt)
	vcp.info(111, 'prev', prev, 'ctrlheld', ctrlheld, 'runcnt', runcnt)

	vemcore_swito_list_buffers(e)
	if tsstk.tabs.len == 0 {
		vcp.info('tablst zeror')
		return
	}

	if ctrlheld { // popmenu and select mode
		// todo
		if runcnt == 0 {
		} else {
		}
		// default
		if prev {
			e.fcall2('switch-to-prev-buffer')
		} else {
			e.fcall2('switch-to-next-buffer')
		}
	} else { // quick swap mode
		item := tsstk.popone(prev, true)
		buf := e.get_buffer_create(item) // must exists
		e.switch_to_buffer(buf)
	}
}

fn vemcore_swito_prev_buffer(e &emacs.Env) {
	// vcp.info(111)
	// e.fcall2('switch-to-prev-buffer')

	// 0.07s-0.2s
	dlyfn := 'run-with-idle-timer'
	// dlyfn = 'run-with-timer'
	e.fcall2(dlyfn, e.realval(0.095), emacs.elnil(), e.funvalx(vemcore_swito_prev_buffer_s2))
}

fn vemcore_swito_prev_buffer_s2(e &emacs.Env) {
	vemcore_swito_buffer_s3(e, true)
}

/// quick is stack swap, not next/prev
fn (me &TabswiStack) popone(prev bool, quick bool) string {
	im := me
	if quick {
		// 0=>last
		first := im.tabs[0]
		last := im.tabs[im.tabs.len - 1]
		im.tabs[0] = last
		im.tabs[im.tabs.len - 1] = first
		return last
	} else {
		if !prev {
			// 0=>last
			item := im.tabs[0]
			im.tabs.delete(0)
			im.tabs << item
			return item
		} else {
			// last => 0
			item := im.tabs[im.tabs.len - 1]
			for i := im.tabs.len - 1; i > 0; i-- {
				im.tabs[i] = im.tabs[i - 1]
			}
			im.tabs[0] = item
			return item
		}
	}
}

const vemcore_tabswi_filtered_bufs = {
	' *Minibuf-0*':        1
	' *server*':           1
	' *tab-line-hscroll*': 1
	' *Echo Area 0*':      1
	' *Echo Area 1*':      1
}

fn (me &TabswiStack) append(bufname string) {
	im := me
	if _ := vemcore_tabswi_filtered_bufs[bufname] {
	} else {
		im.tabs << bufname
	}
}

// 初始化化顺序,从当前buff做为最后一个,当前buff之前的排列到最前
// buf0, buf1, buf2(cur), buf3, buf4 =>
// buf3, buf4, buf0, buf1, buf2(cur)
fn vemcore_swito_list_buffers(e &emacs.Env) {
	if tsstk.tabs.len > 0 {
		return
	}
	curbuf := e.orbuffer(emacs.elnil())
	curbuf_name := curbuf.buffer_name(e)
	buflst := e.buffer_list()
	curbuf_idx := -1
	for idx, buf in buflst {
		if curbuf_idx < 0 {
			if buf.buffer_name(e) == curbuf_name {
				curbuf_idx = idx
			}
		} else {
			tsstk.append(buf.buffer_name(e))
		}
	}
	for idx, buf in buflst {
		if idx < curbuf_idx {
			tsstk.append(buf.buffer_name(e))
		} else {
			break
		}
	}
	ref2mut(tsstk).tabs << curbuf_name
	vcp.info(tsstk.tabs.len, tsstk.tabs.str())
}

fn vemcore_swito_ctrlcap(press bool) {
	if press {
		bv := vcp.atomic_cmpswap(&emcvs.ctrlheld, 0, 1)
		vcp.falseprt(bv, 'state mass', emcvs.ctrlheld)
	} else {
		bv := vcp.atomic_cmpswap(&emcvs.ctrlheld, 1, 0)
		vcp.falseprt(bv, 'state mass', emcvs.ctrlheld)
		vcp.atomic_store(&emcvs.onectrl_runcnt, 0)
	}
}

fn run_pre_command_hook(e &emacs.Env) {
	if true {
		return
	}
	vcp.info(111)
	lastcmd := e.getvar('last-command-event')
	lastipt := e.getvar('last-input-event')
	iptpend := e.fcall2('input-pending-p')
	evmdfr := e.fcall2('event-modifiers', lastipt)
	vcp.info(lastcmd.strfy(e), lastipt.strfy(e), iptpend.isnil(e), evmdfr.strfy(e))
}

fn run_post_command_hook(e &emacs.Env) {
	if true {
		return
	}
	vcp.info(111)

	lastcmd := e.getvar('last-command-event')
	lastipt := e.getvar('last-input-event')
	iptpend := e.fcall2('input-pending-p')
	evmdfr := e.fcall2('event-modifiers', lastipt)
	vcp.info(lastcmd.strfy(e), lastipt.strfy(e), iptpend.isnil(e), evmdfr.strfy(e))
}

// sometime hang seconds
fn vemcore_x11proc() {
	xlo := xlibv.new()
	x := xlo
	x.open()

	xlibv.setup_globhook(x.dsp)

	ctrl_lkc := xlibv.keysym2code(x.dsp, C.XK_Control_L)
	ctrl_rkc := xlibv.keysym2code(x.dsp, C.XK_Control_R)
	meta_lkc := xlibv.keysym2code(x.dsp, C.XK_Meta_L)
	meta_rkc := xlibv.keysym2code(x.dsp, C.XK_Meta_R)

	vcp.info(x.dsp.str())
	evtstk := xlibv.XEvent{}
	for i := 0; true; i++ {
		evt := &evtstk
		// println('has evt $n')
		C.XNextEvent(x.dsp, voidptr(evt))
		ke := castptr[xlibv.XDeviceKeyEvent](evt)
		// vcp.info(usize(ke.window), usize(ke.subwindow), xlibv.xdev_is_key_press(int(ke.type)),
		// xlibv.xdev_is_key_release(int(ke.type)), xlibv.str2keycode(x.dsp, 'CTRL_L'),
		// xlibv.keysym2code(x.dsp, C.XK_Control_L))
		if ke.keycode == ctrl_lkc || ke.keycode == ctrl_rkc {
			act := 'unknown'
			if xlibv.xdev_is_key_press(int(ke.type)) {
				vemcore_swito_ctrlcap(true)
				act = 'press'
			} else if xlibv.xdev_is_key_release(int(ke.type)) {
				vemcore_swito_ctrlcap(false)
				act = 'release'
			} else {
				assert false
			}
			vcp.info('got', act, int(ke.keycode), int(ke.window), int(ke.subwindow), voidptr(ke.subwindow),
				emcvs.emwinid, emcvs.emoutwinid)
		}
	}
}
