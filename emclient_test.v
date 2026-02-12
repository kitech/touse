module emacs

import vcp
import time

fn test_1() {
	dump(MAJOR_VERION)
}

fn test_2() {
	btime := time.now()
	runon_uithread(fn (e &Env, args []Value) Value {
		vcp.info('ehehe', e.asptr())
		return emvs.eltrue
	}, true, 1.2, f32(123), 'abc', 42) or { panic(err) }
	vcp.info(time.since(btime).str())

	runon_uithread('prin1-to-string', false, 1.2) or { panic(err) }

	assert false
}
