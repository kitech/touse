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

    // rclass u16
    rclass ClassType
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

pub fn Record.new(r Anyer) Record {
    o := Record{}
    return o
}

pub fn RecordPtr.new() RecordPtr {
    r := RecordPtr{}

    return r
}
pub fn RecordSrv.new() RecordSrv {
    r := RecordSrv{}

    return r
}
pub fn RecordTxt.new() RecordTxt {
    r := RecordTxt{}

    return r
}
pub fn RecordA.new(name string, ipstr string, ttl int) Record {
    r := Record{}
    r.type = .RT_A
    r.rclass = .CLASS_IN
    r.ttl = u32(ttl)
    r.name = String.from(name)
    d := RecordA{C.ipv4_string_to_address(ipstr)}
    r.data.a = d

    return r
}


/////////

fn C.mdns_socket_listen(...voidptr) usize
fn C.mdns_announce_multicast(...voidptr) int
fn C.mdns_goodbye_multicast(...voidptr) int
fn C.ipv4_string_to_address(...voidptr) C.sockaddr_in
fn C.getipaddrs(...voidptr) &charptr
fn C.freeipaddrs(...voidptr)
/*
char** getipaddrs(int* count, int max_count);
void freeipaddrs(char** ips, int count);
*/


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
    addr.sin_family = u8(C.AF_INET)
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

pub enum ClassType as u16 {
    CLASS_IN = C.MDNS_CLASS_IN  // 1
    ClASS_ANY = C.MDNS_CLASS_ANY // 255
}
