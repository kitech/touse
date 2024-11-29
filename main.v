import vcp
import emacs

fn main() {
	vcp.info(int(emacs.MAJOR_VERION))
}

fn init() {
	emacs.reginiter(emuser_init)
}

fn emuser_init(e &emacs.Env) {
	vcp.info(e != vnil)

	e.add_hook('emacs-startup-hook', fn () {
		vcp.info('111', 'emacs-startup-hook cllaed')
	})
}
