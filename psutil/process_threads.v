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
    vms    u64 // 字段对齐 pypi pmem；不可用的平台为 none
    rss    u64
    shared u64
    text   ?u64
    lib    ?u64
    data   ?u64
    dirty  ?u64
}

pub fn (i MemoryInfo) str1() string {
    return 'MemoryInfo{rss: ${i.rss} vms: ${i.vms} shared: ${i.shared} text: ${i.text} lib: ${i.lib} data: ${i.data} dirty: ${i.dirty}}'
}

struct MemoryInfoRaw {
    vms     u64
    rss     u64
    shared  u64
    text    u64
    lib     u64
    data    u64
    dirty   u64
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
        vms: raw.vms
        rss: raw.rss
        shared: raw.shared
        text: opt_u64(raw.text)
        lib: opt_u64(raw.lib)
        data: opt_u64(raw.data)
        dirty: opt_u64(raw.dirty)
    }
}

pub fn process_memory(pid int) !MemoryInfo {
    return memory_info(pid)
}

pub fn my_process_memory() !MemoryInfo {
    return memory_info(os.getpid())
}
