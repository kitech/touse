module oai


// 4B maybe emoji, seem as cjk
pub fn is_noncjk_full(s string) bool {
    for r in s.runes() {
        if r.length_in_bytes() == 1 {
        } else if r.length_in_bytes() == 4 {
            return false
        } else {
            return false
        }
    }
    return true
}
