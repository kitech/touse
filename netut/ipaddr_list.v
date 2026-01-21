module netut

import json

// 使用C99编写跨平台获取当前系统IP地址列表的函数，函数名加前缀 netut__，注意是又下划线
#flag @DIR/ipaddr_list.o
// 使用C99编写跨平台监听IP地址变化的函数，函数名加前缀 netut__，注意是双下划线
#flag @DIR/ip_monitor.o

#flag darwin -framework SystemConfiguration

c99 { // need extern for return size>sizeof(int32)
    extern void* netut_get_all_ip_addresses();
}

@[importc: "netut_get_all_ip_addresses"]
pub fn get_all_ip_addresses() voidptr
@[importc: "netut_free_ip_list"]
pub fn free_ip_list(voidptr)

@[importc: "netut_print_ip_list"]
pub fn print_ip_list(voidptr)

@[importc: "netut_format_ip_list_json"]
pub fn ip_list_json(iplst voidptr, buf charptr, bufsz usize) int

pub fn get_ipaddrs() ![]string{
    iplst := get_all_ip_addresses()

    bufsz := 986
    buf := [bufsz]i8{}
    rv := ip_list_json(iplst, charptr(&buf[0]), usize(bufsz))
    assert rv==0
    defer { free_ip_list(iplst) }
    
    jstr := charptr(&buf[0]).tosref()
    // dump(jstr)
    addrs := json.decode(Addresses, jstr) !
    // dump(addrs)
    res := addrs.addresses.map(|x| x.address)
    
    return res
}

struct Addresses {
    pub mut:
    count int
    error bool
    addresses []struct {
        interface string
        address string
        family string
        prefix_length int
        status string
        type string
    }
}


//////////////////

// all return non int funcs need extern
c99 {
    extern void* netut_create_ip_monitor_event(void*, void*);
    extern char* netut_get_monitor_event_error(void*);
}

@[importc: "netut_create_ip_monitor_event"]
pub fn create_ip_monitor_event(cbfn voidptr, cbval voidptr) voidptr

@[importc: "netut_free_ip_monitor_event"]
pub fn free_ip_monitor_event(mon voidptr)

@[importc: "netut_start_ip_monitor_event"]
pub fn start_ip_monitor_event(mon voidptr) int

@[importc: "netut_stop_ip_monitor_event"]
pub fn stop_ip_monitor_event(mon voidptr) int

@[importc: "netut_get_monitor_event_error"]
pub fn get_monitor_event_error(mon voidptr) charptr

@[importc: "netut_process_ip_events"]
pub fn process_ip_events(mon voidptr, ms int) int

fn onip_change(interface_name charptr, ip_address charptr, family int, event_type int, cbval voidptr) {
    onip_change_2(interface_name.tosdup(), ip_address.tosdup(), family, event_type, cbval)
}
fn onip_change_2(interface_name string, ip_address string, family int, event_type int, cbval voidptr) {
    println("ifn $interface_name, ip $ip_address, $family, $event_type")
    p := &Cbpair(cbval)
    p.cb(interface_name, ip_address, family, event_type, p.val)
}
struct Cbpair {
pub:
    cb fn(string, string, int, int, voidptr)
    val voidptr
}

// should block
pub fn run_ipmon(stop &int, cbfn fn(string, string, int, int, voidptr), cbval voidptr) {
    p := &Cbpair{ cb:cbfn, val: cbval }
    mon := create_ip_monitor_event(onip_change, p)
    assert mon!=nil
    defer { free_ip_monitor_event(mon) }
    
    rv := start_ip_monitor_event(mon)
    assert rv==0
    defer { stop_ip_monitor_event(mon) }
    
    for *stop==0 {
        rv = process_ip_events(mon, 100)
        if rv < 0 {
            s := get_monitor_event_error(mon).tosdup()
            dump(s)
            break
        }
        
        // idle here
        if rv == 1 {
            // no event timeout
        }
    }
    
    println("ipmon done")
}
