module pathut

fn has_restricted(s string) bool {
	for c in s.bytes() {
		if is_restricted(c) {
			return true
		}
	}
	return false
}

fn test_safe_encode() {
	assert safe_encode('') == ''
	assert safe_encode('normal.txt') == 'normal.txt'
	assert !has_restricted(safe_encode('a:b?c*d"e<f>g|h#i%j\\k/l'))
	assert safe_encode('.') == '${full_stop}'
	assert safe_encode('..') == '${full_stop}${full_stop}'
	assert safe_encode('.hidden').starts_with('${full_stop}')
	assert safe_encode('trail.').ends_with('${full_stop}')
	assert safe_encode(' a ').starts_with('${sym_space}')
	assert safe_encode(' a ').ends_with('${sym_space}')
	assert safe_encode('中文') == '中文'
}

fn test_safe_decode() {
	assert safe_decode('') == ''
	assert safe_decode('${full_stop}') == '.'
	assert safe_decode('${full_stop}${full_stop}') == '..'
	assert safe_decode('a：b？c＊d＂e＜f＞g｜h＃i％j＼k／l') == 'a:b?c*d"e<f>g|h#i%j\\k/l'
	assert safe_decode('${sym_space}a${sym_space}') == ' a '
}

fn test_safe_roundtrip() {
	names := [
		'normal.txt',
		'a:b?c*d"e<f>g|h#i%j\\k/l',
		'中文',
		'emoji-😀',
		'.hidden',
		'trail.',
		' a ',
		'.',
		'..',
		'a..b',
		'a.c1_1_of_2',
		'：already',
		'‛quoted',
		'␠literal',
		'control\x01',
		'del\x7f',
		'x Ｙ z',
	]
	for name in names {
		encoded := safe_encode(name)
		assert !has_restricted(encoded), 'restricted char leaked: ${name} -> ${encoded}'
		assert safe_decode(encoded) == name, 'roundtrip failed: ${name} -> ${encoded} -> ${safe_decode(encoded)}'
	}
}
