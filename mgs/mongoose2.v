module mgs

import vcp

// binding version: 7.16-202510
#flag -lmongoose
#include <mongoose.h>

c99 {
    typedef struct mg_str mg_str;
    typedef struct mg_mgr mg_mgr;
    typedef struct mg_connection mg_connection;
    typedef struct mg_iobuf mg_iobuf;
    typedef struct mg_http_message mg_http_message;
    typedef struct mg_http_serve_opts mg_http_serve_opts;
}

pub type Mgr = C.mg_mgr
pub struct C.mg_mgr{}
pub type Addr = C.mg_addr
pub struct C.mg_addr{}
pub type Conn = C.mg_connection
pub struct C.mg_connection{
pub mut:
    is_closing int // bitfield
    is_draining int // bitfield
    is_resp int // bitfield
    is_full int // bitfield
    is_readable int // bitfield
    is_writable int // bitfield
    is_io_err int // bitfield
    is_arp_looking int // bitfield
    is_udp int // bitfield
    is_websocket int // bitfield
    is_listening int // bitfield
    
    next &Conn
    mgr &Mgr
    loc Addr
    rem Addr
    
    recv Iobuf // C.mg_iobuf
    send Iobuf // C.mg_iobuf
    fd voidptr
    id usize
    fn_data voidptr
}
pub type Iobuf = C.mg_iobuf
pub struct C.mg_iobuf {
    pub mut:
    buf byteptr // unsigned char *buf;  // Pointer to stored data
    size isize // size_t size;         // Total size available
    len isize // size_t len;          // Current number of bytes
    align isize // size_t align;        // Alignment during allocation
}
pub type HttpMsg = C.mg_http_message
pub struct C.mg_http_message{
    pub mut:
    method Str
    uri Str
    query Str
    proto Str
    
    body Str
    head Str
    message Str // Request + headers + body
}
pub type ReqType = HttpMsg | usize
pub type ProcFunc = fn(c &Conn, ev Ev, evdata voidptr)
struct C.mg_str{
    pub mut:
    buf charptr
    len usize
}
pub type Str = C.mg_str

pub fn (s Str) tov() string { return unsafe { *&string(voidptr(&s)) } }
pub fn (s Str) dup() string { return tosdup(s.buf, int(s.len)) }

fn C.mg_mgr_init(...voidptr)
fn C.mg_log_set(...voidptr)

pub fn Mgr.new() &Mgr {
    mut mgr := &Mgr{}
    C.mg_mgr_init(mgr)
    C.mg_log_set(C.MG_LL_DEBUG)
    return mgr
}

fn C.mg_mgr_free(...voidptr)
pub fn (r &Mgr) free() { C.mg_mgr_free(&r) }

fn C.mg_http_listen(...voidptr) &Conn
fn C.mg_listen(...voidptr) &Conn

// addr http://ip:port/
pub fn (r &Mgr) http_listen(url string, evproc ProcFunc, cbval voidptr) &Conn {
    c := C.mg_http_listen(r, url.str, voidptr(evproc), cbval)
    return c
}

fn C.mg_mgr_poll(...voidptr)

pub fn (r &Mgr) poll(ival int) {
        C.mg_mgr_poll(r, ival)
}

pub fn mgstr2v(s &C.mg_str) &string {
    return unsafe { &string(voidptr(&s)) }
}
pub fn mgstrofv(s &string) &C.mg_str {
    return unsafe { &C.mg_str(voidptr(&s)) }
}

pub fn C.mg_match(...voidptr) cint

pub fn (s0 Str) match(s Str) bool {
    rv := C.mg_match(s0, s, vnil)
    return rv == 1
}

pub fn (s0 Str) matchv(s string) bool {
    rv := C.mg_match(s0, *&Str(&s), vnil)
    return rv == 1
}

pub type HttpServeOpts = C.mg_http_serve_opts
// @[typedef]
pub struct C.mg_http_serve_opts {
    pub mut:
    root_dir charptr
    ssi_pattern charptr
    extra_headers charptr
    mime_types charptr
    page404 charptr
    fs voidptr // &FS // struct mg_fs
}

// static site
pub fn (c &Conn) http_serve_dir(htmsg &HttpMsg, opts &HttpServeOpts) {
    C.mg_http_serve_dir(c, htmsg, opts)
}
pub fn (c &Conn) http_serve_file(htmsg &HttpMsg, path string, opts &HttpServeOpts) {
    C.mg_http_serve_file(c, htmsg, path.str, opts)
}

/////////

// void mg_http_reply(struct mg_connection *, int status_code, const char *headers,
                   // const char *body_fmt, ...);
fn C.mg_http_reply(...voidptr)

pub type Headers = map[string]string | []string | string

// dont too much data, need temp build data string
pub fn (c &Conn) http_reply(stcode int, headers Headers, bodys ... string) {
    mut hdrstr := ""
    match headers {
        map[string]string {
            for k, v in headers { hdrstr += "${k}: ${v}\r\n" }
        }
        []string {
            for s in headers { hdrstr += s + "\r\n" }
        }
        string { hdrstr = headers }
    }
    mut data := ""
    for s in bodys { data += s }
    hdrptr := if hdrstr.len == 0 { vnil } else { hdrstr.str }
    datptr := if data.len == 0 { vnil } else { data.str }
    // vcp.info('datalen', data.len)
    C.mg_http_reply(c, stcode, hdrptr, data.str)
}

fn C.mg_close_conn(...voidptr)
pub fn (c &Conn) close() { C.mg_close_conn(c) }

pub fn (c &Conn) set_closing() {
    c.is_closing = 1
}

pub fn (c &Conn) set_draining() {
    c.is_draining = 1
}

pub fn (c &Conn) set_resp() { 
    c.is_resp = 0
}

fn C.mg_send(... voidptr) cint

pub fn (c &Conn) send(data voidptr, len usize) bool {
    rv := C.mg_send(c, data, len)
    return rv.ok()
}
pub fn (c &Conn) send1(data string) bool {
    return c.send(data.str, usize(data.len))
}

pub enum Ev  {
    error = C.MG_EV_ERROR      // Error                        char *error_message
    open = C.MG_EV_OPEN       // Connection created           NULL
    poll = C.MG_EV_POLL       // mg_mgr_poll iteration        uint64_t *uptime_millis
    resolve = C.MG_EV_RESOLVE    // Host name is resolved        NULL
    connect = C.MG_EV_CONNECT    // Connection established       NULL
    accept = C.MG_EV_ACCEPT     // Connection accepted          NULL
    tls_hs = C.MG_EV_TLS_HS     // TLS handshake succeeded      NULL
    read = C.MG_EV_READ       // Data received from socket    long *bytes_read
    write = C.MG_EV_WRITE      // Data written to socket       long *bytes_written
    close = C.MG_EV_CLOSE      // Connection closed            NULL
    http_hdrs = C.MG_EV_HTTP_HDRS  // HTTP headers                 struct mg_http_message *
    http_msg = C.MG_EV_HTTP_MSG   // Full HTTP request/response   struct mg_http_message *
    ws_open = C.MG_EV_WS_OPEN    // Websocket handshake done     struct mg_http_message *
    ws_msg = C.MG_EV_WS_MSG     // Websocket msg, text or bin   struct mg_ws_message *
    ws_ctl = C.MG_EV_WS_CTL     // Websocket control msg        struct mg_ws_message *
    mqtt_cmd = C.MG_EV_MQTT_CMD   // MQTT low-level command       struct mg_mqtt_message *
    mqtt_msg = C.MG_EV_MQTT_MSG   // MQTT PUBLISH received        struct mg_mqtt_message *
    mqtt_open = C.MG_EV_MQTT_OPEN  // MQTT CONNACK received        int *connack_status_code
    sntp_time = C.MG_EV_SNTP_TIME  // SNTP time received           uint64_t *epoch_millis
    wakeup = C.MG_EV_WAKEUP     // mg_wakeup() data received    struct mg_str *data
    user = C.MG_EV_USER        // Starting ID for user events
}

pub enum Protocol {
    http 
    websocket 
    arp
    origin
}

pub enum LogLevel {
    llnone = C.MG_LL_NONE
    llerror = C.MG_LL_ERROR
    llinfo = C.MG_LL_INFO
    lldebug = C.MG_LL_DEBUG
    llverbose = C.MG_LL_VERBOSE
}

pub fn log_set(ll LogLevel) { C.mg_log_set(ll) }

fn C.mg_log_set(...voidptr)
fn C.mg_mgr_init(...voidptr)
fn C.mg_mgr_free(...voidptr)
fn C.mg_mgr_poll(...voidptr) int
fn C.mg_bind(...voidptr) voidptr
// fn C.mg_set_protocol_http_websocket(...voidptr)
fn C.mg_send(...voidptr) cint
fn C.mg_send_head(...voidptr)
fn C.mg_send_response_line(...voidptr)
fn C.mg_http_send_error(...voidptr)
fn C.mg_http_send_redirect(...voidptr)
fn C.mbuf_remove(...voidptr)
fn C.mg_http_serve_dir(...voidptr)
fn C.mg_http_serve_file(...voidptr)
