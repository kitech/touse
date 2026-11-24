module pathut

// Based on rclone lib/encoder: restricted ASCII characters are mapped to
// their FULLWIDTH equivalents, control characters to the SYMBOL FOR block,
// and a quote rune makes the mapping reversible.

const quote_rune = `‛`
const full_offset = rune(0xFEE0)
const sym_null = rune(0x2400) // ␀
const sym_space = rune(0x2420) // ␠
const sym_del = rune(0x247F)
const full_stop = rune(0xFF0E) // ．

fn is_restricted(c u8) bool {
	return c == `/` || c == `:` || c == `?` || c == `*` || c == `"` || c == `<` || c == `>`
		|| c == `|` || c == `#` || c == `%` || c == 92
}

fn is_replacement(r rune) bool {
	if r == quote_rune || r == sym_space || r == sym_del || r == full_stop {
		return true
	}
	if r >= sym_null && r <= rune(0x241F) {
		return true
	}
	ur := u32(r)
	base := u32(full_offset)
	if ur >= base && ur <= base + 0x7E {
		return is_restricted(u8(ur - base))
	}
	return false
}

// safe_encode turns one name into a safe single path segment.
// It never emits '/', so the result is always one segment.
pub fn safe_encode(name string) string {
	if name == '' {
		return ''
	}
	if name == '.' {
		return '${full_stop}'
	}
	if name == '..' {
		return '${full_stop}${full_stop}'
	}

	rs := name.runes()
	mut out := []rune{}
	mut start := 0
	mut end := rs.len

	if rs[0] == rune(0x20) {
		out << sym_space
		start = 1
	} else if rs[0] == rune(0x2E) {
		out << full_stop
		start = 1
	}

	mut suffix := []rune{}
	if end > start {
		if rs[end - 1] == rune(0x20) {
			suffix << sym_space
			end--
		} else if rs[end - 1] == rune(0x2E) {
			suffix << full_stop
			end--
		}
	}

	for i := start; i < end; i++ {
		r := rs[i]
		if is_replacement(r) {
			out << quote_rune
		}
		ur := u32(r)
		if ur < 0x20 {
			out << rune(u32(sym_null) + ur)
		} else if r == rune(0x7F) {
			out << sym_del
		} else if ur < 0x80 && is_restricted(u8(ur)) {
			out << rune(ur + u32(full_offset))
		} else {
			out << r
		}
	}
	for r in suffix {
		out << r
	}
	return out.string()
}

// safe_decode reverses safe_encode.
pub fn safe_decode(name string) string {
	if name == '' {
		return ''
	}
	if name == '${full_stop}' {
		return '.'
	}
	if name == '${full_stop}${full_stop}' {
		return '..'
	}

	rs := name.runes()
	mut out := []rune{}
	mut i := 0
	for i < rs.len {
		r := rs[i]
		if r == quote_rune {
			if i + 1 < rs.len {
				out << rs[i + 1]
				i += 2
			} else {
				out << r
				i++
			}
			continue
		}
		ur := u32(r)
		base := u32(full_offset)
		if r == sym_space {
			out << rune(0x20)
		} else if r >= sym_null && r <= rune(0x241F) {
			out << rune(ur - u32(sym_null))
		} else if r == sym_del {
			out << rune(0x7F)
		} else if r == full_stop {
			out << rune(0x2E)
		} else if ur >= base && ur <= base + 0x7E && is_restricted(u8(ur - base)) {
			out << rune(ur - base)
		} else {
			out << r
		}
		i++
	}
	return out.string()
}
