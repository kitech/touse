module psutil

import os

// prompt, 使用C99编写跨平台获取当前指定进程线程数的函数
#flag @DIR/process_threads.o
// 使用C99编写跨平台获取当前指定进程线内存使用量的函数，函数名加前缀 psutil__
#flag @DIR/process_memory.o

@[importc: "psutil_get_process_thread_count"]
pub fn threads_count(pid int) int

pub fn my_threads_count() int {
    return threads_count(os.getpid())
}

pub struct MemoryInfo {
    pub:
    vms    u64 // rss/vms/shared 使用 pypi psutil 字段名；顺序保持 C ABI
    rss    u64
    shared u64
}

pub fn (i MemoryInfo) str1() string {
    return 'MemoryInfo{rss: ${i.rss} vms: ${i.vms} shared: ${i.shared}}'
}

struct MemoryInfoRaw {
    vms     u64
    rss     u64
    shared  u64
    pid     int
    errcode int
    errmsg  [256]char
}

fn C.psutil_get_process_memory_2(int, &MemoryInfoRaw)

// memory_info 对齐 pypi Process.memory_info()。
pub fn memory_info(pid int) !MemoryInfo {
    mut raw := MemoryInfoRaw{}
    C.psutil_get_process_memory_2(pid, &raw)
    if raw.errcode != 0 {
        msg := unsafe { cstring_to_vstring(&raw.errmsg[0]) }
        return error(msg)
    }
    return MemoryInfo{
        vms:    raw.vms
        rss:    raw.rss
        shared: raw.shared
    }
}

pub fn process_memory(pid int) !MemoryInfo {
    return memory_info(pid)
}

pub fn my_process_memory() !MemoryInfo {
    return memory_info(os.getpid())
}
