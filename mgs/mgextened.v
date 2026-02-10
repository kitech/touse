module mgs

import log
import time
import sync
import os
import arrays

pub fn (r &Mgr) runloop(interval ... int) {
    mut ival := firstofv(interval)
    ival = if ival <= 0 { 3000 } else { ival }
    mut stop := false
    for i:=100; ! stop; i++ {
        r.poll(ival)
    }
}

pub fn (c &Conn) http_reply_error(stcode int, error string) {
    c.http_reply(stcode, "", error)
}
pub fn (c &Conn) http_reply_ok(extra string) {
    c.http_reply(200, "", "It's just works $extra\n")
}

struct Globvars {
    pub mut:
    mu sync.RwMutex
    // keep Funwrap's reference not GC collet
    funs map[u64]&Funwrap // listen connid =>
}

const mgv = &Globvars{}

pub type HttpFunc = fn (&Conn, &HttpMsg, voidptr)
pub type WsFunc = fn(&Conn, &WsMsg, voidptr)
pub type HandleFunc = fn(&Conn, &HttpMsg, voidptr) | fn(&Conn, &WsMsg, voidptr) | fn(&Conn, Ev, voidptr)

struct Funwrap {
    pub mut:
    proto Protocol
    opts ListenOption
}

@[params]
pub struct ListenOption {
    pub mut:
    cbval voidptr
    wsuri string
    ssl bool
    ca string 
    key string 
    cert string
    
    rawfunc RawFunc = vnil
    httpfunc HttpFunc = vnil
    wsfunc WsFunc = vnil
}

pub fn (r &Mgr) listen(url string, opts ListenOption) {
    info := &Funwrap{opts: opts}

    if opts.wsfunc != vnil || opts.httpfunc != vnil{
        info.proto = if opts.wsfunc!=vnil { .websocket } else { .http }
        c := r.http_listen(url, event_proc, voidptr(info))
        mgv.funs[u64(c.id)] = info
    } else if opts.rawfunc != vnil {
        c := C.mg_listen(r, url.str, event_proc, voidptr(info))
        mgv.funs[u64(c.id)] = info
    } else {
        assert false, "Handler cannot all nil"
    }
}

fn event_proc(c &Conn, ev Ev, evdata voidptr) {
    info := unsafe { &Funwrap(c.fn_data) }
    
    if info.proto == .websocket && ev == .http_msg {
        req := &HttpMsg(evdata)
        upgrade := true
        if info.opts.wsuri != "" && !req.uri.matchv(info.opts.wsuri) {
            // check http below
            upgrade = false
        }
        if upgrade {
            c.ws_upgrade(req)
            return
        }
    }
    
    match ev {
        .ws_msg {
            fun := info.opts.wsfunc
            if fun != vnil {
                fun(c, &WsMsg(evdata), info.opts.cbval)
            }
        }
        .http_msg {
            fun := info.opts.httpfunc
            if fun != vnil {
                fun(c, &HttpMsg(evdata), info.opts.cbval)
            }
        }
        else {
            fun := info.opts.rawfunc
            if fun != vnil {
                fun(c, ev, evdata)
            }
        }
    }
    
    if c.is_listening == ctrue && ev == .close {
        mgv.funs.delete(u64(c.id))
    }
}

pub struct HttpServeRewriteOpts {
    HttpServeOpts
    pub mut:
    index bool = false
    baseuri string // trimmed part
}

pub fn (c &Conn) http_serve_dir_rewrite(req &HttpMsg, opts &HttpServeRewriteOpts) {
    requri := url_decode(req.uri.tov())
    rootdir := tos3(opts.root_dir)
    path := opts.baseuri
    pathpfx := requri[1..]

    dump(requri)
    dump(path)
    dump(opts)    
    if opts.baseuri == "" {
        c.http_serve_dir(req, &HttpServeOpts(opts))
        return
    }
    
    dstfile := http_rewrite(path, requri, rootdir)
    log.info("Rewrite ${requri} => ${dstfile} \t:${@FILE_LINE}")
    if dstfile == "" || !os.exists(dstfile) {
        c.http_reply(404, "")
    } else if os.is_dir(dstfile) {
        // c.http_serve_dir(req, &HttpServeOpts(opts))
        data := dir_to_list_html(pathpfx, dstfile)
        c.http_reply(200, ['content-type: text/html; charset=utf8'], '$dstfile:<br/>\n${data}')
    } else {
        // c.http_serve_dir(req, &opts)
        c.http_serve_file(req, dstfile, &HttpServeOpts(opts))
    }
}

fn dir_to_list_html(pathpfx string, dir string) string {
    dirs := os.ls(dir) or {panic(err)}
    data := ''
    arr := dirs.map(fn(x string) string {
        fsize := os.file_size(os.join_path(dir, x))
        return dir_list_html_format(0, fsize, pathpfx, x)
    })
    data = arr.join('\n')
    pdir := dir_list_html_format(0, 0, pathpfx, '..')
    return data    
}

fn dir_list_html_format(idx int, size u64, pathpfx string, name string) string {
    href := if name=='..' { os.dir(pathpfx) } else { "${pathpfx}/${name}" }
    return '<li> ${size} <a href="/${href}">$name</a></li><br/>'
}

pub fn http_rewrite(baseuri string, requri string, rootdir string) string {
    assert requri.starts_with(baseuri), baseuri+" "+requri
    dstfile := os.join_path(rootdir, requri[baseuri.len..])
    log.info("rewrited $dstfile \t:${@FILE_LINE}")
    if !os.exists(dstfile) { return dstfile }
    if os.real_path(dstfile).starts_with(os.real_path(rootdir)) { return dstfile }
    if dstfile.count('..')==0 && dstfile.starts_with(rootdir) { return dstfile }
    // maybe ../../ like 
    return ""
}
