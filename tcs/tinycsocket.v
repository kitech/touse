module tcs

import strconv

#flag -DTINYCSOCKET_IMPLEMENTATION
#include "@DIR/tinycsocket.h"
#include <assert.h>

fn init() {
    res := C.tcs_lib_init()
    assert res == 0
}
fn deinit() {
    res := C.tcs_lib_free()
    assert res == 0
}

pub type Result = int // enum indeed

pub type Socket = C.TcsSocket
@[typedef]
pub struct C.TcsSocket{}

pub type Address = C.TcsAddress
pub struct C.TcsAddress {
    family int
}

// (tcp/udp)://ip:port
pub fn dial(address string) !Socket {
    sock := invalid_socket()
    proto, ipstr, port := parse_addr_uri(address) !
    res := Result(0)

    // res := C.tcs_tcp_server_str(&sock, c'0.0.0.0', 3000)
    if proto == C.TCS_PROTOCOL_IP_UDP {
        sock = newUdpSocket() !
        res = C.tcs_connect_str(sock, ipstr.str, port)
    } else {
        timeoutms := 0
        res = C.tcs_tcp_client_str(&sock, ipstr.str, u16(port), timeoutms)
    }
    assert res==0, res.errmsg()
    return sock
}

fn invalid_socket() Socket {
    sock := Socket{}
    c99 { sock = TCS_SOCKET_INVALID; }
    return sock
}
pub fn errmsg() string {
    return charptr(C.strerror(C.errno)).tosref()
}
pub fn (res Result) errmsg() string {
    emsg1 := match int(res) {
        0 { 'SUCCESS' }
        1 { 'AGAIN' }
        2 { 'IN_PROGRESS' }
        3 { 'SHUTDOWN' }

            -1 { 'UNKNOWN' }
            -2 { 'MEMORY' }
            -3 { 'INVALID_ARGUMENT' }
            -4 { 'SYSTEM' }
            -5 { 'PERMISSION_DENIED' }
            -6 { 'NOT_IMPLEMENTED' }

        else { '$res' }
    }
    emsg2 := errmsg()
    emsg3 := '$emsg1 $emsg2'

    return emsg3
}

pub fn split_host_port(ipport string) (string, int) {
    ipstr := ipport.all_before(':')
    portstr := ipport.all_after(':')
    return ipstr, portstr.int()
}

// (tcp/udp/unix)://ip:port
// return proto, ipstr, port
pub fn parse_addr_uri(address string) !(int, string, int) {
    protostr := address.all_before("://").to_lower()
    hoststr := address.all_after("://")
    ipstr := hoststr.all_before(":")
    portstr := hoststr.all_after(":")

    proto := 0
    port := portstr.int()
    match protostr {
        "udp" { proto = C.TCS_PROTOCOL_IP_UDP }
        "tcp" { proto = C.TCS_PROTOCOL_IP_TCP }
        else { return error("wtt proto $protostr") }
    }

    match ipstr {
        "*" { ipstr = "0.0.0.0" }
        " " { return error("use * or 0.0.0.0 for any") }
        else {}
    }
    if port == 0 { return error("invalid port $portstr") }

    return proto, ipstr, port
}

// deprecated
pub fn newUdpSocket() !Socket {
    sock := invalid_socket()
    res := Result(0)

    res = C.tcs_socket(&sock, C.TCS_AF_IP4, C.TCS_SOCK_DGRAM, C.TCS_PROTOCOL_IP_UDP)
    assert res==0
    sock.set_reuse_address(true) !
    sock.set_broadcast(true) !

    return sock
}

// use listen
fn newUdpServer(address string) !Socket {
    proto, ipstr, port := parse_addr_uri(address) !
    res := Result(0)
    sock := newUdpSocket() !

    ipport := '$ipstr:$port'
    bind_address := Address{}
    c99 {
        res = tcs_address_parse(ipport.str, &bind_address);
        assert(res==0);
        res = tcs_bind(sock, &bind_address);
    }
    assert res == 0, errmsg()
    return sock
}

// pub fn newUdpClient(ipport string) !Socket {
//     res := Result(0)
//     sock := invalid_socket()

//     ipstr, port := split_host_port(ipport)
//     dump('$ipstr $port')
//     res = C.tcs_udp_sender_str(&sock, ipstr.str, u16(port))
//     assert res == 0, res.errmsg()

//     return sock
// }

pub fn listen(address string) !Socket {
    sock := invalid_socket()
    proto, ipstr, port := parse_addr_uri(address) !
    res := Result(0)
    // res := C.tcs_tcp_server_str(&sock, c'0.0.0.0', 3000)
    if proto == C.TCS_PROTOCOL_IP_UDP {
        sock = newUdpServer(address) !
    } else {
        res = C.tcs_tcp_server_str(&sock, ipstr.str, u16(port))
    }
    assert res == 0, address+errmsg()
    sock.set_reuse_address(true) !

    return sock
}

pub fn (s Socket) accept() !Socket {
    sock := invalid_socket()
    addr := Address{}
    res := C.tcs_accept(s, &sock, &addr)
    assert res == 0, errmsg()
    dump(sock)
    return sock
}

@[params]
pub struct ReadArg {
    pub:
    n   int
    sep string
    timeoutms int
}

pub fn (s Socket) read(buf []u8, arg ReadArg) !int {
    flags := u32(0)
    rn := usize(0)
    res := Result(0)

    if arg.sep != "" {
        sep := arg.sep[0]
        res = C.tcs_receive_line(s, buf.data, buf.len, &rn, sep)
    } else if arg.n > 0 {
        assert false
    } else {
        res = C.tcs_receive(s, buf.data, buf.len, flags, &rn)
    }
    if res == 3 {
        return errorwc('EOF', int(res))
    } else if res != 0 {
        return errorwc(errmsg(), int(res))
    }
    assert res==0, errmsg()

    return int(rn)

}
pub fn (s Socket) read_from(buf []u8, arg ReadArg) !(int, Address) {
    addr := Address{}
    rn := usize(0)
    res := C.tcs_receive_from(s, buf.data, buf.len, 0, &addr, &rn)
    assert res == 0, errmsg()

    return int(rn), addr
}

// string, &u8, []u8
pub fn (s Socket) write[T](buf T) !int {
    d := byteptr(nil)
    len := 0

    $if T.unaliased_typ is string {
        d = byteptr(buf.str)
        len = buf.len
    } $else $if T.unaliased_typ is []u8 {
        d = byteptr(buf.data)
        len = buf.len
    } $else { assert false, typeof(buf).name }

    wn := usize(0)
    res := C.tcs_send(s, d, len, 0, &wn)
    assert res==0, res.errmsg()
    assert int(wn) == len

    return len
}
// string, []u8, charptr
pub fn (s Socket) write_to[T](buf T, ipport string) !int {
    res := Result(0)
    bind_address := Address{}
    c99 {
        res = tcs_address_parse(ipport.str, &bind_address);
        assert(res==0);
    }

    d, len := byteptr(nil), 0
    wn := usize(0)
    $if T.unaliased_typ is string {
        d, len = buf.str, buf.len
    } $else $if T.unaliased_typ is charptr {
        d, len = buf, C.strlen(buf)

    } $else $if T.unaliased_typ is []u8 {
        d, len = buf.data, buf.len
    } $else { assert false, typeof(buf).name }

    res = C.tcs_send_to(s, d, len, 0, &bind_address, &wn)
    assert res==0, errmsg()+ ' $ipport'
    assert int(wn) == len

    return int(wn)
}

pub fn (s Socket) close() {
    res := C.tcs_close(&s)
    assert res==0, errmsg()
}

pub fn (s Socket) str() string { return 'Socket(${s.sysfd()})' }
pub fn (s Socket) sysfd() int { return *&int(&s) }

pub fn (s Socket) laddr() Address {
    addr := Address{}
    res := C.tcs_address_socket_local(s, &addr)
    assert res==-6, res.errmsg()
    assert false, "TODO"
    return addr
}
pub fn (s Socket) laddr2() string { return s.addrof2(true) }
pub fn (s Socket) raddr() Address {
    addr := Address{}
    res := C.tcs_address_socket_remote(s, &addr)
    assert res==-6, res.errmsg()
    assert false, "TODO"
    return addr
}
pub fn (s Socket) raddr2() string { return s.addrof2(false) }
pub fn (s Socket) addrof2(isloc bool) string {
    addr0 := Address{}
    res := Result(0)
    bufp2 := charptr(nil)
    c99 {
        struct sockaddr_in addr = {0};
        socklen_t len = sizeof(addr);
        if (isloc) {
            res = getsockname(s, (struct sockaddr *)&addr, &len);
        } else {
            res = getpeername(s, (struct sockaddr *)&addr, &len);
        }
        assert(res==0);

        char bufp[70] = {0};
        char* x = inet_ntop(AF_INET, &(addr.sin_addr.s_addr), bufp, 70);
        assert(x != 0);
        snprintf(bufp+strlen(bufp), 9, ":%d", ntohs(addr.sin_port));
        // printf("'%s' %d\n", bufp, strlen(bufp));
        res = tcs_address_parse(bufp, &addr0);
        bufp2 = bufp;
    }
    assert res == 0
    // dump(bufp2.tosdup())
    return bufp2.tosdup()
}

pub fn (addr Address) family() string {
    return addr.family.str()
}
pub fn (addr Address) str() string {
    buf := [70]i8{}
    res := C.tcs_address_to_str(&addr, &buf[0])
    assert res == 0, res.errmsg()
    s := charptr(&buf[0]).tosdup()
    return 'proto://$s'
}

pub fn (s Socket) set_broadcast(bv bool) !bool {
    res := C.tcs_opt_broadcast_set(s, bv)
    return res == 0
}
pub fn (s Socket) set_reuse_address(bv bool) !bool {
    res := C.tcs_opt_reuse_address_set(s, bv)
    return res == 0
}
pub fn (s Socket) set_read_timeoutms(v int) !bool {
    res := C.tcs_opt_receive_timeout_set(s, v)
    return res == 0
}

fn C.getsockopt(...voidptr) int
pub fn (s Socket) get_type() int {
    typ := 0
    len := sizeof(int)

    // Call getsockopt to retrieve the socket type option
    rv := C.getsockopt(s, C.SOL_SOCKET, C.SO_TYPE, &typ, &len)
    assert rv == 0
    return typ
}

pub fn (s Socket) get_type2() string {
    typ := s.get_type()
    return match typ {
        C.TCS_SOCK_DGRAM { 'udp' }
        C.TCS_SOCK_STREAM { 'tcp' }
        C.TCS_SOCK_RAW { 'raw' }
        // C.TCS_SOCK_SEQPACKET { 'seqpacket' } // new
        else { 'wtype $typ' }
    }
}


// /*
// * List of all functions in the library:
// *
// * The documentation for each function is located at the declaration in this document.
// * Note: Most IDE:s and editors can jump to decalarations directly from here (ctrl+click on symbol or right click -> "Go to Declaration")
// *
// * Library Management:
fn C.tcs_lib_init() Result
fn C.tcs_lib_free() Result
// *
// * Socket Creation:
// * - TcsResult tcs_socket(TcsSocket* socket_ctx, TcsAddressFamily family, int type, int protocol);
fn C.tcs_socket(...voidptr) Result
// * - TcsResult tcs_socket_preset(TcsSocket* socket_ctx, TcsPreset socket_type);
// * - TcsResult tcs_close(TcsSocket* socket_ctx);
fn C.tcs_close(voidptr) Result
// *
// * High-level Socket Creation:
// * - TcsResult tcs_tcp_server(TcsSocket* socket_ctx, const struct TcsAddress* local_address);
fn C.tcs_tcp_server(...voidptr) Result
// * - TcsResult tcs_tcp_server_str(TcsSocket* socket_ctx, const char* local_address, uint16_t port);
fn C.tcs_tcp_server_str(...voidptr) Result
// * - TcsResult tcs_tcp_client(TcsSocket* socket_ctx, const struct TcsAddress* remote_address, int timeout_ms);
fn C.tcs_tcp_client_str(...voidptr) Result
// * - TcsResult tcs_tcp_client_str(TcsSocket* socket_ctx, const char* remote_address, uint16_t port, int timeout_ms);
// * - TcsResult tcs_udp_receiver(TcsSocket* socket_ctx, const struct TcsAddress* local_address);
// * - TcsResult tcs_udp_receiver_str(TcsSocket* socket_ctx, const char* local_address, uint16_t port);
fn C.tcs_udp_receiver_str(...voidptr) Result
// * - TcsResult tcs_udp_sender(TcsSocket* socket_ctx, const struct TcsAddress* remote_address);
// * - TcsResult tcs_udp_sender_str(TcsSocket* socket_ctx, const char* remote_address, uint16_t port);
fn C.tcs_udp_sender_str(...voidptr) Result
// * - TcsResult tcs_udp_peer(TcsSocket* socket_ctx, const struct TcsAddress* local_address, const struct TcsAddress* remote_address);
// * - TcsResult tcs_udp_peer_str(TcsSocket* socket_ctx, const char* local_address, uint16_t local_port, const char* remote_address, uint16_t remote_port);
// *
// * High-level Raw L2-Packet Sockets (Experimental):
// * - TcsResult tcs_packet_sender(TcsSocket* socket_ctx, const struct TcsAddress* remote_address);
// * - TcsResult tcs_packet_sender_str(TcsSocket* socket_ctx, const char* interface_name, const uint8_t destination_mac[6], uint16_t protocol);
// * - TcsResult tcs_packet_peer(TcsSocket* socket_ctx, const struct TcsAddress* local_address, const struct TcsAddress* remote_address);
// * - TcsResult tcs_packet_peer_str(TcsSocket* socket_ctx, const char* interface_name, const uint8_t destination_mac[6], uint16_t protocol);
// * - TcsResult tcs_packet_capture_iface(TcsSocket* socket_ctx, const struct TcsInterface* iface);
// * - TcsResult tcs_packet_capture_ifname(TcsSocket* socket_ctx, const char* interface_name);
// *
// * Socket Operations:
// * - TcsResult tcs_bind(TcsSocket socket_ctx, const struct TcsAddress* local_address);
// * - TcsResult tcs_connect(TcsSocket socket_ctx, const struct TcsAddress* address);
// * - TcsResult tcs_connect_str(TcsSocket socket_ctx, const char* remote_address, uint16_t port);
fn C.tcs_connect_str(...voidptr) Result
// * - TcsResult tcs_listen(TcsSocket socket_ctx, int backlog);
fn C.tcs_listen(...voidptr) Result
// * - TcsResult tcs_accept(TcsSocket socket_ctx, TcsSocket* child_socket_ctx, struct TcsAddress* address);
fn C.tcs_accept(...voidptr) Result
// * - TcsResult tcs_shutdown(TcsSocket socket_ctx, TcsSocketDirection direction);
// *
// * Data Transfer:
// * - TcsResult tcs_send(TcsSocket socket_ctx, const uint8_t* buffer, size_t buffer_size, uint32_t flags, size_t* bytes_sent);
fn C.tcs_send(...voidptr) Result
// * - TcsResult tcs_send_to(TcsSocket socket_ctx, const uint8_t* buffer, size_t buffer_size, uint32_t flags, const struct TcsAddress* destination_address, size_t* bytes_sent);
fn C.tcs_send_to(...voidptr) Result
// * - TcsResult tcs_sendv(TcsSocket socket_ctx, const struct TcsBuffer* buffers, size_t buffer_count, uint32_t flags, size_t* bytes_sent);
// * - TcsResult tcs_send_netstring(TcsSocket socket_ctx, const uint8_t* buffer, size_t buffer_size);
// * - TcsResult tcs_receive(TcsSocket socket_ctx, uint8_t* buffer, size_t buffer_size, uint32_t flags, size_t* bytes_received);
fn C.tcs_receive(...voidptr) Result
// * - TcsResult tcs_receive_from(TcsSocket socket_ctx, uint8_t* buffer, size_t buffer_size, uint32_t flags, struct TcsAddress* source_address, size_t* bytes_received);
fn  C.tcs_receive_from(...voidptr) Result
// * - TcsResult tcs_receive_line(TcsSocket socket_ctx, uint8_t* buffer, size_t buffer_size, size_t* bytes_received, uint8_t delimiter);
fn C.tcs_receive_line(...voidptr) Result
// * - TcsResult tcs_receive_netstring(TcsSocket socket_ctx, uint8_t* buffer, size_t buffer_size, size_t* bytes_received);
//
// *
// * Socket Pooling:
// * - TcsResult tcs_pool_create(struct TcsPool** pool);
// * - TcsResult tcs_pool_destroy(struct TcsPool** pool);
// * - TcsResult tcs_pool_add(struct TcsPool* pool, TcsSocket socket_ctx, void* user_data, bool poll_can_read, bool poll_can_write, bool poll_error);
// * - TcsResult tcs_pool_remove(struct TcsPool* pool, TcsSocket socket_ctx);
// * - TcsResult tcs_pool_poll(struct TcsPool* pool, struct TcsPollEvent* events, size_t events_count, size_t* events_populated, int64_t timeout_in_ms);
// *
// * Socket Options:
// * - TcsResult tcs_opt_set(TcsSocket socket_ctx, int32_t level, int32_t option_name, const void* option_value, size_t option_size);
// * - TcsResult tcs_opt_get(TcsSocket socket_ctx, int32_t level, int32_t option_name, void* option_value, size_t* option_size);
// * - TcsResult tcs_opt_broadcast_set(TcsSocket socket_ctx, bool do_allow_broadcast);
fn C.tcs_opt_broadcast_set(...voidptr) Result
// * - TcsResult tcs_opt_broadcast_get(TcsSocket socket_ctx, bool* is_broadcast_allowed);
// * - TcsResult tcs_opt_keep_alive_set(TcsSocket socket_ctx, bool do_keep_alive);
// * - TcsResult tcs_opt_keep_alive_get(TcsSocket socket_ctx, bool* is_keep_alive_enabled);
// * - TcsResult tcs_opt_reuse_address_set(TcsSocket socket_ctx, bool do_allow_reuse_address);
fn C.tcs_opt_reuse_address_set(...voidptr) Result
// * - TcsResult tcs_opt_reuse_address_get(TcsSocket socket_ctx, bool* is_reuse_address_allowed);
// * - TcsResult tcs_opt_send_buffer_size_set(TcsSocket socket_ctx, size_t send_buffer_size);
// * - TcsResult tcs_opt_send_buffer_size_get(TcsSocket socket_ctx, size_t* send_buffer_size);
// * - TcsResult tcs_opt_receive_buffer_size_set(TcsSocket socket_ctx, size_t receive_buffer_size);
// * - TcsResult tcs_opt_receive_buffer_size_get(TcsSocket socket_ctx, size_t* receive_buffer_size);
// * - TcsResult tcs_opt_receive_timeout_set(TcsSocket socket_ctx, int timeout_ms);
fn C.tcs_opt_receive_timeout_set(...voidptr) Result
// * - TcsResult tcs_opt_receive_timeout_get(TcsSocket socket_ctx, int* timeout_ms);
// * - TcsResult tcs_opt_linger_set(TcsSocket socket_ctx, bool do_linger, int timeout_seconds);
// * - TcsResult tcs_opt_linger_get(TcsSocket socket_ctx, bool* do_linger, int* timeout_seconds);
// * - TcsResult tcs_opt_ip_no_delay_set(TcsSocket socket_ctx, bool use_no_delay);
// * - TcsResult tcs_opt_ip_no_delay_get(TcsSocket socket_ctx, bool* is_no_delay_used);
// * - TcsResult tcs_opt_out_of_band_inline_set(TcsSocket socket_ctx, bool enable_oob);
// * - TcsResult tcs_opt_out_of_band_inline_get(TcsSocket socket_ctx, bool* is_oob_enabled);
// * - TcsResult tcs_opt_priority_set(TcsSocket socket_ctx, int priority);
// * - TcsResult tcs_opt_priority_get(TcsSocket socket_ctx, int* priority);
// * - TcsResult tcs_opt_nonblocking_set(TcsSocket socket_ctx, bool do_nonblocking);
// * - TcsResult tcs_opt_nonblocking_get(TcsSocket socket_ctx, bool* is_nonblocking);
// * - TcsResult tcs_opt_membership_add(TcsSocket socket_ctx, const struct TcsAddress* multicast_address);
// * - TcsResult tcs_opt_membership_add_to(TcsSocket socket_ctx, const struct TcsAddress* local_address, const struct TcsAddress* multicast_address);
// * - TcsResult tcs_opt_membership_drop(TcsSocket socket_ctx, const struct TcsAddress* multicast_address);
// * - TcsResult tcs_opt_membership_drop_from(TcsSocket socket_ctx, const struct TcsAddress* local_address, const struct TcsAddress* multicast_address);
//
// *
// * Address and Interface Utilities:
// * - TcsResult tcs_interface_list(struct TcsInterface interfaces[], size_t capacity, size_t* out_count);
// * - TcsResult tcs_address_resolve(const char* hostname, TcsAddressFamily address_family, struct TcsAddress addresses[], size_t capacity, size_t* out_count);
// * - TcsResult tcs_address_resolve_timeout(const char* hostname, TcsAddressFamily address_family, struct TcsAddress addresses[], size_t capacity, size_t* out_count, int timeout_ms);
// * - TcsResult tcs_address_list(unsigned int interface_id_filter, TcsAddressFamily address_family_filter, struct TcsInterfaceAddress interface_addresses[], size_t capacity, size_t* out_count);
// * - TcsResult tcs_address_socket_local(TcsSocket socket_ctx, struct TcsAddress* local_address);
fn C.tcs_address_socket_local(...voidptr) Result
// * - TcsResult tcs_address_socket_remote(TcsSocket socket_ctx, struct TcsAddress* remote_address);
fn C.tcs_address_socket_remote(...voidptr) Result
// * - TcsResult tcs_address_socket_family(TcsSocket socket_ctx, TcsAddressFamily* out_family);
// * - TcsResult tcs_address_parse(const char str[], struct TcsAddress* out_address);
// * - TcsResult tcs_address_to_str(const struct TcsAddress* address, char out_str[70]);
fn C.tcs_address_to_str(...voidptr) Result
// * - bool tcs_address_is_equal(const struct TcsAddress* l, const struct TcsAddress* r);
// * - bool tcs_address_is_any(const struct TcsAddress* addr);
// * - bool tcs_address_is_local(const struct TcsAddress* addr);
// * - bool tcs_address_is_loopback(const struct TcsAddress* addr);
// * - bool tcs_address_is_multicast(const struct TcsAddress* addr);
// * - bool tcs_address_is_broadcast(const struct TcsAddress* addr);
// */
