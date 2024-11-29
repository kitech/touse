import vcp
import emacs

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

	eminit_uis(e)
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

//
// 这两个hook的函数参数有要求,
// 'window-scroll-functions', 'window-size-change-functions'
const hooks = ['after-change-major-mode-hook', 'after-init-hook', 'emacs-startup-hook',
	'buffer-list-update-hook', 'buffer-quit-function', 'focus-in-hook', 'focus-out-hook',
	'window-setup-hook', 'after-save-hook', 'before-save-hook', 'quit-window-hook', 'post-gc-hook',
	'window-configuration-change-hook', 'after-setting-font-hook', 'suspend-hook',
	'suspend-resume-hook']

fn eminit_hooks(e &emacs.Env) {
	for idx_, hook_ in hooks {
		idx := idx_
		e.add_hook(hook_, fn [idx] (e &emacs.Env) {
			hook := hooks[idx]
			vcp.info('111', idx.str(), hook, 'cllaed')
		})
	}
}

struct MainWin {
pub mut:
	left1 emacs.Value
	left2 emacs.Value
}

const emmw = &MainWin{}

fn eminit_uis(e &emacs.Env) {
	dw, dh := e.display_pixel_width(), e.display_pixel_height()
	w := e.window_pixel_width(vnil)
	h := e.window_pixel_height(vnil)
	vcp.info('size: ${w}x${h}, dsp: ${dw}x${dh}')

	// cannot resize a root window of a frame
	// e.window_resize(vnil, 200, true, true)

	frmwidth := dw * 8 / 9
	frmheight := dh * 5 / 6

	rgtwinwidth := frmwidth * 3 / 4
	topleftheight := frmheight * 3 / 5

	e.set_frame_width(vnil, frmwidth, true)

	w1 := e.split_window(vnil, rgtwinwidth, .left, true)
	refvar2mut(emmw).left1 = w1
	w2 := e.split_window(w1, topleftheight, .below, true)
	refvar2mut(emmw).left2 = w2
}

const elvars = ['last-nonmenu-event', 'default-directory', 'use-dialog-box', 'use-file-dialog',
	'window-system', 'tool-bar-mode', 'menu-bar-mode']

fn eminit_peekvars(e &emacs.Env) {
	for idx, vn in elvars {
		val := e.getvar(vn)
		str := val.strfy(e)
		vty := val.typof(e)
		vcp.info(idx.str(), vn.str(), vty.strfy(e), str)
	}
}
