import os
import time

import vcp
import touse.x11ut

///
fn run_byapi() {
    t := x11ut.Tray.new()
    t.init(nil)
    t.embed()
    m := t.newMenu()
    for {
        bv := t.process_events()
        time.sleep(123*time.millisecond)
    }
    m.cleanup()
    t.cleanup()
}

///
if abs1() { run_byapi() }
else {
    rv := x11ut.main_demo(os.args.len, vcp.vargs2cargs().data)
}
