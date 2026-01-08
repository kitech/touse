#ifndef HEXRGB_H
#define HEXRGB_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

bool hexrgb_is_valid(const char* hex);
int hexrgb_to_rgb(const char* hex, uint8_t* r, uint8_t* g, uint8_t* b);
char* hexrgb_to_hex(uint8_t r, uint8_t g, uint8_t b, char* buffer, size_t size);

#ifdef __cplusplus
}
#endif

#endif
// Total lines: 18
