// module main

import os
import sync.stdatomic

import vcp
import vcp.mpv

///

pub struct Bkdstate {
	pub mut:
	cmdno u64 = 100
}

pub fn mvpsetopts(opts []string) {
	h := gvars.mpvo
	rv := 0
	// opts << "wid"; opts << gvars.wid
	// opts << "x11-bypass-compositor"; opts << "no"
	// opts << "input-default-bindings"; opts << "no"
	// opts << "input-vo-keyboard"; opts << "no"
	// opts << "load-scripts" << "no"
	// opts << "player-operation-mode"; opts << "pseudo-gui"
	// opts << "vo"; opts << "gpu" // "gpu,libmpv,x11,xv"
	for i:=0; i < opts.len; i+= 2{
		rv = C.mpv_set_option_string(h, opts[i].str, opts[i+1].str)
		vcp.info(i.str(), rv, opts[i], opts[i+1])
		check_mpvret(rv, opts[i], opts[i+1])
	}	
}

///
// 播放创建,播放完free
pub struct Bkdlibmpv {
	pub mut:
	mpvo voidptr
}

pub fn mpvchk_create_handle() {
	if gvars.mpvo != vnil { return }

	// todo 有时无图像,但有声音,
	// 播放正常,可能是无法正确嵌入tcltk窗口
	// 尝试一种可能的解决方案,用xlib创建窗口,看能不能放到tcltk的layout中
	// keep-open-pause=no and keep-open=yes fix this!!!
	gv := gvars
	opts := ["wid", gv.wid, "vo", "gpu", "idle", "yes", "keep-open-pause", "no", "keep-open", "yes"]
	opts << "log-file"; opts << "mpvtk.log"
	// opts << "playlist"; opts << "mpvtk.playlist" // why404
	// opts << "show-progress"; opts << "yes" // why404
	// opts << "x11-bypass-compositor"; opts << "no"
	// opts << "input-default-bindings"; opts << "no"
	// opts << "input-vo-keyboard"; opts << "no"
	// opts << "load-scripts" << "no"
	// opts << "player-operation-mode"; opts << "pseudo-gui"
	assert gv.wid.starts_with('0x')
	
	mut rv := 0
	h := C.mpv_create()
	gv.mpvo = h
	assert h!=vnil

	name4c := C.mpv_client_name(h)
	vcp.info("New mpv handler", h, tosbca(name4c))

	mvpsetopts(opts)
	C.mpv_request_event(h, C.MPV_EVENT_LOG_MESSAGE, 1)
	C.mpv_request_log_messages(h, c'info')
	C.mpv_set_wakeup_callback(h, mpv_wakeup_cbproc, voidptr(42))

	rv = C.mpv_initialize(h)
	check_mpvret(rv)
}

pub fn play_file(file string) {
	gv := gvars
	mut rv := 0

	mpvchk_create_handle()
	h := gv.mpvo

	if true {
		rv = mpv.command_async(h, 12345, "loadfile", file) //, "append-play")
		check_mpvret(rv)

	gv.plst.add(file)
	gv.savch <- 1
		return
	}

	cmdargs := [charptr('loadfile'.str), charptr(file.str), vnil]
	cmdargs.firstz()
	vcp.info(cmdargs.len, cmdargs.str(), file)
	rv = C.mpv_command_async(h, 12345, cmdargs.clone().data)
	check_mpvret(rv)
}

pub fn play_pause_or_resume() {
	// "cycle", "pause"
	rv := mpv.command_async(gvars.mpvo, 12345, "cycle", "pause")
	check_mpvret(rv)
}

pub fn play_pause() {
	if true { play_pause_or_resume(); return }
	rv := mpv.set_property(gvars.mpvo, "pause", true)
	check_mpvret(rv)	
}

pub fn play_resume() {
	if true { play_pause_or_resume(); return }
	rv := mpv.set_property(gvars.mpvo, "pause", false)
	check_mpvret(rv)	
}

///
pub struct Bkdcmdmpv {

}


///
const playlist_file = "mpvtk.playlist"

// todo use .m3u8 format
pub struct Playlist {
	pub mut:
	list []string
	moded bool = false
}

pub fn (me &Playlist) load() bool {
	if !os.exists(playlist_file) {
	}else{
		lines := os.read_lines(playlist_file) or {
			vcp.error(err.str()); return false }
		me.list = lines
	}
	return true
}

pub fn (me &Playlist) save() bool {
	scc := me.list.join('\n')
	if scc != "" {
		os.write_file(playlist_file, scc) or { vcp.error(err.str(), playlist_file) }
		me.moded = false
	}
	return true
}

pub fn (me &Playlist) add(file string) bool {
	if me.list.contains(file) { return false}
	if !os.exists(file) { return false }
	if me.list.len > 32 {}

	me.list << file
	me.moded = true
	return true
}
