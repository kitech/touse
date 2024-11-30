module emacs

import vcp

// symbol, lispsym
// sym2 := vcp.dlsym0('lispsym')
// vcp.info(sym2)

// v is derefed Value
pub fn islispobj(v voidptr) int {
	sym2 := vcp.dlsym0('valid_lisp_object_p')
	// vcp.info(sym2)
	fno2 := funcof(sym2, fn (_ voidptr) int {
		return 0
	})
	rv2 := fno2(voidptr(v))
	//	vcp.info(rv2)
	return rv2
}
