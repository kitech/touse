module oai


// 4B maybe emoji
pub fn is_noncjk_full(s string) bool {
    for r in s.runes() {
        if r.length_in_bytes() == 1 ||
            r.length_in_bytes() == 4 {
            }else{
                return false
            }
    }
    return true
}
