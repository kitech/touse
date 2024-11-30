module emacs

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

pub fn (e &Env) set_frame_size(frm Value, w int, h int, inpixel bool) {
}

pub fn (e &Env) set_frame_width(frm Value, w int, inpixel bool) {
	frm2 := e.getframe(frm)
	rv := e.fcall2(funame2el(@FN), frm2, e.intval(w), emvs.elnil, bool2el(inpixel))
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
