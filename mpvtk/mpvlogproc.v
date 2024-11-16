
import vcp

import vcp.mpv

// because mpv thread conflict with gc

pub fn mpvlog_fwdproc() {
	gv := gvars
	logch := gv.logch
	savch := gv.savch

	for i:= 0; ; i ++ {
		select {
			evox := <- logch {
				// vcp.info("logch got", evox)
			}
			savsig := <- savch {
				// vcp.info("savch got", typeof(savsig).name)
				gv.plst.save()
			}
		}
		// evo := castptr[mpv.Event](evox)
		// vcp.info(evox)

		// evid := int(evo.event_id)
		// evname := C.mpv_event_name(evo.event_id)
		// vcp.info(i.str(), evid, tosbca(evname))
		// match evid {
		// use vbug works, const == var, but not var == const
// 		if mpv.EVENT_LOG_MESSAGE == evid {
// 			msgo := castptr[mpv.EventLogMessage](evo.data)
// 			vcp.info(i.str(), tosbca(msgo.prefix), tosbca(msgo.level), tosbca(msgo.text)
// )
// 		} else {

// 		}
		// if evo.data != vnil {
		// 	vcp.freerc(evo.data)
		// }
		// vcp.freerc(evox)
	}
}

fn check_mpvret(code int, what ... string) bool {
	if code != C.MPV_ERROR_SUCCESS {
		msg4c := C.mpv_error_string(code)
		vcp.info(code, tosbca(msg4c), what.str())
		return false
	}
	return true
}

fn C.GC_thread_is_registered() cint
fn mpv_wakeup_cbproc(ctx voidptr) {
	if true {mpv_wakeup_cb1(ctx)}
}
// 难道是这个函数处理太复杂,导致经常播放无响应??? 确实
// dont malloc memory useing gc
// only use C.printf
fn mpv_wakeup_cb1(ctx voidptr) {
	isgcth := C.GC_thread_is_registered() == 1 
	if !isgcth {
		// C.printf(c'thread not gc managed %d\n', vcp.gettid())
	}
	// vcp.gcreg_mythread()

	mpvo := gvars.mpvo
	for i:=0; i < 50000; i++ {
		evox := C.mpv_wait_event(mpvo, 0)
		evo := castptr[mpv.Event](evox)
		if evo.event_id == .NONE {
			break
		}
		// evox2 := cmemdup(evox, sizeof(mpv.Event))
		// evo2 := castptr[mpv.Event](evox2)
		// evo2.data = vnil

		evid := int(evo.event_id)
		evname := mpv.event_name0(cint(evo.event_id))
		// match evid {
		// use vbug works, const == var, but not var == const
		if mpv.EVENT_LOG_MESSAGE == evid {
			msgo := castptr[mpv.EventLogMessage](evo.data)
			// C.printf(c'mpv_wakeup_cb:77: %d %s: %s', i, evname, msgo.text)
			// evo2.data = cmemdup(evo.data, sizeof(mpv.EventLogMessage))	
			// vcp.freerc(ptr)
			// println('${@FILE_LINE}: ${tosbca(evname)}, ${tosbca(msgo.text)}')
			// x := '${@FILE_LINE}: ${tosbca(evname)}, ${tosbca(msgo.text)}'
		}
		else if mpv.EVENT_PROPERTY_CHANGE == evid {
			// C.printf(c'%s: %d, evid: %d, %s ...\n', (@FILE_LINE).str, i, evid, evname)
			C.infolm(i, evid, evname)
		}
		else {
			// C.printf(c'%s: %d, evid: %d, %s ...\n', (@FILE_LINE).str, i, evid, evname)
			C.infolm(i, evid, evname)
		}
		// }

		gvars.logch <- evox
	}
			
}
