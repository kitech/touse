module psutil

// 缺失 .o 时 V 会自动编译相邻的 threadlist.c
#flag -I @DIR/
#flag @DIR/threadlist.o
#include "@DIR/threadlist.h"

@[typedef]
pub struct C.psutil_ThreadInfo {
	id          u64
	tid         u64
	name        [64]char
	state       [8]char
	is_current  int
	user_time   f64
	system_time f64
	stack_size  u64
	stack_used  u64
	pc          u64
	wchan       [32]char
	syscall     [32]char
	func        [96]char
}

fn C.psutil_list_threads(&C.psutil_ThreadInfo, int, &int) int
fn C.psutil_list_threads_pid(int, &C.psutil_ThreadInfo, int, &int) int

const max_thread_list = 256

pub struct ThreadInfo {
pub:
	id          u64 // pypi 兼容 id
	tid         u64
	name        string
	state       string
	is_current  bool
	user_time   f64
	system_time f64
	stack_size  u64
	stack_used  u64
	pc          u64
	wchan       string
	syscall     string
	func        string
}

pub struct ThreadList {
pub:
	items     []ThreadInfo
	truncated bool
}

// thread_list 列出当前进程所有 OS 线程；调用方所在线程标记 is_current=true。
// 不支持的平台返回 error。
pub fn thread_list() ![]ThreadInfo {
	res := thread_list_ex() or { return err }
	return res.items
}

// thread_list_ex 额外返回 truncated，标记超过 256 上限的静默截断。
pub fn thread_list_ex() !ThreadList {
	mut raw := []C.psutil_ThreadInfo{len: max_thread_list}
	mut truncated := 0
	n := unsafe { C.psutil_list_threads(&raw[0], max_thread_list, &truncated) }
	if n < 0 {
		return error('thread list is not supported on this platform')
	}
	mut list := []ThreadInfo{cap: n}
	for i in 0 .. n {
		list << ThreadInfo{
			id:          raw[i].id
			tid:         raw[i].tid
			name:        unsafe { cstring_to_vstring(&raw[i].name[0]) }
			state:       unsafe { cstring_to_vstring(&raw[i].state[0]) }
			is_current:  raw[i].is_current != 0
			user_time:   raw[i].user_time
			system_time: raw[i].system_time
			stack_size:  raw[i].stack_size
			stack_used:  raw[i].stack_used
			pc:          raw[i].pc
			wchan:       unsafe { cstring_to_vstring(&raw[i].wchan[0]) }
			syscall:     unsafe { cstring_to_vstring(&raw[i].syscall[0]) }
			func:        unsafe { cstring_to_vstring(&raw[i].func[0]) }
		}
	}
	return ThreadList{
		items: list
		truncated: truncated != 0
	}
}

// process_threads 对齐 pypi Process.threads()，按 pid 列出线程。
pub fn process_threads(pid int) ![]ThreadInfo {
	mut raw := []C.psutil_ThreadInfo{len: max_thread_list}
	mut truncated := 0
	n := unsafe { C.psutil_list_threads_pid(pid, &raw[0], max_thread_list, &truncated) }
	if n < 0 { return map_proc_err(pid, n, 'threads') }
	mut list := []ThreadInfo{cap: n}
	for i in 0 .. n {
		list << ThreadInfo{
			id: raw[i].id
			tid: raw[i].tid
			name: unsafe { cstring_to_vstring(&raw[i].name[0]) }
			state: unsafe { cstring_to_vstring(&raw[i].state[0]) }
			is_current: raw[i].is_current != 0
			user_time: raw[i].user_time
			system_time: raw[i].system_time
			stack_size: raw[i].stack_size
			stack_used: raw[i].stack_used
			pc: raw[i].pc
			wchan: unsafe { cstring_to_vstring(&raw[i].wchan[0]) }
			syscall: unsafe { cstring_to_vstring(&raw[i].syscall[0]) }
			func: unsafe { cstring_to_vstring(&raw[i].func[0]) }
		}
	}
	return list
}
