module psutil

// 缺失 .o 时 V 会自动编译相邻的 threadlist.c
#flag -I @DIR/
#flag @DIR/threadlist.o
#include "@DIR/threadlist.h"

@[typedef]
pub struct C.psutil_ThreadInfo {
	tid        u64
	name       [32]char
	state      [8]char
	is_current int
}

fn C.psutil_list_threads(&C.psutil_ThreadInfo, int) int

const max_thread_list = 256

pub struct ThreadInfo {
pub:
	tid        u64
	name       string
	state      string
	is_current bool
}

// thread_list 列出当前进程所有 OS 线程；调用方所在线程标记 is_current=true。
// 不支持的平台返回 error。
pub fn thread_list() ![]ThreadInfo {
	mut raw := []C.psutil_ThreadInfo{len: max_thread_list}
	n := unsafe { C.psutil_list_threads(&raw[0], max_thread_list) }
	if n < 0 {
		return error('thread list is not supported on this platform')
	}
	mut list := []ThreadInfo{cap: n}
	for i in 0 .. n {
		list << ThreadInfo{
			tid:        raw[i].tid
			name:       unsafe { cstring_to_vstring(&raw[i].name[0]) }
			state:      unsafe { cstring_to_vstring(&raw[i].state[0]) }
			is_current: raw[i].is_current != 0
		}
	}
	return list
}
