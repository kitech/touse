module main

import dl
import os
import time
import rand
import vcp
import mkuse.emacs
import mkuse.joplin

fn main() {
	vcp.info(int(emacs.MAJOR_VERION))
}

fn init() {
	emacs.reginiter(emuser_init)
}

fn emuser_init(e &emacs.Env) {
	vcp.info(e != vnil)

	eminit_hooks(e)
	eminit_shotkeys(e)
	eminit_peekvars(e)
	eminit_setvars(e)

	eminit_uis(e)

	vcp.info('done')
}

const shotkeys = {
	'C-o': 'veopen-file-dialog'
	'C-,': 'vehello'
}

fn eminit_shotkeys(e &emacs.Env) {
	for k, v in shotkeys {
		cgm := e.fcall2('current-global-map')
		km := e.fcall2('keymap-lookup', cgm, e.strval(k))
		if !km.isnil(e) {
			vcp.info('keymap exist', k.str(), km.strfy(e), '=>', v.str())
		}
		e.global_set_key(k, v)
	}
}

// 查找所有符号, M-x apropos RET hook
// mapatoms
// 这两个hook的函数参数有要求,
// 'window-scroll-functions', 'window-size-change-functions'
const hooks = ['after-change-major-mode-hook', 'after-init-hook', 'emacs-startup-hook',
	'buffer-list-update-hook', 'buffer-quit-function', 'focus-in-hook', 'focus-out-hook',
	'window-setup-hook', 'after-save-hook', 'before-save-hook', 'quit-window-hook', 'post-gc-hook',
	'window-configuration-change-hook', 'after-setting-font-hook', 'suspend-hook',
	'suspend-resume-hook', 'minibuffer-setup-hook', 'minibuffer-with-setup-hook']

fn eminit_hooks(e &emacs.Env) {
	for idx_, hook_ in hooks {
		idx := idx_
		e.add_hook(hook_, fn [idx] (e &emacs.Env) {
			hook := hooks[idx]
			name4v := '${@MOD}__run_' + emacs.nameofel(hook, false)
			sym4v := vcp.dlsym0(name4v)
			// vcp.info('111', idx.str(), hook, 'called', name4v, sym4v)
			if sym4v != vnil {
				fno := funcof(sym4v, fn (_ &emacs.Env) {})
				fno(e)
			}
		})
	}
	vcp.info('added hooks:', hooks.len)
}

struct MainWin {
pub mut:
	left1 emacs.Value
	left2 emacs.Value

	// dont save emacs.Value unless it global
	// cannot use that value in other callback
	btnbar_name string
	dirwin_name string
	symwin_name string
	msgwin_name string
	bigwin_name string

	minibufwin emacs.Value

	popwin_pkginst_name string
}

struct EnvContext {
pub mut:
	btnbar emacs.Value
	dirwin emacs.Value
	symwin emacs.Value
	msgwin emacs.Value
	bigwin emacs.Value

	popwin_pkginst emacs.Value
}

const emmw = &MainWin{}

fn eminit_uis(e &emacs.Env) {
}

fn emui_waitcond(e &emacs.Env, maxtry int, condfn fn () bool) bool {
	btime := time.now()
	for i := 0; i < maxtry; i++ {
		cdok := condfn()
		if !cdok {
			if rand.int() % 2 == 1 {
				e.fcall2('redisplay')
			} else {
				e.fcall2('sit-for', e.realval(0.01))
			}
		} else {
			if i > 0 {
				vcp.info('sit-for ', i.str(), time.since(btime).str())
			}
			return true
		}
	}
	vcp.info('resize not done, wait???', maxtry, time.since(btime).str())
	return false
}

/*
window layout
----------------------
|w1|   |    w0      |
|  |w4 |            |
|  | - |------------|
|  |w2 |    w3      |
*/

// call at some later time, eg. after window fully inited
fn eminit_resize_mainwin_ifneed(e &emacs.Env) {
	dw, dh := e.display_pixel_width(), e.display_pixel_height()
	w := e.window_pixel_width(vnil)
	h := e.window_pixel_height(vnil)
	vcp.info('size: ${w}x${h}, dsp: ${dw}x${dh}')
	w0 := e.getwin(vnil)

	// cannot resize a root window of a frame
	// e.window_resize(vnil, 200, true, true)

	frmwidth := dw * 8 / 9
	frmheight := dh * 5 / 6

	rgtwinwidth := frmwidth * 3 / 4
	topleftheight := frmheight * 3 / 5

	// vcp.info(rgtwinwidth, topleftheight)
	// some times, split too small error???
	minw := e.window_min_size(vnil, true, true)
	// vcp.info(minw)

	e.set_frame_width(vnil, frmwidth, true)

	emui_waitcond(e, 99, fn [e, rgtwinwidth] () bool {
		cwwidth := e.window_pixel_width(vnil)
		return cwwidth >= rgtwinwidth
	})
	cwwidth := e.window_pixel_width(vnil)

	w1 := e.split_window(vnil, rgtwinwidth, .left, true)
	if w1.isnil(e) {
		vcp.info(111, w1.isnil(e), minw, cwwidth, rgtwinwidth)
		e.chkret()
		return
	}
	refvar2mut(emmw).left1 = w1

	w4 := e.split_window(w1, 80, .right, true)
	if w1.isnil(e) {
		vcp.info(111, w1.isnil(e), minw, cwwidth, rgtwinwidth)
		e.chkret()
		return
	}
	// refvar2mut(emmw).left2 = w2

	w2 := e.split_window(w4, topleftheight, .below, true)
	if w1.isnil(e) {
		vcp.info(111, w1.isnil(e), minw, cwwidth, rgtwinwidth)
		e.chkret()
		return
	}
	refvar2mut(emmw).left2 = w2

	w3 := e.split_window(w0, 480, .below, true)
	if w3.isnil(e) {
		vcp.info(111, w1.isnil(e), minw, cwwidth, rgtwinwidth)
		e.chkret()
		return
	}
	refvar2mut(emmw).minibufwin = w3

	wins := e.window_list()
	for idx, wx in wins {
		vcp.info(wx.window_name(e), w0.window_name(e))
		e.select_window(wx)
		if e.eq(wx, w0) {
		} else if e.eq(wx, w1) {
			// e.switch_to_buffer2('*Messages*')
		} else if e.eq(wx, w2) {
			e.switch_to_buffer2('*Messages*')
		} else if e.eq(wx, w3) {
			e.switch_to_buffer2('*Messages*')
		}
	}
	e.select_window(w0)
	w1.set_window_parameter(e, 'tab-line-format', e.intern('none'))
	w3.set_window_parameter(e, 'tab-line-format', e.intern('none'))
	w4.set_window_parameter(e, 'tab-line-format', e.intern('none'))
	w2.set_window_parameter(e, 'tab-line-format', e.intern('none'))
	// w1.set_window_parameter(e, 'mode-line-format', e.intern('none'))
	// w2.set_window_parameter(e, 'mode-line-format', e.intern('none'))
	w1.set_window_parameter(e, 'header-line-format', e.intern('none'))
	w2.set_window_parameter(e, 'header-line-format', e.intern('none'))
	w1.set_window_parameter(e, 'no-delete-other-windows', emacs.bool2el(true))
	w2.set_window_parameter(e, 'no-delete-other-windows', emacs.bool2el(true))
	w3.set_window_parameter(e, 'no-delete-other-windows', emacs.bool2el(true))
	w4.set_window_parameter(e, 'no-delete-other-windows', emacs.bool2el(true))

	// 为什么在这个循环里设置就不管用???
	buflst := e.buffer_list()
	for b in buflst {
		name := b.buffer_name(e)
		vcp.info(name)
		match name {
			// seems not work
			'*scratch*' {
				// e.select_window(w0)
				// e.switch_to_buffer(b)
				// e.set_buffer2(name)
			}
			'*Messages*' {
				// e.select_window(w2)
				// e.switch_to_buffer(b)
				// e.set_buffer2(name)
			}
			'aaa' {}
			else {
				// e.select_window(w0)
				// e.switch_to_buffer(b)
				// e.set_buffer2(name)
			}
		}
	}

	e.select_window(w4)
	e.fcall2('dired', e.strval(os.getwd()))
	// e.fcall2('dired', e.strval(vcp.path_expend('~/aprog')))
	e.fcall2('set-window-dedicated-p', w4, e.intern('t'))
	e.chkret()
	e.fcall2('set-window-dedicated-p', w2, e.intern('t'))
	e.chkret()
	e.fcall2('set-window-dedicated-p', w3, e.intern('t'))
	e.chkret()

	///
	ref2mut(emmw).bigwin_name = w0.window_name(e)
	ref2mut(emmw).msgwin_name = w3.window_name(e)
	ref2mut(emmw).symwin_name = w2.window_name(e)
	ref2mut(emmw).dirwin_name = w4.window_name(e)
	ref2mut(emmw).btnbar_name = w1.window_name(e)
}

fn EnvContext.new(e &emacs.Env) &EnvContext {
	ctx := &EnvContext{}

	frms := e.frame_list()
	vcp.info('frms', frms.len, frms.str())
	for i, frm in frms {
		// vcp.info(i.str(), frm.strfy(e))

		wins := e.window_list(frm)
		// vcp.info('wins', wins.len, wins.str())
		for j, win in wins {
			// vcp.info(j.str(), win.strfy(e), win.window_name(e))
			wname := win.window_name(e)
			wstr := win.strfy(e)

			match wname {
				emmw.dirwin_name {
					ctx.dirwin = win
				}
				emmw.btnbar_name {
					ctx.btnbar = win
				}
				emmw.msgwin_name {
					ctx.msgwin = win
				}
				emmw.symwin_name {
					ctx.symwin = win
				}
				emmw.bigwin_name {
					ctx.bigwin = win
				}
				else {}
			}
		}
	}

	return ctx
}

fn create_btnwin_content(e &emacs.Env, ctx &EnvContext) {
	btnbar := ctx.btnbar // emmw.btnbar

	e.select_window(btnbar)
	eb1 := e.get_buffer_create('test222')
	e.switch_to_buffer(eb1)
	e.getwin(vnil).set_window_dedicated_p(e, true)

	eb1.insert(e, 'App\n')

	if true {
		btn := e.insert_button('Instpkg')
		eb1.insert(e, '\n\n')
		// vcp.info(btn.typof(e).strfy(e))
		fn1 := fn (e &emacs.Env) {
			vcp.info('btn clicked')
		}
		fnv1 := e.funval(fn1)
		btn.button_put(e, 'mouse-action', fnv1)
	}

	for i in 0 .. 12 {
		btn := e.insert_button('btn${i}')
		eb1.insert(e, '\n\n')
		// vcp.info(btn.typof(e).strfy(e))
		fn1 := fn (e &emacs.Env) {
			vcp.info('btn clicked')
		}
		fnv1 := e.funval(fn1)
		btn.button_put(e, 'mouse-action', fnv1)
	}

	w1 := btnbar
	e.fcall2('set-window-dedicated-p', w1, e.intern('t'))
	e.chkret()
}

fn create_flowt_minibuf(e &emacs.Env, ctx &EnvContext) {
	w3 := ctx.msgwin // emmw.msgwin

	// some about minibuffer
	oldmbwin := e.minibuffer_window()
	vcp.info(oldmbwin.strfy(e), w3.strfy(e))
	if false {
		e.select_window(w3)
		e.switch_to_buffer2('*Minibuf-0*')
		w3.set_window_parameter(e, 'minibuffer', e.intern('only'))
		w3.set_window_parameter(e, 'mini', emacs.bool2el(true))
		// e.set_minibuffer_window(w3)
		// if e.nle_check() != .return_ {
		//  vcp.error('somerr')
		//  return
		// }
	}
	if false { // use c create minibuffer frame
		cfunc1 := vcp.dlsym0('make_minibuffer_frame')
		cfno1 := funcof(cfunc1, fn () voidptr {
			return vnil
		})
		minifrm := cfno1()
		vcp.info(minifrm)
	}
	if false { // try create float minibuffer
		mbfrm := e.make_minbuf_frame(vnil)
		vcp.info(mbfrm.strfy(e))
		e.set_frame_size(mbfrm, 600, 100, true)
		e.set_frame_position(mbfrm, 700, 600)
	}
	if true {
		oldmbfrm := oldmbwin.window_frame(e)
		dftfrm := e.getframe(vnil)
		vcp.info('dftfrm/mbfrm', e.eq(dftfrm, oldmbfrm), dftfrm.strfy(e), oldmbfrm.strfy(e))
	}
}

fn create_float_window(e &emacs.Env, ctx &EnvContext) {
	topfrm := e.getframe(vnil)
	frm := e.make_child_frame(topfrm)
	vcp.info(frm.strfy(e))
	// frm.set_frame_parameter(e, 'parent-frame', topfrm)
	// frm.set_frame_parameter(e, 'menu-bar-lines', e.intval(0))
	// frm.set_frame_parameter(e, 'menu-bar-mode', emacs.bool2el(false))
	// frm.set_frame_parameter(e, 'auto-lower', emacs.bool2el(false))
	// // frm.set_frame_parameter(e, 'minibuffer', emacs.bool2el(false))
	// frm.set_frame_parameter(e, 'tool-bar-lines', e.intval(0))

	// frm.set_frame_parameter(e, 'user-position', emacs.bool2el(true))
	// frm.set_frame_parameter(e, 'left', e.intval(100))
	// frm.set_frame_parameter(e, 'top', e.intval(100))
	e.set_frame_size(frm, 500, 300, true)
	// e.set_frame_position(frm, 200, 150)
	e.set_frame_position(frm, 900, 50)

	// 创建第二个的时候有点问题呢?
	if false {
		frm2 := e.make_child_frame(topfrm)
		e.set_frame_size(frm, 400, 300, true)
		e.set_frame_position(frm, 600, 150)
	}

	// save some
	mw := emmw
	ctx.popwin_pkginst = frm
}

fn create_fixed_buffers(e &emacs.Env, ctx &EnvContext) {
	mw := emmw
	frm := ctx.popwin_pkginst
	frm.raise_frame(e)
	frm.select_frame(e)
	frm.select_frame_set_input_focus(e)

	eb1 := e.get_buffer_create('test111')
	e.switch_to_buffer(eb1)
	e.getwin(vnil).set_window_dedicated_p(e, true)

	eb1.insert(e, 'hehehhehee\n')
	for i in 0 .. 6 {
		btn := e.insert_button('insbtn${i}')
		eb1.insert(e, '\n')
		// vcp.info(btn.typof(e).strfy(e))
		fn1 := fn (e &emacs.Env) {
			vcp.info('btn clicked')
		}
		fnv1 := e.funval(fn1)
		btn.button_put(e, 'mouse-action', fnv1)
	}
}

// command-line-1: Symbol’s value as variable is void: global-tab-bar-mode
// 'global-tab-bar-mode'
const elvars = ['last-nonmenu-event', 'default-directory', 'use-dialog-box', 'use-file-dialog',
	'window-system', 'tool-bar-mode', 'menu-bar-mode', 'global-tab-bar-mode', 'global-tab-line-mode',
	'command-error-function', 'debug-on-message']

fn eminit_peekvars(e &emacs.Env) {
	for idx, vn in elvars {
		val := e.getvar(vn)
		str := val.strfy(e)
		vty := val.typof(e)
		vcp.info(idx.str(), vn.str(), vty.strfy(e), str)
	}
}

fn eminit_setvars(e &emacs.Env) {
	e.fcall2('add-to-list', e.intern('write-file-functions'), e.funvalx(write_file_func1))
	// this is local variable, set here not work
	// e.fcall2('add-to-list', e.intern('write-contents-functions'), e.funvalx(write_contents_func1))
}

fn run_minibuffer_setup_hook(e &emacs.Env) {
	vcp.info('...')
}

fn run_minibuffer_with_setup_hook(e &emacs.Env) {
	vcp.info('...')
}

/// hooks
fn run_window_setup_hook(e &emacs.Env) {
	vcp.info('...')
	e.chkret()
	eminit_resize_mainwin_ifneed(e)
	ctx := EnvContext.new(e)

	create_btnwin_content(e, ctx)
	create_float_window(e, ctx)
	create_flowt_minibuf(e, ctx)
	create_fixed_buffers(e, ctx)

	vcp.dodelay(1 * time.second / 1, load_notes, 123)
	if false {
		vcp.dotick(17 * time.second / 1, emacs_tick, 123)
	}
}

fn run_window_configuration_change_hook(e &emacs.Env) {
	//  vcp.info('...')
	// tv := e.intval(123)
	// e.nle_clear_indeep()
	// tv.tostr(e)
	// e.chkret()

	tcons := e.cons2(1, 1.2, '3.4')
	vcp.info(tcons.strfy(e))

	vcp.info(999)
}

const md2jpldirs = ['~/mdnote', '~/Sync']
const md2jplexts = ['.md', '.markdown', '.txt']

fn run_after_save_hook(e &emacs.Env) {
	bfile := e.buffer_file_name(vnil)
	vcp.info('savewt', bfile)

	run_md2jpl(bfile)
}

fn run_before_save_hook(e &emacs.Env) {
	vcp.info(111)
	e.fcall2('add-to-list', e.intern('write-contents-functions'), e.funvalx(write_contents_func1))
	// bfile := e.buffer_file_name(vnil)
	// vcp.info('savewt', bfile)

	// run_md2jpl(bfile)
}

fn md2jpl_match(bfile string) (string, bool) {
	dir := ''
	extok := false
	for ext in md2jplexts {
		if bfile.ends_with(ext) {
			extok = true
			break
		}
	}
	for d in md2jpldirs {
		d2 := vcp.path_expend(d)
		if bfile.starts_with(d2) {
			dir = d2
			break
		}
	}
	return dir, extok
}

fn run_md2jpl(bfile string) {
	dir, extok := md2jpl_match(bfile)
	if dir == '' || !extok {
		return
	}
	vcp.info('mated', bfile)
}

fn emacs_tick(x int) {
	vcp.info('hhhhh', x)
	emacs.runon_uithread('prin1-to-string', false, 123)
}

// used for visited file
fn write_file_func1(e &emacs.Env, args []emacs.Value) emacs.Value {
	vcp.info(111)
	// bfile := e.buffer_file_name(vnil)
	// vcp.info('savewt', bfile)
	return emacs.elnil()
}

// used for visited/non-visited file
fn write_contents_func1(e &emacs.Env, args []emacs.Value) emacs.Value {
	vcp.info(111)
	ebuf := e.orbuffer(emacs.elnil())
	ebname := ebuf.buffer_name(e)
	bfile := e.buffer_file_name(vnil)
	vcp.info('savewt', bfile, ebuf.strfy(e), ebname)

	if ebname.starts_with('Note ') {
		sendto_msgbuf(e, 'Saved ${ebname}')
		return emacs.eltrue()
	}

	return emacs.elnil()
}

fn sendto_msgbuf(e &emacs.Env, msg string) {
	ebuf := e.get_buffer_create('*Message')
	e.fcall2('message', e.strval(msg))
}

///

fn load_notes(x int) {
	vcp.info('hhhhh', x)
	emacs.runon_uithread('prin1-to-string', false, 123)
	jlo := joplin.Jldata.new()
	jlo.set_token(os.getenv('JLTOKEN'))
	notes := jlo.notes() or { vcp.error(err.str()) }
	arradr := voidptr(&notes)

	emacs.runon_uithread(load_notes_done, true, arradr)
	// vcp.dodelay(9 * time.second, voidptr(fn (_ voidptr) {}), arradr)
	vcp.dorefer(9 * time.second, arradr)
	vcp.info('caller', arradr)
}

fn newjlapi() &joplin.Jldata {
	jlo := joplin.Jldata.new()
	jlo.set_token(os.getenv('JLTOKEN'))
	return jlo
}

//  unlock []T slice's addr and pass by pointer and deref !!!

fn load_notes_done(e &emacs.Env, args []emacs.Value) emacs.Value {
	vcp.info('hehehhe', args.len)
	// &[]joplin.Jlnote
	notesptr := emacs.ofptrstr(args[0].tostr(e))
	vcp.info(notesptr, sizeof(joplin.Jlnote))

	arr2 := derefvar[[]joplin.Jlnote](notesptr)
	vcp.info('deref[[]T]', notesptr, arr2.len, arr2.str())

	// edit emacs buffer now
	dirwin := find_emwin(e, emmw.dirwin_name)
	genbuf_notes(e, arr2)

	bufs := e.buffer_list()
	vcp.info('bufs', bufs.len, bufs.str())
	for i, buf in bufs {
		vcp.info(i.str(), buf.strfy(e))
	}

	return emacs.elnil()
}

fn genbuf_notes(e &emacs.Env, notes []joplin.Jlnote) {
	dirwin := find_emwin(e, emmw.dirwin_name)
	frm := dirwin.window_frame(e)

	frm.raise_frame(e)
	frm.select_frame(e)
	frm.select_frame_set_input_focus(e)
	e.select_window(dirwin)

	eb1 := e.get_buffer_create('Notelist')
	// eb1 = dirwin.window_buffer(e)
	dirwin.set_window_dedicated_p(e, false)
	e.switch_to_buffer(eb1)
	dirwin.set_window_dedicated_p(e, true)

	eb1.insert(e, 'Notelist, ${notes.len}\n')
	for idx, note in notes {
		btn := e.insert_button('${idx} ${note.title}')
		eb1.insert(e, '\n')
		// vcp.info(btn.typof(e).strfy(e))
		note2 := &notes[idx]
		fn1 := fn [note2] (e &emacs.Env) {
			vcp.info('btn clicked', note2.id, note2.title)
			// onclick_note_title(e, note2)
			vcp.dotask(onclick_note_title, voidptr(note2))
		}
		fnv1 := e.funval(fn1)
		btn.button_put(e, 'mouse-action', fnv1)
	}
}

fn onclick_note_title(note &joplin.Jlnote) {
	vcp.info(note.id, note.title)
	jlo := newjlapi()
	note2 := jlo.note(note.id) or { vcp.error(err.str()) }
	note3 := voidptr(&note2)
	emacs.runon_uithread(emwin_show_note, false, note3)
}

fn emwin_show_note(e &emacs.Env, args []emacs.Value) emacs.Value {
	argptr := emacs.ofptrstr(args[0].tostr(e))
	note := castptr[joplin.Jlnote](argptr)
	vcp.info(note.str())

	ctx := EnvContext.new(e)
	bigwin := ctx.bigwin
	frm := bigwin.window_frame(e)

	frm.raise_frame(e)
	frm.select_frame(e)
	frm.select_frame_set_input_focus(e)
	e.select_window(bigwin)

	// 这种创建的buffer叫,not visiting file
	bufname := 'Note ${note.id}'
	eb1 := e.get_buffer_create(bufname)
	// eb1 = dirwin.window_buffer(e)
	// dirwin.set_window_dedicated_p(e, false)
	e.switch_to_buffer(eb1) // why tab not show?
	e.fcall2('tab-line-mode', e.intval(1)) // works
	// e.fcall2('buffer-offer-save', emacs.elnil())
	// e.fcall2('pop-to-buffer', eb1)
	// e.fcall2('set-buffer', eb1)
	// e.fcall2('display-buffer-in-tab', eb1, emacs.elnil()) // this is tab-bar, not tab-line
	// e.fcall2('switch-to-buffer-other-tab', eb1)
	// dirwin.set_window_dedicated_p(e, true)

	e.fcall2('erase-buffer')
	// eb1.insert(e, 'Notelist, ${notes.len}\n')
	eb1.insert(e, note.body)

	// digest buffer
	eb2 := e.get_buffer_create('jldigest')

	return emacs.elnil()
}

fn find_emwin(e &emacs.Env, name string) emacs.Value {
	frms := e.frame_list()
	vcp.info('frms', frms.len, frms.str())
	for i, frm in frms {
		vcp.info(i.str(), frm.strfy(e))

		wins := e.window_list(frm)
		vcp.info('wins', wins.len, wins.str())
		for j, win in wins {
			vcp.info(j.str(), win.strfy(e), win.window_name(e))
			wname := win.window_name(e)
			wstr := win.strfy(e)
			if wname == name {
				return win
			}
		}
	}
	return emacs.elnil()
}
