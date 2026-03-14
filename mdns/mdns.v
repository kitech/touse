module mdns

import log
import time
import os
import net

#flag -DSO_REUSEPORT
#include "@DIR/mdns.h"
#include "@DIR/mdnsut.c"

pub type Record = C.mdns_record_t
pub struct C.mdns_record_t {
    pub:
    name String
    type RecordType

    data union {
        ptr RecordPtr
        srv RecordSrv
        a   RecordA
        aaaa RecordAAAA
        txt  RecordTxt
    }

    rclass u16
    ttl    u32
}

pub type RecordSrv = C.mdns_record_srv_t
pub struct C.mdns_record_srv_t {
    pub:
    priority u16
	weight   u16
	port     u16
	name     String
}
pub type RecordPtr = C.mdns_record_ptr_t
pub struct C.mdns_record_ptr_t {
    pub:
    name  String
}
pub type RecordA = C.mdns_record_a_t
pub struct C.mdns_record_a_t {
    pub:
    // addr Sockaddr_in
    addr C.sockaddr_in
}
pub type RecordAAAA = C.mdns_record_aaaa_t
pub struct C.mdns_record_aaaa_t {
    pub:
    // addr Sockaddr_in
    addr C.sockaddr_in6
}
pub type RecordTxt = C.mdns_record_txt_t
pub struct C.mdns_record_txt_t {
    pub:
    key  String
    value  String
}

pub type String = C.mdns_string_t
pub struct C.mdns_string_t {
    pub:
    str     charptr
    length  usize
}
pub fn (s String) str() string {
    return s.str.tosref(int(s.length))
}
pub fn String.from(s string) String {
    return String{s.str, usize(s.len)}
}

////////
const gvs = &Globs{}
struct Globs {
    pub:
    cbs  map[string]fn(string, string) // name =>
    lsnopt   ListenOpt
}

pub fn set_service_cb(name string, f fn(string, string)) {
    gvs.cbs[name] = f
}

/////////

fn C.mdns_socket_listen(...voidptr) usize
fn C.mdns_announce_multicast(...voidptr) int
fn C.mdns_goodbye_multicast(...voidptr) int

@[params]
pub struct ListenOpt {
    pub:
    name string = "_ohmy._tcp.local." // _hostname._tcp.local.
    broadcast_timeval  int = 8 // sec

    stopp  &bool = nil
}

fn C.sim_select(int, int) int
c99 {
    // one fd read with timeout
    static int sim_select(int fd, int timeout_sec) {
        struct timeval timeout;
		timeout.tv_sec = timeout_sec;
		timeout.tv_usec = 0;

		int nfds = fd + 1;
		fd_set readfs;
		FD_ZERO(&readfs);
        FD_SET(fd, &readfs);

		int res = select(nfds, &readfs, 0, 0, &timeout);
        return res;
    }
}

// would blocking
// listen on udp://*:5353
pub fn listen(opt ListenOpt) int {
    gvs.lsnopt = opt

    buf := []i8{len:2048}
    sock := socket_open_service()
    assert sock > 0

    cstr := String.from(opt.name)
    rec := Record{}
    rec.type = .RT_PTR
    rec.name = cstr
    rec.data.ptr.name = cstr

    btime := time.now()
    todur := opt.broadcast_timeval*time.second
    for i := 0;; i++ {
        rc := C.sim_select(sock, 1)
        if rc < 0 {
            dump('error $rc')
            return rc
        } else if rc == 0 {
            if i == 0 || time.since(btime) >= todur {
                btime = time.now()
                rvi := C.mdns_announce_multicast(sock, buf.data, buf.len, rec, nil, 0, nil, 0)
                // dump('mdns br $rvi')
                if C.errno == C.ENETUNREACH {
                    log.warn(errmsg())
                } else {
                    assert rvi == 0, errmsg()
                }
            }
            continue
        }

        rv := C.mdns_socket_listen(sock, buf.data, buf.len, record_cbraw, nil)
        // if rv > 0 { dump(rv) }
        if rv < 0 { dump('error $rv'); return -1 }
    }
    return 0
}

// return 0 for success
fn record_cbwrap(name string, fromip string, rec Record, cbval voidptr) int {
    if name == gvs.lsnopt.name {
        return 0 // ourself
    }
    if name == '' {
        return 0 // not support rtype
    }

    if gvs.cbs.len == 0 {
        println('cbnfty $name $fromip to ${gvs.cbs.len} \t${@FILE_LINE}')
    }
    for x, f in gvs.cbs {
        f(name, fromip.all_before(':'))
    }

    return 0
}

// return 0 for success
fn record_cbraw(sock int, from &C.sockaddr_in6, addrlen usize,
                entry EntryType, query_id u16, rtype RecordType,
                rclass u16, ttl u32, data voidptr, size usize,
                name_offset usize, name_length usize, record_offset usize,
                record_length usize, user_data voidptr) int
{
    // dump('$sock $entry $rtype $size $name_length $record_length')

    buf := []i8{len:256}
    sklen4 := sizeof(C.sockaddr_in)
    sklen6 := sizeof(C.sockaddr_in6)

    offset := name_offset
    name1 := C.mdns_string_extract(data, size, &offset, buf.data, buf.len)
    name := name1.str().clone()

    sklen := if from.sin6_family == C.AF_INET6 { sklen6 } else { sklen4 }
    fromip1 := C.ip_address_to_string(buf.data, buf.len, from, sklen)
    fromip := fromip1.str().clone()
    // dump('$name $fromip')

    rec := parse_record(rtype, data, size, record_offset, record_length)

    match entry {
        .ET_ANSWER {}
        else {}
    }

    record_cbwrap(name, fromip, rec, user_data)
    return 0

}

fn parse_record(rtype RecordType, data voidptr, size usize, offset usize, length usize) Record {
    res := Record{type: rtype}

    itype := int(rtype)
    buf := []i8{len:256}
    addrc4 := C.sockaddr_in{}
    sklen4 := sizeof(addrc4)
    addrc6 := C.sockaddr_in6{}
    sklen6 := sizeof(addrc6)

    match rtype {
		.RT_A {
			val := C.mdns_record_parse_a(data, size, offset, length, &addrc4)
			ipstr := C.ip_address_to_string(buf.data, buf.len, &addrc4, sklen4)
			// dump(ipstr.str())
            res.data.a.addr = *val
		}
		.RT_AAAA {
			val := C.mdns_record_parse_aaaa(data, size, offset, length, &addrc6)
			ipstr := C.ip_address_to_string(buf.data, buf.len, &addrc6, sklen6)
			// dump(ipstr.str())
            res.data.aaaa.addr = *val
		}
		.RT_PTR {
			val := C.mdns_record_parse_ptr(data, size, offset, length, buf.data, buf.len)
            res.data.ptr.name = val
		}
		.RT_SRV {
			val := C.mdns_record_parse_srv(data, size, offset, length, buf.data, buf.len)
            res.data.srv = val
		}
		.RT_TXT {
			txts := []RecordTxt{len: 9}
			val := C.mdns_record_parse_txt(data, size, offset, length, txts.data, txts.len)
			txts = txts[..val]
			if val > 1 { dump('$val $txts') }
            if val > 0 { res.data.txt = txts[0] }
		}
        else { dump('todo $itype $rtype') }
    }

    return res
}

fn C.mdns_record_parse_a(...voidptr) &C.sockaddr_in
fn C.mdns_record_parse_aaaa(...voidptr) &C.sockaddr_in6
fn C.mdns_record_parse_srv(...voidptr) RecordSrv
fn C.mdns_record_parse_txt(...voidptr) usize
fn C.mdns_record_parse_ptr(...voidptr) String
fn C.mdns_string_extract(...voidptr) String
fn C.ip_address_to_string(...voidptr) String

fn C.mdns_socket_open_ipv4(voidptr) int
fn C.mdns_htons(voidptr) u16
fn C.htons(voidptr) u16

// udp4://*:5353 for multicast service
fn socket_open_service() int {
    addr := C.sockaddr_in{}
    addr.sin_family = u16(C.AF_INET)
    addr.sin_port = C.htons(5353)

    sock := C.mdns_socket_open_ipv4(&addr) // nonblocing
    assert sock > 0
    // net.set_blocking(sock, true)
    return sock
}

fn errmsg() string {
    msg := charptr(C.strerror(C.errno)).tosref()
    return 'error ${C.errno} $msg'
}

///////////

pub enum RecordType {
    RT_IGNORE = C.MDNS_RECORDTYPE_IGNORE
    RT_A      = C.MDNS_RECORDTYPE_A
    RT_PTR    = C.MDNS_RECORDTYPE_PTR
    RT_TXT    = C.MDNS_RECORDTYPE_TXT
    RT_AAAA   = C.MDNS_RECORDTYPE_AAAA
    RT_SRV    = C.MDNS_RECORDTYPE_SRV
    RT_ANY    = C.MDNS_RECORDTYPE_ANY
}

pub enum EntryType {
    ET_QUESTION   = C.MDNS_ENTRYTYPE_QUESTION
    ET_ANSWER     = C.MDNS_ENTRYTYPE_ANSWER
    ET_AUTHORITY  = C.MDNS_ENTRYTYPE_AUTHORITY
    ET_ADDITIONAL = C.MDNS_ENTRYTYPE_ADDITIONAL
}
