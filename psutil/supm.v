module psutil

import os

@[params]
pub struct SvOption {
    pub mut:
    name string // must unique
    
    exe string
    args []string
    envs map[string]string
    wkdir string = os.getwd()
    
    auto_restart bool = true
    restart_delay int = 9 // in second
    log_dir string = os.getwd()
    log_max_size int = 9 // in MB
}

pub struct VbiProc {
    pub mut:
    name string
    bkd  string // "vproc", "reproc"
    opts SvOption
    
    p &os.Process = vnil
    // rp voidptr
}

pub interface SvBackend {
    start(name string)
    stop(name string)
}

pub struct Supvis {
    pub mut:
    procs map[string]&VbiProc
}

pub fn Supvis.new() &Supvis {
    sv := &Supvis{}
    
    return sv
}

pub fn (sv &Supvis) add(name string, opts SvOption) {
    p := &VbiProc{}
    p.name = name
    p.opts = opts
    
    sv.procs[name] = p
}
pub fn (sv &Supvis) del(name string) {
    
}

pub fn (sv &Supvis) start(name string) {
    ps := sv.procs[name] or {
        dump('not exist $name')
        return
    }
    
    p := os.new_process(ps.opts.exe)
    p.set_args(ps.opts.args)
    p.set_work_folder(ps.opts.wkdir)
    ps.p = p
    p.run()
}

pub fn (sv &Supvis) stop(name string) {
    ps := sv.procs[name] or {
        dump('not exist $name')
        return
    }
    ps.p.signal_stop()
    ps.p.signal_term()
    ps.p.signal_kill()
    ps.p.wait()
    ps.p.close()
}
pub fn (sv &Supvis) pause(name string) {
    
}
