module md4c

#flag -lmd4c-html
#include <md4c-html.h>

fn C.md_html(... voidptr) int

// int md_html(const MD_CHAR* input, MD_SIZE input_size,
            // void (*process_output)(const MD_CHAR*, MD_SIZE, void*),
            // void* userdata, unsigned parser_flags, unsigned renderer_flags);

struct Context {
    pub:
    res string
}
fn process_output(data charptr, len int, ctx &Context) {
    ctx.res += data.tosdup(len)
}

pub fn tohtml(ipt string) !string {
    ctx := &Context{}
    rv := C.md_html(ipt.str, ipt.len, process_output, ctx, 0, 0)
    if rv!=0 {
        return errorws('md parse error', rv)
    }
    return ctx.res
}
