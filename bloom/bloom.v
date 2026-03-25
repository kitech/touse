module bloom

// libbloom

#flag -DBLOOM_VERSION_MAJOR=2
#flag -DBLOOM_VERSION_MINOR=0
#flag -I @DIR/murmur2
#flag @DIR/bloom.o
#flag @DIR/murmur2/MurmurHash2.o
#flag -lm

#include "@DIR/bloom.h"

pub type Bloom = C.bloom
struct C.bloom {
    pub:
    bits usize
    bytes usize
}

// n [10000, 1000_000+]
// p [0.1, 0.001]
pub fn new(n usize, p f64) &Bloom{
    b := &Bloom{}
    if n == 0 { n = 1000000 }
    if p == 0 { p = 0.1 }
    C.bloom_init2(b, n, p)
    return b
}
pub fn (b &Bloom) freeit() {
    C.bloom_free(b)
}
pub fn (b &Bloom) add(s string) {
    C.bloom_add(b, s.str, s.len)
}
pub fn (b &Bloom) check(s string) bool {
    rv := C.bloom_check(b, s.str, s.len)
    return rv != 0
}

pub fn (b &Bloom) save(f string) bool {
    rv := C.bloom_save(b, f.str)
    return rv == 0
}
pub fn (b &Bloom) load(f string) bool {
    rv := C.bloom_load(b, f.str)
    return rv == 0
}


fn C.bloom_init2(...voidptr)
fn C.bloom_free(voidptr)
fn C.bloom_add(...voidptr)
fn C.bloom_check(...voidptr) int
fn C.bloom_save(...voidptr) int
fn C.bloom_load(...voidptr) int
