
; usage
; (add-to-list 'load-path "~/aprog/touse/emlut"))
; (require 'emlut)

(load "funcvars.el")
(load "sidebar-ctrlbar.el")
(load "wined-pkgman.el")
(load "configvars.el")
(load "switch-buffer.el")
(load "keymaps.el")
(run-with-idle-timer 2 nil #'load "locale-zh")

(provide 'emlut)
