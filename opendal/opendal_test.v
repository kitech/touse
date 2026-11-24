import touse.opendal

fn test_opendal_basic() {
	if !opendal.libok() && opendal.dyn_init('') != 0 {
		println('SKIP: libopendal_c not available')
		return
	}
	mut op := opendal.Operator.new('memory', none, none) or { panic('new failed') }
	defer { op.free() }

	op.write('a/b.txt', 'abc'.bytes(), none) or { panic('write failed') }
	assert (op.read('a/b.txt', none) or { []u8{} }) == 'abc'.bytes()
	assert op.is_exist('a/b.txt') or { false }
	assert !(op.is_exist('missing') or { true })

	mut m := op.stat('a/b.txt', none) or { panic('stat failed') }
	defer { m.free() }
	assert m.content_length() == 3

	mut ro := opendal.ReadOptions{}
	ro.init() or { panic('ro init failed') }
	defer { ro.free() }
	ro.set_range(1, 1)
	assert (op.read('a/b.txt', ro) or { []u8{} }) == 'b'.bytes()

	mut info := op.info() or { panic('info failed') }
	defer { info.free() }
	if info.capability().rename {
		op.rename('a/b.txt', 'a/c.txt') or { panic('rename failed') }
		assert !(op.is_exist('a/b.txt') or { true })
		assert op.is_exist('a/c.txt') or { false }
	}
}
