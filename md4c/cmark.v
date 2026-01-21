module md4c

#flag -lcmark

#include <cmark.h>

// char *cmark_markdown_to_html(const char *text, size_t len, int options);
fn C.cmark_markdown_to_html(...voidptr) charptr

pub fn tohtml_cmark(ipt string) !string {
    x := C.cmark_markdown_to_html(ipt.str, ipt.len, 0)
    return x.tosfree()
}
