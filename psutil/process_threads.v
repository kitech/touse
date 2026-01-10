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
    virt u64 // )unsigned long long virtual_memory;   // 虚拟内存大小 (字节)
    res  u64 // unsigned long long resident_memory;  // 常驻内存大小 (字节)
    shrd u64 // unsigned long long shared_memory;    // 共享内存大小 (字节) (Linux only)
    pid  int // int pid;                             // 进程ID
    errcode int // int error_code;                      // 错误代码
    errmsg [256]i8 // char error_msg[256];                 // 错误信息
}

// @[importc: "psutil_get_process_memory"]
// pub fn process_memory(pid int) MemoryInfo

fn C.psutil_get_process_memory_2(int, & MemoryInfo)
pub fn process_memory(pid int) MemoryInfo {
    mi := MemoryInfo{}
    C.psutil_get_process_memory_2(pid, &mi)
    return mi
    // return process_memory(os.getpid())
}
pub fn my_process_memory() MemoryInfo {
    return process_memory(os.getpid())
}
