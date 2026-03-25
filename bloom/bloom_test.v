
import bloom

fn test_1() {
    b := bloom.new(0, 0)
    b.add('foo')
    assert b.check('foo')
    assert !b.check('bar')

    dump(b)
    b.freeit()
}
