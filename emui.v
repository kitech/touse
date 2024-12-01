module emacs

import rand
import vcp

//  tab-bar (frame tabs) or tab-line (buffer tabs).

pub fn (e &Env) window_system() string {
	//
	return ''
}

pub fn (e &Env) display_graphic_p() bool {
	return false
}

pub enum Winside {
	above
	below
	left
	right
}

pub fn bool2el(v bool) Value {
	return if v { emvs.eltrue } else { emvs.elnil }
}

// w nil for selected-window
// size in cols/rows, not pixels
// size about 20-120
pub fn (e &Env) split_window(w Value, size int, side Winside, inpixel bool) Value {
	sideval := e.intern(side.str())
	curwin := e.getwin(w)
	pxl := bool2el(inpixel)
	rv := e.fcall2(funame2el(@FN), curwin, e.intval(size), sideval, pxl)
	return rv
}

pub fn (e &Env) window_resize(w Value, delta int, hori bool, inpixel bool) {
	w2 := e.getwin(w)
	rv := e.fcall2(funame2el(@FN), w2, e.intval(delta), bool2el(hori), bool2el(inpixel))
}

pub fn (e &Env) select_window(w Value) {
	rv := e.fcall2(funame2el(@FN), w)
}

pub fn (e &Env) window_list() []Value {
	wins := e.fcall2('window-list') // cons
	// vcp.info(wins.strfy(e), wins.typof(e).strfy(e))
	rv := e.cons2arr(wins)
	return rv
}

// fmt: #<window 3 on *scratch*>
pub fn (e &Env) window_name(w Value) string {
	return w.window_name(e)
}

pub fn (w Value) window_name(e &Env) string {
	s := w.strfy(e)
	s = s.all_before(' on').replace('<', '')
	return s
}

pub fn (w Value) set_window_parameter(e &Env, prm string, val Value) {
	e.fcall2(funame2el(@FN), w, e.intern(prm), val)
}

pub fn (w Value) set_frame_parameter(e &Env, prm string, val Value) {
	e.fcall2(funame2el(@FN), w, e.intern(prm), val)
	// e.fcall2(funame2el(@FN), w, e.strval(prm), val)
}

pub fn (w Value) set_window_dedicated_p(e &Env, val bool) {
	e.fcall2(funame2el(@FN), w, bool2el(val))
}

pub fn (e &Env) set_frame_size(frm Value, w int, h int, inpixel bool) {
	if w > 0 {
		e.set_frame_width(frm, w, inpixel)
	}
	if h > 0 {
		e.set_frame_height(frm, h, inpixel)
	}
}

pub fn (e &Env) set_frame_width(frm Value, w int, inpixel bool) {
	frm2 := e.getframe(frm)
	rv := e.fcall2(funame2el(@FN), frm2, e.intval(w), emvs.elnil, bool2el(inpixel))
}

pub fn (e &Env) set_frame_height(frm Value, w int, inpixel bool) {
	frm2 := e.getframe(frm)
	rv := e.fcall2(funame2el(@FN), frm2, e.intval(w), emvs.elnil, bool2el(inpixel))
}

pub fn (e &Env) set_frame_position(frm Value, x int, y int) {
	rv := e.fcall2(funame2el(@FN), frm, e.intval(x), e.intval(y))
}

pub fn (e &Env) getwin(w Value) Value {
	rv := w
	if rv.isnil(e) {
		rv = e.fcall2('selected-window')
	}
	return rv
}

pub fn (e &Env) getframe(frm Value) Value {
	rv := frm
	if rv.isnil(e) {
		rv = e.fcall2('selected-frame')
	}
	return rv
}

pub fn (e &Env) orbuffer(buf Value) Value {
	rv := buf
	if rv.isnil(e) {
		rv = e.fcall2('current-buffer')
	}
	return rv
}

pub fn (e &Env) window_total_height(w Value) int {
	rv := e.fcall2(funame2el(@FN), e.getwin(w))
	// vcp.info(rv.typof(e).strfy(e), rv.strfy(e))
	return int(rv.toint(e))
}

pub fn (e &Env) window_total_width(w Value) int {
	rv := e.fcall2(funame2el(@FN), e.getwin(w))
	// vcp.info(rv.typof(e).strfy(e), rv.strfy(e))
	return int(rv.toint(e))
}

pub fn (e &Env) window_pixel_height(w Value) int {
	rv := e.fcall2(funame2el(@FN), e.getwin(w))
	// vcp.info(rv.typof(e).strfy(e), rv.strfy(e))
	return int(rv.toint(e))
}

pub fn (e &Env) window_pixel_width(w Value) int {
	rv := e.fcall2(funame2el(@FN), e.getwin(w))
	// vcp.info(rv.typof(e).strfy(e), rv.strfy(e))
	return int(rv.toint(e))
}

pub fn (e &Env) window_min_size(w Value, hori bool, inpixel bool) int {
	rv := e.fcall2(funame2el(@FN), e.getwin(w), bool2el(hori), bool2el(inpixel))
	return int(rv.toint(e))
}

pub fn (e &Env) display_pixel_height() int {
	rv := e.fcall2(funame2el(@FN))
	return int(rv.toint(e))
}

pub fn (e &Env) display_pixel_width() int {
	rv := e.fcall2(funame2el(@FN))
	return int(rv.toint(e))
}

pub fn (e &Env) get_buffer(name string) Value {
	rv := e.fcall2(funame2el(@FN), e.strval(name))
	return rv
}

pub fn (e &Env) buffer_name(v Value) string {
	rv := e.fcall2(funame2el(@FN), v)
	return rv.tostr(e)
}

pub fn (v Value) buffer_name(e &Env) string {
	return e.buffer_name(v)
}

pub fn (e &Env) buffer_list() []Value {
	rv := e.fcall2(funame2el(@FN)) // cons
	arr := e.cons2arr(rv)
	for idx, val in arr {
		// vcp.info(idx.str(), val.typof(e).strfy(e), val.strfy(e), val.buffer_name(e))
	}
	return arr
}

pub fn (e &Env) switch_to_buffer(b Value) {
	rv := e.fcall2(funame2el(@FN), b)
	e.chkret()
}

pub fn (e &Env) switch_to_buffer2(b string) {
	rv := e.fcall2('switch-to-buffer', e.strval(b))
	e.chkret()
}

pub fn (e &Env) set_buffer(b Value) {
	rv := e.fcall2(funame2el(@FN), b)
	e.chkret()
}

pub fn (e &Env) set_buffer2(b string) {
	rv := e.fcall2('set-buffer', e.strval(b))
	e.chkret()
}

pub fn (e &Env) mini_buffer_window() Value {
	return e.fcall2(funame2el(@FN))
}

// set-minibuffer-window window
// float window
// Emacs里有两种实现方式，一种基于overlay，缺点是遇到Unicode或者不等宽的字符会出问题，不过支持Terminal。另一种是基于Emacs26加入的childframe机制，可以完美显示，不过不支持TUI（不过终端下的显示元素都比较单一）。

// 给当前的buff文字加链接
pub fn (e &Env) make_button(bp int, ep int) Value {
	return e.fcall2(funame2el(@FN), e.intval(bp), e.intval(ep))
}

// 这个button更像链接,怎么更像button呢
pub fn (e &Env) insert_button(label string) Value {
	rv := e.fcall2(funame2el(@FN), e.strval(label))
	assert rv.typof(e).strfy(e) == 'overlay' // it overlay?
	return rv
}

// it really set property
pub fn (v Value) button_put(e &Env, prop string, val Value) {
	rv := e.fcall2(funame2el(@FN), v, e.intern(prop), val)
}

pub fn (e &Env) make_frame() Value {
	return e.fcall2(funame2el(@FN))
}

pub fn (e &Env) make_child_frame(p Value) Value {
	// frame paramter keys
	// minibuffer . nil
	// parent-frame . p

	kvs2 := map[string]Anyer{}
	kvs2['minibuffer'] = false
	kvs2['parent-frame'] = p

	kvs := map[string]Value{}
	kvs['minibuffer'] = emvs.elnil
	kvs['parent-frame'] = p
	kvs['width'] = e.intval(300)
	kvs['menu-bar-lines'] = e.intval(0)
	kvs['tool-bar-lines'] = e.intval(0)
	kvs['menu-bar-mode'] = bool2el(false) // noeffect
	kvs['tool-bar-mode'] = bool2el(false) // noeffect
	kvs['tab-line-mode'] = bool2el(false) // noeffect
	kvs['auto-lower'] = bool2el(true)
	kvs['auto-raise'] = bool2el(true)
	kvs['visibility'] = bool2el(true)
	kvs['undecorated'] = bool2el(true)
	kvs['inhibit-double-buffering'] = bool2el(true)
	kvs['z-group'] = e.intern('above')
	kvs['name'] = e.strval('emff0x${voidptr(e)}')
	kvs['title'] = e.strval('emtitle0x${voidptr(e)}')
	kvs['unsplittable'] = emvs.eltrue
	kvs['drag-internal-border'] = emvs.eltrue
	kvs['drag-with-header-line'] = emvs.eltrue
	kvs['drag-with-mode-line'] = emvs.eltrue

	// auto conv
	for k, v in kvs {
		// vcp.info(v.strfy(e))
		tv := e.fromel(v)
		// vcp.info(tv)
		kvs2[k] = tv
	}

	alst0 := e.alist(kvs)
	alst2 := e.alist2(kvs2)
	// alst := if rand.int() % 2 == 1 { alst0 } else { alst2 }
	alst := ifelse(rand.int() % 2 == 1, alst0, alst2)

	// alst := emvs.elnil
	// item0 := e.fcall2('cons', e.intern('minibuffer'), emvs.elnil)
	// item1 := e.fcall2('cons', e.intern('parent-frame'), p)
	// item2 := e.fcall2('cons', e.intern('width'), e.intval(300))
	// alst = e.fcall2('list', item0, item1, item2)

	rv := e.fcall2('make-frame', alst)
	return rv
}

pub fn (v Value) select_frame(e &Env) {
	rv := e.fcall2(funame2el(@FN), v)
}

pub fn (v Value) select_frame_set_input_focus(e &Env) {
	rv := e.fcall2(funame2el(@FN), v)
}

pub fn (v Value) raise_frame(e &Env) {
	rv := e.fcall2(funame2el(@FN), v)
}

pub fn (v Value) lower_frame(e &Env) {
	rv := e.fcall2(funame2el(@FN), v)
}

pub fn (e &Env) get_buffer_create(name string) Value {
	rv := e.fcall2(funame2el(@FN), e.strval(name))
	return rv
}

pub fn (e &Env) kill_buffer(b Value) {
	rv := e.fcall2(funame2el(@FN), b)
}

pub fn (v Value) buffer_string(e &Env) string {
	rv := e.fcall2(funame2el(@FN), v)
	return rv.tostr(e)
}

pub fn (b Value) buffer_move(e &Env, pos int) {
}

pub fn (b Value) insert(e &Env, val string) {
	rv := e.fcall2(funame2el(@FN), e.strval(val))
}

pub fn (b Value) point(e &Env) int {
	rv := e.fcall2(funame2el(@FN), b)
	return int(rv.toint(e))
}
