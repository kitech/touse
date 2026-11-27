// 动态加载入口：直接混编 opendal_dyn.c，不生成 .o，不改 C 源。
module opendal

import vcp.tcchf

#flag @DIR/opendal_dyn.o
//#include <@DIR/opendal_dyn.c>

fn C.opendal_dyn_libok() int
fn C.opendal_dyn_init(path &char) int
fn C.opendal_dyn_has_symbol(name &char) int
fn C.opendal_dyn_cleanup()

pub fn libok() bool {
	return C.opendal_dyn_libok() != 0
}

pub fn dyn_init(path string) int {
	return C.opendal_dyn_init(path.str)
}

pub fn has_symbol(name string) bool {
	return C.opendal_dyn_has_symbol(name.str) != 0
}

pub fn cleanup() {
	C.opendal_dyn_cleanup()
}
