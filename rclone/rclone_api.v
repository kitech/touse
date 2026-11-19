module rclone

import vcp.tcchf

#include <librclone.h>

// @[typedef]
struct C.RcloneRPCResult {
	Output &char
	Status int
}

pub struct RpcResult {
pub:
	status int
	output string
}

fn C.rclone_libok() int
pub fn libok() bool {
	return C.rclone_libok() != 0
}

fn C.rclone_dyn_init(library_path &char) int
pub fn dyn_init(library_path string) int {
	return C.rclone_dyn_init(library_path.str)
}

fn C.rclone_dyn_cleanup()
pub fn cleanup() {
	C.rclone_dyn_cleanup()
}

fn C.RcloneInitialize()
pub fn initialize() {
	C.RcloneInitialize()
}

fn C.RcloneFinalize()
pub fn finalize() {
	C.RcloneFinalize()
}

fn C.RcloneFreeString(s &char)
pub fn free_string(s &char) {
	C.RcloneFreeString(s)
}

fn C.RcloneRPC(method &char, input &char) C.RcloneRPCResult
pub fn rpc(method string, input string) RpcResult {
	r := C.RcloneRPC(method.str, input.str)
	mut out := ''
	if r.Output != unsafe { nil } {
		out = cstring_to_vstring(r.Output)
		C.RcloneFreeString(r.Output)
	}
	return RpcResult{ status: r.Status, output: out }
}
