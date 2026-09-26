#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <math.h>

/**
 * Full version: Convert bytes to human-readable string
 * Supports: B, KiB, MiB, GiB, TiB, PiB, EiB (binary prefixes)
 *
 * @param bytes Number of bytes
 * @param buf Output buffer
 * @param buf_size Size of output buffer
 * @param use_si Use SI units (1000-based) instead of binary (1024-based)
 * @param decimal_places Number of decimal places (0-3)
 * @return Pointer to buf, NULL on failure
 */
char* byteut_human_full(uint64_t bytes, char* buf, size_t buf_size, 
                       int use_si, int decimal_places) {
    if (!buf || buf_size < 16) {
        return NULL;
    }
    
    static const char* units_si[] = {"B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"};
    static const char* units_iec[] = {"B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB"};
    
    const char** units = use_si ? units_si : units_iec;
    uint64_t divisor = use_si ? 1000 : 1024;
    
    if (bytes == 0) {
        snprintf(buf, buf_size, "0 B");
        return buf;
    }
    
    int unit_index = 0;
    double value = (double)bytes;
    
    while (value >= divisor && unit_index < 8) {
        value /= divisor;
        unit_index++;
    }
    
    // Limit decimal places
    if (decimal_places < 0) decimal_places = 0;
    if (decimal_places > 3) decimal_places = 3;
    
    // Check if decimal part is zero
    double integer_part;
    double fractional_part = modf(value, &integer_part);
    
    // Determine format based on decimal places and zero decimal
    if (fabs(fractional_part) < 0.0005 && decimal_places > 0) {
        // Decimal part is effectively zero, use integer format
        snprintf(buf, buf_size, "%.0lf %s", integer_part, units[unit_index]);
    } else {
        // Use specified decimal places
        const char* format;
        switch (decimal_places) {
            case 0: format = "%.0lf %s"; break;
            case 1: format = "%.1lf %s"; break;
            case 2: format = "%.2lf %s"; break;
            case 3: format = "%.3lf %s"; break;
            default: format = "%.1lf %s"; break;
        }
        snprintf(buf, buf_size, format, value, units[unit_index]);
    }
    
    return buf;
}

/**
 * Full version with default parameters (binary units, 1 decimal place)
 */
char* byteut_human(uint64_t bytes, char* buf, size_t buf_size) {
    return byteut_human_full(bytes, buf, buf_size, 0, 1);
}

/**
 * Simple version: Convert bytes to compact x.yM format
 * Only shows highest unit, omits decimal when zero
 *
 * @param bytes Number of bytes
 * @param buf Output buffer
 * @param buf_size Size of output buffer
 * @param use_short_units Use short units (K/M/G) instead of long (KB/MB/GB)
 * @return Pointer to buf, NULL on failure
 */
char* byteut_human_simple(uint64_t bytes, char* buf, size_t buf_size, 
                         int use_short_units) {
    if (!buf || buf_size < 16) {
        return NULL;
    }
    
    static const char* units_long[] = {"B", "KB", "MB", "GB", "TB", "PB", "EB"};
    static const char* units_short[] = {"B", "K", "M", "G", "T", "P", "E"};
    
    const char** units = use_short_units ? units_short : units_long;
    const uint64_t divisor = 1024;
    
    if (bytes == 0) {
        snprintf(buf, buf_size, "0B");
        return buf;
    }
    
    // Less than 1K: display as integer B
    if (bytes < divisor) {
        snprintf(buf, buf_size, "%lluB", (unsigned long long)bytes);
        return buf;
    }
    
    int unit_index = 0;
    double value = (double)bytes;
    
    while (value >= divisor && unit_index < 6) {
        value /= divisor;
        unit_index++;
    }
    
    // Check if decimal part is zero (consider floating point error)
    double integer_part;
    double fractional_part = modf(value, &integer_part);
    
    if (fabs(fractional_part) < 0.05) {
        // Integer format (no decimal)
        snprintf(buf, buf_size, "%.0lf%s", integer_part, units[unit_index]);
    } else {
        // One decimal place
        snprintf(buf, buf_size, "%.1lf%s", value, units[unit_index]);
    }
    
    return buf;
}

/**
 * Simple version with default parameters (short units)
 */
char* byteut_human_short(uint64_t bytes, char* buf, size_t buf_size) {
    return byteut_human_simple(bytes, buf, buf_size, 1);
}

/**
 * Smart version: Intelligent formatting with auto-adjusted precision
 * Omits decimal when zero, adjusts decimal places based on magnitude
 *
 * @param bytes Number of bytes
 * @param buf Output buffer
 * @param buf_size Size of output buffer
 * @return Pointer to buf, NULL on failure
 */
char* byteut_human_smart(uint64_t bytes, char* buf, size_t buf_size) {
    if (!buf || buf_size < 16) {
        return NULL;
    }
    
    static const char* units[] = {"B", "K", "M", "G", "T", "P", "E"};
    const uint64_t divisor = 1024;
    
    if (bytes == 0) {
        snprintf(buf, buf_size, "0B");
        return buf;
    }
    
    if (bytes < divisor) {
        snprintf(buf, buf_size, "%lluB", (unsigned long long)bytes);
        return buf;
    }
    
    int unit_index = 0;
    double value = (double)bytes;
    
    while (value >= divisor && unit_index < 6) {
        value /= divisor;
        unit_index++;
    }
    
    // Check decimal part
    double integer_part;
    double fractional_part = modf(value, &integer_part);
    
    // Smart formatting based on magnitude and decimal part
    if (fabs(fractional_part) < 0.05) {
        // Decimal part effectively zero, use integer format
        snprintf(buf, buf_size, "%.0lf%s", integer_part, units[unit_index]);
    } else if (value >= 100) {
        // 100 or more: no decimal (but keep 1 decimal if not exactly zero)
        if (fabs(fractional_part) < 0.05) {
            snprintf(buf, buf_size, "%.0lf%s", integer_part, units[unit_index]);
        } else {
            snprintf(buf, buf_size, "%.1lf%s", value, units[unit_index]);
        }
    } else if (value >= 10) {
        // 10-99: 1 decimal place
        snprintf(buf, buf_size, "%.1lf%s", value, units[unit_index]);
    } else {
        // 1-9.9: check if 2 decimal places needed
        double fractional_part_two = fractional_part * 100;
        int int_fractional = (int)round(fractional_part_two);
        
        if (int_fractional % 10 == 0) {
            // Second decimal digit is zero, only need 1 decimal
            snprintf(buf, buf_size, "%.1lf%s", value, units[unit_index]);
        } else {
            // Need 2 decimal places
            snprintf(buf, buf_size, "%.2lf%s", value, units[unit_index]);
        }
    }
    
    return buf;
}

/**
 * Integer arithmetic version: Avoid floating point errors
 * Omit decimal when zero, uses integer-only calculations
 *
 * @param bytes Number of bytes
 * @param buf Output buffer
 * @param buf_size Size of output buffer
 * @return Pointer to buf, NULL on failure
 */
char* byteut_human_int(uint64_t bytes, char* buf, size_t buf_size) {
    if (!buf || buf_size < 16) {
        return NULL;
    }
    
    static const char* units[] = {"B", "K", "M", "G", "T", "P", "E"};
    const uint64_t divisor = 1024;
    
    if (bytes == 0) {
        snprintf(buf, buf_size, "0B");
        return buf;
    }
    
    if (bytes < divisor) {
        snprintf(buf, buf_size, "%lluB", (unsigned long long)bytes);
        return buf;
    }
    
    int unit_index = 0;
    uint64_t scaled = bytes;
    
    while (scaled >= divisor && unit_index < 6) {
        scaled /= divisor;
        unit_index++;
    }
    
    // Calculate decimal part using integer arithmetic
    uint64_t remainder = bytes;
    for (int i = 0; i < unit_index; i++) {
        remainder %= divisor;
        if (i < unit_index - 1) {
            remainder *= divisor;
        }
    }
    
    // Calculate one decimal digit (rounded)
    int decimal = (int)((remainder * 10 + divisor / 2) / divisor);
    
    if (decimal == 0) {
        // No decimal part
        snprintf(buf, buf_size, "%llu%s", (unsigned long long)scaled, units[unit_index]);
    } else if (decimal == 10) {
        // Rounded up, carry over to integer part
        snprintf(buf, buf_size, "%llu%s", (unsigned long long)scaled + 1, units[unit_index]);
    } else {
        // Normal decimal
        snprintf(buf, buf_size, "%llu.%d%s", 
                (unsigned long long)scaled, decimal, units[unit_index]);
    }
    
    return buf;
}

/**
 * Compact version: Minimal x.yM format with integer arithmetic
 * Omit decimal when zero, always use short units
 *
 * @param bytes Number of bytes
 * @param buf Output buffer
 * @param buf_size Size of output buffer
 * @return Pointer to buf, NULL on failure
 */
char* byteut_human_compact(uint64_t bytes, char* buf, size_t buf_size) {
    return byteut_human_int(bytes, buf, buf_size);
}


//////////////////

/**
 * Test function for byteut_human* functions
 */
void byteut_test(void) {
    char buf[32];
    
    printf("Full version (binary units):\n");
    uint64_t test_values[] = {0, 1, 512, 1023, 1024, 1536, 1048576, 1073741824, 1099511627776ULL};
    
    for (size_t i = 0; i < sizeof(test_values)/sizeof(test_values[0]); i++) {
        byteut_human(test_values[i], buf, sizeof(buf));
        printf("%20llu -> %s\n", test_values[i], buf);
    }
    
    printf("\nSimple version (short units):\n");
    for (size_t i = 0; i < sizeof(test_values)/sizeof(test_values[0]); i++) {
        byteut_human_short(test_values[i], buf, sizeof(buf));
        printf("%20llu -> %s\n", test_values[i], buf);
    }
    
    printf("\nSmart version:\n");
    for (size_t i = 0; i < sizeof(test_values)/sizeof(test_values[0]); i++) {
        byteut_human_smart(test_values[i], buf, sizeof(buf));
        printf("%20llu -> %s\n", test_values[i], buf);
    }
    
    printf("\nInteger arithmetic version:\n");
    for (size_t i = 0; i < sizeof(test_values)/sizeof(test_values[0]); i++) {
        byteut_human_int(test_values[i], buf, sizeof(buf));
        printf("%20llu -> %s\n", test_values[i], buf);
    }
    
    // Test exact values (no decimal)
    printf("\nExact value tests (should show no decimal):\n");
    uint64_t exact_values[] = {1024, 2048, 4096, 1048576, 1073741824, 1099511627776ULL};
    
    for (size_t i = 0; i < sizeof(exact_values)/sizeof(exact_values[0]); i++) {
        byteut_human_int(exact_values[i], buf, sizeof(buf));
        printf("%20llu -> %s\n", exact_values[i], buf);
    }
}


#ifdef BYTEUT_MAIN_DEMO
int main() {
    byteut_test();    
    return 0;
}
#endif
