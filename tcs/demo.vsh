import touse.tcs

import os
import time
import vcp
import vcp.yco
import vcp.json

fn tcp_read_proc(c tcs.Socket) {
    defer { c.close() }
    buf := []u8{len: 1234}
    for {
        rn := c.read(buf) or {
            vcp.error(err.str())
            return
        }
        vcp.info("<< tcp ${c.str()}", rn, "|${buf[..rn].bytestr()}|")
        for i in 0..rn {
            // println(buf[i])
        }
        wn : c.write(buf[..rn]) or {
            vcp.error(err.str())
            return
        }
    }
}

fn udp_read_proc(c tcs.Socket) {
    vcp.info("udp reading ...")
    buf := []u8{len: 1234}
    for {
        rn, addr := c.read_from(buf) or { panic(err) }
        vcp.info("<< udp ${c.str()}", rn, buf[..rn].bytestr())
    }
    vcp.info("udp done")
}

fn tcp_accept_proc(lsnsk tcs.Socket) {
    for {
        c := lsnsk.accept() or { panic(err) }
        vcp.info("new income tcp conn", c)
        f := fn() { tcp_read_proc(c) }
        yco.gofy(f)
    }
}

lsnsktcp := tcs.listen("tcp://*:1716") !
lsnskudp := tcs.listen("udp://*:1716") !

yco.gofy(voidptr(fn(){ tcp_accept_proc(lsnsktcp) }))
yco.gofy(voidptr(fn(){ udp_read_proc(lsnskudp) }))

if abs1() {
    udpcli := tcs.newUdpSocket() !
    udpcli.write_to('hehehhe', '255.255.255.255:1716') !
}
if abs1() {
    udpcli := tcs.dial('udp://255.255.255.255:1716') !
    dump(udpcli.laddr2())
    dump(udpcli.raddr2())
    dump(udpcli.get_type2())
    udpcli.write('1234567') !
}

vcp.forever(12333)
