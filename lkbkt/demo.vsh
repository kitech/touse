// Run via `make v-check` from lkbkt/ (it builds liblkbkt.a and links it).

import lkbkt

mut b := lkbkt.bucket_new(10, 5, 0, 1024) or { panic('lkbkt_new: ${err}') }

// first request for a key is free (nginx semantics)
d1 := b.check('192.0.2.1', 1000)
assert d1.result == .pass
assert d1.delay_ms == 0

d2 := b.check('192.0.2.1', 1000)
assert d2.result == .delay
assert d2.delay_ms == 100

d3 := b.check('192.0.2.1', 1000)
assert d3.result == .delay
assert d3.delay_ms == 200

// fill up to burst
for _ in 0 .. 3 {
	b.check('192.0.2.1', 1000)
}

assert b.check('192.0.2.1', 1000).result == .reject
assert b.check('192.0.2.1', 2000).result == .pass

// idle + drained keys are expired after 60 s
assert b.expire(62000) == 1
assert b.size() == 0

b.free()
assert b.size() == 0

println('v: all checks passed')
