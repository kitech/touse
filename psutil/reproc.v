module psutil

import vcp.venv


#flag -lreproc
#include "@DIR/reproc_p.h"


$if windows {
    pub type ProcessType = voidptr
    $if amd64 {
        pub type PipeType = u64
    } $else {
        pub type PipeType = u32
    }
} $else{
    pub type ProcessType = int
    pub type PipeType = int
}

pub type Reproc = C.reproc_t_emu
pub struct C.reproc_t_emu {
    pub mut:
    handle ProcessType
/*
    pipe struct {
        pub mut:
        in PipeType
        out PipeType
        err PipeType
        exit_ PipeType
    }
*/
    status int
    stop struct {}
   
    deadline int64
    nonblocking bool
/*  
    child struct {
        pub mut:
        out PipeType
        err PipeType
    }
*/
}

fn C.reproc_new() &Reproc
pub fn Reproc.new() &Reproc {
    p := C.reproc_new()
    // C.memset(p, -1, sizeof(Reproc))
    return p
}

// emulate version
pub fn Reproc.from(val ProcessType) &Reproc{
    p := &Reproc{}
    p.handle = val
    p.status = -5
    return p
}

pub fn (p &Reproc) pid() int {
    return reproc_pid(p)
}

pub fn (p &Reproc) kill() ! {
    rv := reproc_kill(p)
    if rv != 0 { 
        return errorwc(reproc_strerror(rv).tosref(), rv)
    }
}
pub fn (p &Reproc) terminate() ! {
    rv := reproc_terminate(p)
    if rv != 0 { 
        return errorwc(reproc_strerror(rv).tosref(), rv)
    }
}
