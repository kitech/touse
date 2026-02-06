module mpvut

import dl
import log
import net.unix
import x.json2

pub interface Sender {
    send(cmd string, args...Anyer) !RpcResultDataType
    sendraw(cmdjosn string) !RpcResultDataType
}

pub struct Cmder {
    pub mut:
    sder Sender = vnil
}

@[params]
pub struct Options{
    pub mut:
    typ SenderType
    path string
    obj voidptr
}

pub enum SenderType{
    clib
    uds
}

pub fn new(opts Options) &Cmder{
    o := &Cmder{}
    match opts.typ {
        .clib { o.sder = new_clib(opts.obj) }
        .uds { o.sder = new_uds(opts.path)}
    }
    return o
}

pub fn (o &Cmder) command(cmd string, args...Anyer) RpcResultDataType {
    return o.sder.send(cmd, ...args) or {println("$cmd: $err :${@FILE_LINE}")}
}

pub struct UnixSocketSender {
    pub mut:
    path string
    con &unix.StreamConn = vnil
}

pub fn new_uds(path string) &UnixSocketSender{
    o := &UnixSocketSender{}
    o.path = path
    return o
}
// not work for x.json2
pub type RpcResultDataType = string | int | f64  | bool //  | int | f64
struct RpcResult {
    pub mut:
    data RpcResultDataType @[json:omitempty]
    request_id int
    error string
}
// underly return format: {"data":"ipc_1","request_id":0,"error":"success"}
pub fn (o &UnixSocketSender) send(cmd string, args...Anyer) !RpcResultDataType {
    if o.con == vnil {
        con := unix.connect_stream(o.path) !
        o.con = con
    }
    argarr := ['"$cmd"']
    for aa in args { 
        match aa {
            bool { argarr << aa.str().trim('&') }
            int { argarr << aa.str()}
            f32 { argarr << aa.str()}
            f64 { argarr << aa.str().trim('&')}
            string { argarr << '"$aa"' }
            else { argarr << '"$aa"'}
        }
    }
    line := '{ "command": [${argarr.join(", ")}] }\n'
    log.info("* >> ${line.len} $line".trim_space()+" :${@FILE_LINE}")
    n := o.con.write_string(line) !
    // buf := []u8{len:399}
    // n = o.con.read(mut buf) !
    // resjcc := buf[..n].bytestr()
    resjcc := o.read_response_skip_event()!
    assert resjcc.starts_with("{") && resjcc.ends_with("}\n")
    log.info("* << $n $resjcc".trim_space()+" :${@FILE_LINE}\n")
    
    return parse_json_result(resjcc)
}
fn omitor(err IError) {}

pub fn (o &UnixSocketSender) read_response_skip_event() !string {
    for i := 0; i < 3 ; i ++ {
        buf := []u8{len:999}
        n := o.con.read(mut buf) !
        resjcc := buf[..n].bytestr()
        assert resjcc.starts_with("{") && resjcc.ends_with("}\n"), resjcc
        // log.info("* << $n $resjcc".trim_space().compact()+" :${@FILE_LINE}\n")
        
        if resjcc.starts_with('{"event":') {
            log.info("Ignore event line ${resjcc.compact()} :${@FILE_LINE}")
        }else{
            return resjcc
        }
    }
    return ""
}

/*
{"event":"audio-reconfig"}
{"event":"video-reconfig"}
{"event":"end-file","reason":"stop","playlist_entry_id":1}
{"event":"start-file","playlist_entry_id":2}
*/

// TODO how process multiple lines
pub fn parse_json_result(resjcc string) !RpcResultDataType {
    lines := resjcc.split_into_lines()
    assert lines.len > 0, resjcc.compact()
    for line in lines {
        if line.starts_with('{"event":') {
            
        }
    }
    return parse_json_result_oneline(lines[0])
}
pub fn parse_json_result_oneline(resjcc string) !RpcResultDataType {
    // parse result 111
    // oh always error indeed
    rvo := json2.decode[RpcResult](resjcc) or {
        log.debug("$err :${@FILE_LINE}") // dont want
        omitor(err)
    }
    log.debug(rvo.str().compact()+" :${@FILE_LINE}")
    
    // parse result with json2 raw decode
    jsobj := json2.raw_decode(resjcc) or {panic(err)}
    datax := jsobj.as_map()["data"]
    reqidx := jsobj.as_map()["request_id"]
    errorx := jsobj.as_map()["error"]

    rvo.error = errorx.str()
    rvo.request_id = reqidx.int()
    match datax {
        int { rvo.data = datax }
        i64 { rvo.data = RpcResultDataType(int(datax)) }
        string { rvo.data = datax }
        f64 { rvo.data = datax }
        bool { rvo.data = datax }
        json2.Null { rvo.data = 1 }
        map[string]json2.Any { // {"playlist_entry_id":2}
            log.debug("Got it `$datax` :${@FILE_LINE}")
            rvo.data = datax.str() 
        }
        else {
            // sofork datax.str() == '[]'
            log.debug("`$datax` :${@FILE_LINE}")
            if datax.str() == '[]' {
            }else{
                panic('notimpl `$datax`')
            }
        }
    }
    
    log.debug(rvo.str().compact()+" :${@FILE_LINE}")
    return if rvo.error=="success" {rvo.data}else{error(rvo.error)}    
}

pub fn (o &UnixSocketSender) sendraw(cmdjson string) !RpcResultDataType {
    if o.con == vnil {
        con := unix.connect_stream(o.path) !
        o.con = con
        // o.send("disable_event", "all") or {omitor(err)}
    }
    line := cmdjson
    log.info("* >> ${line.len} $line")
    n := o.con.write_string(line) !
    buf := []u8{len:399}
    n = o.con.read(mut buf) !
    resjcc := buf[..n].bytestr()
    log.info("* << $n $resjcc")
    
    return parse_json_result(resjcc)
}

///////

// TODO
pub struct ClibSender{
    pub mut:
    obj voidptr
}

pub fn new_clib(obj voidptr) &ClibSender {
    o := &ClibSender{}
    o.obj = obj
    return o
}

// mpv_command_async mpv_command_string mpv_command

// assume client alread linked with -lmpv
pub fn (o &ClibSender) send(cmd string, args...Anyer) !RpcResultDataType {
    symname := 'mpv_command'
    symaddr := dl.sym(vnil, symname)
    assert symaddr != vnil
    
    fno := funcof(symaddr, fn(o voidptr){})
    fno(o.obj)
    return ""
}
// assume client alread linked with -lmpv
pub fn (o &ClibSender) sendraw(cmdjson string) !RpcResultDataType {
    symname := 'mpv_command'
    symaddr := dl.sym(vnil, symname)
    assert symaddr != vnil
    
    fno := funcof(symaddr, fn(o voidptr){})
    fno(o.obj)
    return ""
}
pub fn (o &ClibSender) send_async(cmd string, args...Anyer) ! {
    symname := 'mpv_command_async'
    symaddr := dl.sym(vnil, symname)
    assert symaddr != vnil
    
    fno := funcof(symaddr, fn(o voidptr){})
    fno(o.obj)
}
pub fn (o &ClibSender) sendraw_async(cmdjson string) ! {
    symname := 'mpv_command_async'
    symaddr := dl.sym(vnil, symname)
    assert symaddr != vnil
    
    fno := funcof(symaddr, fn(o voidptr){})
    fno(o.obj)
}

///// commands

pub fn (o&Cmder) disable_event() {
    o.command(@FN, "all") 
}

pub fn (o&Cmder) loadfile(file string) {
    o.command(@FN, file) 
}

pub fn (o &Cmder) seek(pos f64, relative bool) {
    flag := if relative { "relative" } else { "absolute" }
    o.command(@FN, pos, flag)
}

// { "command": ["set_property", "pause", true] }
pub fn (o&Cmder) pause() {
    o.set_property(.pause, true)
    // line := '{ "command": ["set_property", "pause", true] }\n'
    // o.sder.sendraw(line)or {panic(err)}
}
pub fn (o&Cmder) resume() {
    o.set_property_string(.pause, false)
    // line := '{ "command": ["set_property", "pause", false] }\n'
    // o.sder.sendraw(line)or {panic(err)}
}

// window title like --title command line option
pub fn (o &Cmder) set_title(title string) {
    o.set_property(.title, title)
}

pub fn (o &Cmder) title() string {
    res := o.get_property(.title)
    return res as string
}

// TODO
pub fn (o&Cmder) quit() {
    o.command(@FN)
}

//////

pub fn (o &Cmder) set_property(prop Property, args...Anyer) {
    newargs := [Anyer(prop.tocmdname())]
    for a in args { newargs << a }
    o.command(@FN, ...newargs)
}
pub fn (o &Cmder) set_property_string(prop Property, args...Anyer) {
    newargs := [Anyer(prop.tocmdname())]
    for a in args { newargs << a }
    o.command(@FN, ...newargs)
}

pub fn (o &Cmder) get_property(prop Property, args...Anyer) RpcResultDataType {
    newargs := [Anyer(prop.tocmdname())]
    for a in args { newargs << a }
    return o.command(@FN, ...newargs)
}
pub fn (o &Cmder) get_property_string(prop Property, args...Anyer) {
    newargs := [Anyer(prop.tocmdname())]
    for a in args { newargs << a }
    o.command(@FN, ...newargs)
}
pub fn (o &Cmder) get_version() int {
    res := o.command(@FN)
    return res as int
}
pub fn (o &Cmder) client_name() string {
    res := o.command(@FN)
    return res as string
}


// \see https://mpv.io/manual/stable/#propertiess
pub enum Property {
    filename
    file_size
    estimated_frame_count
    estimated_frame_number
    pid 
    path
    stream_open_filename
    media_title
    title
    file_format
    stream_path
    stream_pos
    stream_end
    duration
    percent_pos
    time_pos
    time_remaining
    playtime_remaining
    playback_time
    pause
    playlist_pos
    playlist_pos_1
    seekable
    seeking
    mpv_version
}

fn (p Property) tocmdname() string {
    id := p.str()
    return id.replace('_', '-')
}
