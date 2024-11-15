
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
