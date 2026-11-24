// 运行：v run opendal/demo.vsh（从仓库根执行）
import opendal

if !opendal.libok() && opendal.dyn_init('') != 0 {
	println('SKIP: libopendal_c not available')
	return
}

mut op := opendal.Operator.new('memory', none, none) or { panic('new failed') }
defer { op.free() }

op.write('hello.txt', 'hello'.bytes(), none) or { panic('write failed') }
data := op.read('hello.txt', none) or { panic('read failed') }
assert data == 'hello'.bytes()

mut meta := op.stat('hello.txt', none) or { panic('stat failed') }
defer { meta.free() }
assert meta.content_length() == 5
assert meta.is_file()

mut lister := op.list('/', none) or { panic('list failed') }
defer { lister.free() }
mut count := 0
for {
	mut entry := lister.next() or { panic('next failed') }
	if entry.is_none() { break }
	_ = entry.name()
	_ = entry.path()
	entry.free()
	count++
}
assert count >= 1

assert op.exists('hello.txt') or { false }
op.delete('hello.txt', none) or { panic('delete failed') }
assert !(op.exists('hello.txt') or { false })

println('opendal: all checks passed')
