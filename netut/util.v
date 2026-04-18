module netut

pub fn ip_islan4(ip string) bool {
    if ip.starts_with('192.') ||
        ip.starts_with('172.') ||
        ip.starts_with('10.') {
            return true
        }
    return false
}
