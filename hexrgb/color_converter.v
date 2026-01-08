module hexrgb

// Link C object file
#flag @DIR/hexrgb.o

// Use @[importc] to map C functions directly
@[importc: 'hexrgb_is_valid']
fn is_valid_raw(hex &char) bool

@[importc: 'hexrgb_to_rgb']
fn to_rgb_raw(hex &char, r &u8, g &u8, b &u8) int

@[importc: 'hexrgb_to_hex']
fn to_hex_raw(r u8, g u8, b u8, buffer &char, size usize) &char

// RGB structure
pub struct RGB {
pub:
    r u8
    g u8
    b u8
}

// Validate hexadecimal color string
pub fn is_valid(hex string) bool {
    return is_valid_raw(hex.str)
}

// Convert hex color to RGB
pub fn to_rgb(hex string) !RGB {
    mut r := u8(0)
    mut g := u8(0)
    mut b := u8(0)
    
    if to_rgb_raw(hex.str, &r, &g, &b) == 0 {
        return RGB{r, g, b}
    }
    return error('Invalid color format: ${hex}')
}

// Convert RGB to hex color
pub fn to_hex(rgb RGB) string {
    mut buffer := [8]u8{}
    to_hex_raw(rgb.r, rgb.g, rgb.b, &char(buffer), 8)
    return unsafe { buffer[0..7].bytestr() }
}

// Convenience function: get hex from individual components
pub fn rgb_to_hex(r u8, g u8, b u8) string {
    return to_hex(RGB{r, g, b})
}

// Convenience function: get individual components from hex
pub fn hex_to_rgb_components(hex string) !(u8, u8, u8) {
    rgb := to_rgb(hex)!
    return rgb.r, rgb.g, rgb.b
}
// Total lines: 55
