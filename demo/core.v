// module main
import dl
import os
import time
import arrays
import rand
import vcp
import mkuse.emacs

// 不影响任何emacs第三方包的部分
pub fn emcore_init(e &emacs.Env) {
	emcore_set_hotkeys(e)
}

struct EmcoreVars {
pub mut:
	name string

	tsstk &TabswiStack = vnil
}

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

pub fn vemcore_swito_next_buffer(e &emacs.Env) {
	vcp.info(111)
	e.fcall2('switch-to-next-buffer')
}

pub fn vemcore_swito_prev_buffer(e &emacs.Env) {
	vcp.info(111)
	e.fcall2('switch-to-prev-buffer')
}

fn run_pre_command_hook(e &emacs.Env) {
	vcp.info(111)
	lastcmd := e.getvar('last-command-event')
	lastipt := e.getvar('last-input-event')
	iptpend := e.fcall2('input-pending-p')
	evmdfr := e.fcall2('event-modifiers', lastipt)
	vcp.info(lastcmd.strfy(e), lastipt.strfy(e), iptpend.isnil(e), evmdfr.strfy(e))
}

fn run_post_command_hook(e &emacs.Env) {
	vcp.info(111)

	lastcmd := e.getvar('last-command-event')
	lastipt := e.getvar('last-input-event')
	iptpend := e.fcall2('input-pending-p')
	evmdfr := e.fcall2('event-modifiers', lastipt)
	vcp.info(lastcmd.strfy(e), lastipt.strfy(e), iptpend.isnil(e), evmdfr.strfy(e))
}
