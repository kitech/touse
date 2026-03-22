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

fn test_vstr() {
	ret := ffi.callany[int](voidptr(foo_prmin_str), '890')
	assert ret == 6

	s9 := ffi.callany[string](voidptr(foo_prmout_str))
	assert s9.len == 5
	assert s9 == '56789'

	s9 = ffi.callany[string](voidptr(foo_prminout_str), '890')
	assert s9.len == 6
	assert s9 == '890FOO'
}

/////////////

fn foo_prmin_arr(arr []int) int {
    res := 0
    for x in arr { res += x }
    return res
}

fn foo_prmout_arr() []int {
    res := []int{len:3}
    for i, x in res { res[i] = i }
    return res
}

fn foo_prminout_arr(arr []int) []int {
    res := []int{len: arr.len}
    for i, x in arr { res[i] = x + 1 }
    return res
}

fn test_varr() {
	ret := ffi.callany[int](voidptr(foo_prmin_arr), [1,2,3])
	assert ret == 6

	s9 := ffi.callany[[]int](voidptr(foo_prmout_arr))
	assert s9.len == 3
	assert s9 == [0,1,2]

	s9 = ffi.callany[[]int](voidptr(foo_prminout_arr), [1,2,3])
	assert s9.len == 3
	assert s9 == [2,3,4]

}
