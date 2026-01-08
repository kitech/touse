module hexrgb

// Test validation function
fn test_is_valid() {
    // Valid formats
    assert is_valid('#FFFFFF') == true
    assert is_valid('#FFF') == true
    assert is_valid('FFFFFF') == true
    assert is_valid('FFF') == true
    assert is_valid('#abcdef') == true
    assert is_valid('#ABCDEF') == true
    assert is_valid('#123') == true
    assert is_valid('123') == true
    assert is_valid('abc') == true
    assert is_valid('ABC') == true
    
    // Invalid formats
    assert is_valid('') == false
    assert is_valid('#') == false
    assert is_valid('#FF') == false
    assert is_valid('#FFFF') == false
    assert is_valid('#FFFFFFF') == false
    assert is_valid('#GGGGGG') == false
    assert is_valid('#12345G') == false
    assert is_valid('##FFFFFF') == false
    assert is_valid('12345') == false
    assert is_valid('12') == false
    
    println('✓ test_is_valid passed')
}

// Test hex to RGB conversion
fn test_to_rgb() {
    // Valid colors
    rgb1 := to_rgb('#FF0000') or { panic('Conversion failed') }
    assert rgb1.r == 255 && rgb1.g == 0 && rgb1.b == 0
    
    rgb2 := to_rgb('#F00') or { panic('Conversion failed') }
    assert rgb2.r == 255 && rgb2.g == 0 && rgb2.b == 0
    
    rgb3 := to_rgb('00FF00') or { panic('Conversion failed') }
    assert rgb3.r == 0 && rgb3.g == 255 && rgb3.b == 0
    
    rgb4 := to_rgb('#0000ff') or { panic('Conversion failed') }
    assert rgb4.r == 0 && rgb4.g == 0 && rgb4.b == 255
    
    rgb5 := to_rgb('#AbCdEf') or { panic('Conversion failed') }
    assert rgb5.r == 171 && rgb5.g == 205 && rgb5.b == 239
    
    rgb6 := to_rgb('808080') or { panic('Conversion failed') }
    assert rgb6.r == 128 && rgb6.g == 128 && rgb6.b == 128
    
    // Invalid colors should return error
    to_rgb('invalid') or { /* Expected error */ }
    to_rgb('#GGGGGG') or { /* Expected error */ }
    to_rgb('#12345') or { /* Expected error */ }
    
    println('✓ test_to_rgb passed')
}

// Test RGB to hex conversion
fn test_to_hex() {
    assert to_hex(RGB{255, 0, 0}) == '#FF0000'
    assert to_hex(RGB{0, 255, 0}) == '#00FF00'
    assert to_hex(RGB{0, 0, 255}) == '#0000FF'
    assert to_hex(RGB{128, 128, 128}) == '#808080'
    assert to_hex(RGB{0, 0, 0}) == '#000000'
    assert to_hex(RGB{255, 255, 255}) == '#FFFFFF'
    assert to_hex(RGB{42, 173, 217}) == '#2AADD9'
    assert to_hex(RGB{255, 165, 0}) == '#FFA500'
    
    println('✓ test_to_hex passed')
}

// Test convenience functions
fn test_convenience_functions() {
    // Test rgb_to_hex
    assert rgb_to_hex(255, 0, 0) == '#FF0000'
    assert rgb_to_hex(0, 255, 0) == '#00FF00'
    assert rgb_to_hex(0, 0, 255) == '#0000FF'
    
    // Test hex_to_rgb_components
    r, g, b := hex_to_rgb_components('#FF8040') or { panic('Failed') }
    assert r == 255 && g == 128 && b == 64
    
    println('✓ test_convenience_functions passed')
}

// Comprehensive test: full conversion cycle
fn test_full_conversion_cycle() {
    test_cases := [
        '#000000',
        '#FFFFFF',
        '#FF0000',
        '#00FF00',
        '#0000FF',
        '#808080',
        '#FFA500',  // Orange
        '#FF00FF',  // Magenta
        '#800080',  // Purple
        '#008080',  // Teal
    ]
    
    for hex in test_cases {
        rgb := to_rgb(hex) or { panic('Conversion failed: ${hex}') }
        converted_hex := to_hex(rgb)
        
        // Normalize expected hex (uppercase, expand shorthand)
        expected_hex := if hex.len == 4 {
            // Expand 3-digit to 6-digit format
            '#${hex[1].str().repeat(2)}${hex[2].str().repeat(2)}${hex[3].str().repeat(2)}'.to_upper()
        } else {
            hex.to_upper()
        }
        
        assert converted_hex == expected_hex
    }
    
    println('✓ test_full_conversion_cycle passed')
}

// Run all tests
fn test_all() {
    println('Running hexrgb tests...')
    
    test_is_valid()
    test_to_rgb()
    test_to_hex()
    test_convenience_functions()
    test_full_conversion_cycle()
    
    println('\n✅ All tests passed!')
}

fn main() {
    test_all()
}
// Total lines: 137
