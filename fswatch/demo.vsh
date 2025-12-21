import touse.fswatch

import vcp

fn on_fsev(evts []fswatch.Event, data voidptr) {
    for idx, e in evts {
        vcp.info("$idx/${evts.len}", data, e.str(), int(e.flags[0]), fswatch.flag_name(e.flags[0]))
    }
    assert fswatch.last_error() == fswatch.ok
}

rv := fswatch.init_library()
assert rv == fswatch.ok

h := fswatch.new()
vcp.info(h)
rv = h.add_callback(on_fsev, h)

rv = h.add_path('/tmp')

rv = h.start_monitor()
