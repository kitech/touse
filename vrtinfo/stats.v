@[has_globals]
module vrtinfo

import os
import time
import touse.psutil
import vcp
import vcp.json
import vcp.yco

#include <gc/gc.h>

fn C.GC_get_gc_no() int
fn C.GC_get_parallel() int
fn C.GC_get_free_space_divisor() usize
fn C.GC_set_free_space_divisor(usize)
fn C.GC_get_full_freq() int
fn C.GC_set_full_freq(int)
fn C.GC_is_disabled() int
fn C.GC_disable()
fn C.GC_enable()
fn C.GC_get_non_gc_bytes() usize
fn C.GC_set_non_gc_bytes(usize)
fn C.GC_gcollect()
fn C.GC_gcollect_and_unmap()
fn C.GC_should_invoke_finalizers() int
fn C.GC_invoke_finalizers() int
fn C.GC_dump()

fn C.crn_get_stats(&yco.InnerStats)

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

fn json_opt_u64(name string, v u64) string {
	if v == 0 {
		return '"${name}":null'
	}
	return '"${name}":${v}'
}

fn json_opt_str(name string, v string) string {
	if v == '' {
		return '"${name}":null'
	}
	return '"${name}":${jstr(v)}'
}

pub fn ping_data() string {
	return jobj(
		'"pong":true',
		'"name":${jstr(g_service_name)}',
		'"pid":${os.getpid()}',
		'"uptime_ms":${uptime_ms()}',
	)
}

pub fn caps_data(extra []string) string {
	mut cmds := []string{}
	for c in command_names {
		cmds << jstr(c)
	}
	for c in extra {
		cmds << jstr(c)
	}
	mut wcmds := []string{}
	for c in write_commands {
		wcmds << jstr(c)
	}
	return jobj(
		'"v":${version}',
		'"cmds":[${cmds.join(',')}]',
		'"write_cmds":[${wcmds.join(',')}]',
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
		'"free_space_divisor":${C.GC_get_free_space_divisor()}',
		'"full_freq":${C.GC_get_full_freq()}',
		'"is_disabled":${C.GC_is_disabled()}',
		'"non_gc_bytes":${C.GC_get_non_gc_bytes()}',
		'"inuse":${st.inuse}',
		'"free_bytes":${st.free_bytes}',
		'"unmapped":${st.objcnt}',
		'"total_bytes":${st.cgocall}',
		'"bytes_since_gc":${st.x}',
		'"obtained_from_os":${st.alloc}',
		'"gc_parallel":${C.GC_get_parallel()}',
		'"cur_thread_registered":${yn(vcp.gcthread_isreg())}',
	)
}

// 所有 gc.set_* 共用的参数解析：args 形如 {"value":N}。
fn gc_arg_i64(args string) !i64 {
	jo := json.parse(args)!
	defer { jo.freeit() }
	if !jo.isObject() {
		return error('args must be an object')
	}
	n := jo.key('value')
	if n == nil || !n.isNumber() {
		return error('value must be a number')
	}
	f := n.tonum()
	if f != f64(i64(f)) {
		return error('value must be an integer')
	}
	return i64(f)
}

// 运行期调整 BDWGC free_space_divisor；value 必须是 [1,100] 的整数。
pub fn gc_set_free_space_divisor_data(args string) !string {
	v := gc_arg_i64(args)!
	if v < 1 || v > 100 {
		return error('value out of range [1,100]')
	}
	old := int(C.GC_get_free_space_divisor())
	C.GC_set_free_space_divisor(usize(v))
	return jobj(
		'"old":${old}',
		'"free_space_divisor":${int(C.GC_get_free_space_divisor())}',
	)
}

// 只在 incremental/generational 模式真正影响行为；默认 20。
pub fn gc_set_full_freq_data(args string) !string {
	v := gc_arg_i64(args)!
	if v < 1 || v > 1000 {
		return error('value out of range [1,1000]')
	}
	old := C.GC_get_full_freq()
	C.GC_set_full_freq(int(v))
	return jobj(
		'"old":${old}',
		'"full_freq":${C.GC_get_full_freq()}',
	)
}

// 1 = GC_disable（连 GC_gcollect 都无效）；0 = GC_enable。
// 只建议调试时短暂使用，记得恢复 0。
pub fn gc_set_is_disabled_data(args string) !string {
	v := gc_arg_i64(args)!
	if v != 0 && v != 1 {
		return error('value must be 0 or 1')
	}
	old := C.GC_is_disabled()
	if v == 1 {
		C.GC_disable()
	} else {
		C.GC_enable()
	}
	return jobj(
		'"old":${old}',
		'"is_disabled":${C.GC_is_disabled()}',
	)
}

// 影响 collection 的调度记账；范围 0..1TiB。
pub fn gc_set_non_gc_bytes_data(args string) !string {
	v := gc_arg_i64(args)!
	if v < 0 || v > (i64(1) << 40) {
		return error('value out of range [0,1099511627776]')
	}
	old := i64(C.GC_get_non_gc_bytes())
	C.GC_set_non_gc_bytes(usize(v))
	return jobj(
		'"old":${old}',
		'"non_gc_bytes":${i64(C.GC_get_non_gc_bytes())}',
	)
}

// 手动触发 full GC + finalizer，用 gc.stats 前后对比判断
// “不可达但未 finalize/未回收”的对象（例如 curl body）占了多少。
pub fn gc_collect_data() string {
	before := vcp.get_bdwgc_stats()
	pending0 := C.GC_should_invoke_finalizers()
	C.GC_gcollect()
	mut nfin := C.GC_invoke_finalizers()
	C.GC_gcollect()
	nfin += C.GC_invoke_finalizers()
	C.GC_gcollect_and_unmap()
	pending1 := C.GC_should_invoke_finalizers()
	after := vcp.get_bdwgc_stats()
	return jobj(
		'"pending_before":${pending0}',
		'"finalized":${nfin}',
		'"pending_after":${pending1}',
		'"heap_before":${before.inuse}',
		'"heap_after":${after.inuse}',
		'"free_before":${before.free_bytes}',
		'"free_after":${after.free_bytes}',
		'"obtained_before":${before.alloc}',
		'"obtained_after":${after.alloc}',
	)
}

// 把 BDWGC 的堆/对象信息 dump 到进程 stderr（通常就是 demo 的终端）。
pub fn gc_dump_data() string {
	C.GC_dump()
	return jobj('"done":true')
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
	mut st := yco.InnerStats{}
	C.crn_get_stats(&st)
	assert st.version == yco.struct_version
	return jobj(
		'"machine_total":${st.mch_totcnt}',
		'"machine_active":${st.mch_actcnt}',
		'"fiber_total":${st.fiber_totcnt}',
		'"fiber_active":${st.fiber_actcnt}',
		'"fiber_total_mem":${st.fiber_totmem}',
		'"fiber_dtorcnt":${st.fiber_dtorcnt}',
		'"max_stack_size":${st.maxstksz}',
	)
}

fn fiber_state_name(state int) string {
	return match state {
		0 { 'nostack' }
		1 { 'runnable' }
		2 { 'executing' }
		3 { 'waiting' }
		4 { 'finished' }
		else { '${state}' }
	}
}

pub fn fibers_data() !string {
	$if emucobypth? {
		return error('fibers command is not supported in this build')
	}
	list := yco.get_fibers()
	mut items := []string{cap: list.len}
	for f in list {
		items << jobj(
			'"id":${f.id}',
			'"mcid":${f.mcid}',
			'"state":${jstr(fiber_state_name(f.state))}',
			'"pkreason":${f.pkreason}',
			'"stksz":${f.stksz}',
			'"used_stksz":${f.used_stksz}',
		)
	}
	return jobj(
		'"count":${list.len}',
		'"fibers":[${items.join(',')}]',
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
		// 累计 CPU 时间（user+system，毫秒）
		fields << '"cpu_ms":${u64((t.user_time + t.system_time) * 1000.0 + 0.5)}'
		fields << json_opt_u64('stksz', t.stack_size)
		fields << json_opt_u64('used_stksz', t.stack_used)
		fields << json_opt_u64('pc', t.pc)
		fields << json_opt_str('wchan', t.wchan)
		fields << json_opt_str('syscall', t.syscall)
		fields << json_opt_str('func', t.func)
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
