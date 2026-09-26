#ifndef BYTEUI_H
#define BYTEUI_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Full version functions
char* byteui_human_full(uint64_t bytes, char* buf, size_t buf_size, 
                       int use_si, int decimal_places);
char* byteui_human(uint64_t bytes, char* buf, size_t buf_size);

// Simple version functions
char* byteui_human_simple(uint64_t bytes, char* buf, size_t buf_size, 
                         int use_short_units);
char* byteui_human_short(uint64_t bytes, char* buf, size_t buf_size);

// Smart version
char* byteui_human_smart(uint64_t bytes, char* buf, size_t buf_size);

// Integer arithmetic version
char* byteui_human_int(uint64_t bytes, char* buf, size_t buf_size);

// Compact version (alias for integer version)
#define byteui_human_compact byteui_human_int

// Test function
void byteui_test(void);

#ifdef __cplusplus
}
#endif

#endif // BYTEUI_H
