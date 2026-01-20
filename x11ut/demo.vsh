import os
import time

import vcp
import touse.x11ut


///
fn menu_clicked(cbval voidptr, checked bool) {
    vcp.info(cbval, checked)
}
fn run_byapi() {
    t := x11ut.Tray.new()
    t.init(nil)
    t.embed()

    m := t.newMenu()
    rv := m.add_item('firs发送ttt', menu_clicked, t)
    rv = m.add_item('firs发送222', menu_clicked, t)
    rv = m.add_item('firs发送333', menu_clicked, t)
    // vcp.info(rv)
    t.set_menu(m)
    
    t.set_tooltip('hehh发送ehe')
    // t.set_tooltip("")
    
    for {
        bv := t.process_events()
        time.sleep(123*time.millisecond)
    }
    m.cleanup()
    t.cleanup()
}

///
if abs0() { run_byapi() }
else {
    rv := x11ut.main_demo(os.args.len, vcp.vargs2cargs().data)
}
