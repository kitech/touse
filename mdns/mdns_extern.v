module mdns

import log
import time
import os
import net


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


@[params]
pub struct ListenOpt {
    pub:
    name string = "_ohmy._tcp.local." // _hostname._tcp.local.
    port int = 8899 // main app control tcp/udp port
    broadcast_timeval  int = 8 // sec
    br_hostname bool = true

    stopp  &bool = &bool(&String{})
}

fn hostname() string {
    name := os.hostname() or { 'nohost' }
    return '${name}.local.'
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

    adds := []Record{}
    r := Record{}
    r.type = .RT_SRV
    r.name = cstr
    r.data.srv = RecordSrv{port:u16(opt.port), name: String.from(hostname())}
    adds << r

    r = create_currip_reca() or { panic(err) }
    adds << r

    btime := time.now()
    todur := opt.broadcast_timeval*time.second
    for i := 0;; i++ {
        rc := C.sim_select(sock, 1)
        if rc < 0 {
            emsg0 := C.strerror(C.errno)
            emsg := charptr(emsg0).tosref()
            dump('error $rc $emsg')
            if emsg.contains('Interrupted system call') {
                time.sleep(1234*time.millisecond)
                continue
            }
            return rc
        } else if rc == 0 {
            if i == 0 || time.since(btime) >= todur {
                log.info('broadcast hostname  A ...')
                // ip may change
                ra := create_currip_reca() or { continue }
                adds[adds.len-1] = ra

                btime = time.now()
                rvi := C.mdns_announce_multicast(sock, buf.data, buf.len, rec, nil, 0, adds.data, adds.len)
                // dump('mdns br $rvi')
                // 101, 50
                if C.errno == C.ENETUNREACH || C.errno == C.ENETDOWN {
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

fn create_currip_reca() !Record {

    ipcnt := 0
    ipstrs := C.getipaddrs(&ipcnt, 0)
    ips := cstrs2vstrs(voidptr(ipstrs), ipcnt, true)
    if ips.len == 0 {
        log.error('$ipcnt $ips')
        return error('ips zeror')
    }

    r := Record{}
    r.type = .RT_A
    r.name = String.from(hostname())
    r.ttl = 60
    r.rclass = .CLASS_IN
    r.data.a = RecordA{ C.ipv4_string_to_address(ips[0].str)}

    return r
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
