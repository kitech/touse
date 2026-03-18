module idtico


#flag -lpng
#flag @DIR/md5.o
#flag @DIR/identicon.o

#include "@DIR/identicon.h"

fn C.identicon_generate(idstr charptr, filename charptr) int
fn C.identicon_generate_to_buffer(idstr charptr, out_buf &charptr, out_len &usize) int

// return fliename
pub fn generate(idstr string, filename string) !string {
    rv := C.identicon_generate(idstr.str, filename.str)
    assert rv == 0
    return filename
}
