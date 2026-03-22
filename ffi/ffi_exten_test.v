// module ffi

import ffi

fn foo_prmin_str(s string) int {
	return (s + 'FOO').len
}

fn foo_prmout_str() string {
	return '56789'
}

fn foo_prminout_str(s string) string {
	return s + 'FOO'
}

fn test_2() {
	ret := ffi.callany[int](voidptr(foo_prmin_str), '890')
	assert ret == 6
	
	s9 := ffi.callany[string](voidptr(foo_prmout_str))
	assert s9.len == 5
	assert s9 == '56789'
	
	s9 = ffi.callany[string](voidptr(foo_prminout_str), '890')
	assert s9.len == 6
	assert s9 == '890FOO'
}
