#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdint.h>
#include <stdbool.h>

/* Validate hexadecimal color string format */
bool hexrgb_is_valid(const char* hex) {
    if (!hex) return false;
    
    const char* start = hex;
    if (*start == '#') start++;
    
    size_t len = strlen(start);
    if (len != 3 && len != 6) return false;
    
    for (size_t i = 0; i < len; i++) {
        if (!isxdigit(start[i])) return false;
    }
    
    return true;
}

/* Convert hex color to RGB */
int hexrgb_to_rgb(const char* hex, uint8_t* r, uint8_t* g, uint8_t* b) {
    if (!hex || !r || !g || !b) return -1;
    if (!hexrgb_is_valid(hex)) return -1;
    
    const char* start = hex;
    if (*start == '#') start++;
    
    size_t len = strlen(start);
    
    if (len == 6) {
        char rr[3] = {start[0], start[1], '\0'};
        char gg[3] = {start[2], start[3], '\0'};
        char bb[3] = {start[4], start[5], '\0'};
        
        *r = (uint8_t)strtoul(rr, NULL, 16);
        *g = (uint8_t)strtoul(gg, NULL, 16);
        *b = (uint8_t)strtoul(bb, NULL, 16);
    } else {
        char rr[3] = {start[0], start[0], '\0'};
        char gg[3] = {start[1], start[1], '\0'};
        char bb[3] = {start[2], start[2], '\0'};
        
        *r = (uint8_t)strtoul(rr, NULL, 16);
        *g = (uint8_t)strtoul(gg, NULL, 16);
        *b = (uint8_t)strtoul(bb, NULL, 16);
    }
    
    return 0;
}

/* Convert RGB to hex color */
char* hexrgb_to_hex(uint8_t r, uint8_t g, uint8_t b, char* buffer, size_t size) {
    if (!buffer || size < 8) return NULL;
    snprintf(buffer, size, "#%02X%02X%02X", r, g, b);
    return buffer;
}
// Total lines: 78
