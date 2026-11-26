@[has_globals]
module vrtinfo

import os
import time
import touse.psutil
import vcp
import vcp.yco

#include <gc/gc.h>

fn C.GC_get_gc_no() int
fn C.GC_get_parallel() int

struct CrnInnerStats {
	mch_totcnt   int
	mch_actcnt   int
	fiber_totcnt int
	fiber_actcnt int
	fiber_totmem int
	maxstksz     int
}

fn C.crn_get_stats(&CrnInnerStats)

__global g_service_name = ''

pub fn set_service_name(name string) {
	g_service_name = name
}

fn uptime_ms() i64 {
	return time.now().unix_milli() - vcp.starttime.unix_milli()
}

fn yn(b bool) string {
	return if b { 'true' } else { 'false' }
}

pub fn ping_data() string {
	return jobj(
		'"pong":true',
		'"name":${jstr(g_service_name)}',
		'"pid":${os.getpid()}',
		'"uptime_ms":${uptime_ms()}',
	)
}

pub fn caps_data() string {
	mut cmds := []string{}
	for c in command_names {
		cmds << jstr(c)
	}
	return jobj(
		'"v":${version}',
		'"cmds":[${cmds.join(',')}]',
		'"max_req":${max_request}',
		'"max_resp":${max_response}',
	)
}

pub fn info_data() string {
	mut args := []string{}
	for a in os.args {
		args << jstr(a)
	}
	return jobj(
		'"pid":${os.getpid()}',
		'"name":${jstr(g_service_name)}',
		'"exe":${jstr(os.executable())}',
		'"args":[${args.join(',')}]',
		'"start_unix_ms":${vcp.starttime.unix_milli()}',
		'"uptime_ms":${uptime_ms()}',
		'"os":${jstr(vcp.vc_os())}',
		'"arch":${jstr(vcp.vc_arch())}',
		'"cc":${jstr(vcp.vc_cc())}',
		'"v_version":${jstr(vcp.vc_verstr())}',
		'"v_hash":${jstr(vcp.vc_verhash())}',
		'"tid":${vcp.gettid()}',
		'"thread":${jstr(vcp.get_currth_name())}',
	)
}

// GogcStat 中 objcnt/cgocall/x 分别复用为 unmapped/total_bytes/bytes_since_gc
pub fn gc_data() string {
	st := vcp.get_bdwgc_stats()
	return jobj(
		'"gc_no":${C.GC_get_gc_no()}',
		'"inuse":${st.inuse}',
		'"unmapped":${st.objcnt}',
		'"total_bytes":${st.cgocall}',
		'"bytes_since_gc":${st.x}',
		'"obtained_from_os":${st.alloc}',
		'"gc_parallel":${C.GC_get_parallel()}',
		'"cur_thread_registered":${yn(vcp.gcthread_isreg())}',
	)
}

pub fn coro_data() string {
	base, sz := yco.go_stackaddr_cur()
	return jobj(
		'"goid":${yco.goid()}',
		'"stack_base_u64":${u64(base)}',
		'"stack_size":${sz}',
		'"gc_thread_registered":${yn(vcp.gcthread_isreg())}',
	)
}

pub fn coro_list_data() string {
	mut st := CrnInnerStats{}
	C.crn_get_stats(&st)
	return jobj(
		'"machine_total":${st.mch_totcnt}',
		'"machine_active":${st.mch_actcnt}',
		'"fiber_total":${st.fiber_totcnt}',
		'"fiber_active":${st.fiber_actcnt}',
		'"fiber_total_mem":${st.fiber_totmem}',
		'"max_stack_size":${st.maxstksz}',
	)
}

pub fn threads_data() !string {
	list := psutil.thread_list() or {
		return error('cannot enumerate threads')
	}
	mut items := []string{cap: list.len}
	for t in list {
		mut fields := [
			'"tid":${t.tid}',
			'"name":${jstr(t.name)}',
			'"state":${jstr(t.state)}',
			'"is_current":${yn(t.is_current)}',
		]
		if t.is_current {
			fields << '"goid":${yco.goid()}'
			fields << '"gc_registered":${yn(vcp.gcthread_isreg())}'
		}
		items << '{${fields.join(',')}}'
	}
	return jobj(
		'"gc_parallel":${C.GC_get_parallel()}',
		'"count":${list.len}',
		'"threads":[${items.join(',')}]',
	)
}

pub fn mem_data() !string {
	$if linux {
		txt := os.read_file('/proc/self/status') or {
			return error('cannot read /proc/self/status')
		}
		mut rss := i64(-1)
		mut size := i64(-1)
		for line in txt.split('\n') {
			if line.starts_with('VmRSS:') {
				rss = line.all_after('VmRSS:').trim_space().all_before('kB').trim_space().i64() * 1024
			}
			if line.starts_with('VmSize:') {
				size = line.all_after('VmSize:').trim_space().all_before('kB').trim_space().i64() * 1024
			}
		}
		return jobj('"rss_bytes":${rss}', '"vm_size_bytes":${size}')
	} $else {
		return error('mem command is only supported on linux')
	}
}
