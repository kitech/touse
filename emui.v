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
	if true {
		wins := e.fcall2('window-list')
		vcp.info(wins.strfy(e))
	}
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

pub fn (e &Env) display_pixel_height() int {
	rv := e.fcall2(funame2el(@FN))
	return int(rv.toint(e))
}

pub fn (e &Env) display_pixel_width() int {
	rv := e.fcall2(funame2el(@FN))
	return int(rv.toint(e))
}
