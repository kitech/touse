;; (require 'myemod)

;; (setq  toggle-debug-on-error t)
(show-paren-mode)
(setq inhibit-startup-message t)
(setq dired-kill-when-opening-new-dired-buffer t)
;; (setq global-tab-line-mode t)
;; (jit-lock-mode nil)
;; fix this https://github.com/Alexander-Miller/treemacs/issues/157
;; (jit-lock-debug-mode nil)
;; (tab-line-mode)
(global-tab-line-mode)
(setq  tab-line-exclude-modes nil)

(defun veopen-file-dialog()
  (interactive)
  (let ((last-nonmenu-event nil)
        (use-dialog-box t)
        (use-file-dialog t))
    (call-interactively #'find-file))
  )

(defun vehello()
  (interactive)
  (message "vehello^^^")
  )
;; (global-set-key (kbd "C-,") 'veopen-file-dialog)

(defun f-this-file ()
  "Return path to this file."
  (cond
   (load-in-progress load-file-name)
   ((and (boundp 'byte-compile-current-file) byte-compile-current-file)
    byte-compile-current-file)
   (:else (buffer-file-name))))

(defun load-file-samedir (file)
  (load-file   (expand-file-name file
                                 (file-name-directory
                                  (file-truename load-file-name)))))
(message (f-this-file))
(message user-emacs-directory)
(setq server-socket-dir "/run/user/1000/emacsv")
(server-start)


(add-to-list 'load-path "~/.emacs.d/handby")
;; (add-to-list 'load-path "~/aprog/mkuse/emacs")
;; (require 'lspmdx)
;; (load-file "lspmdx.el")
(load-file-samedir  "lspmdx.el")

;; (setq module-file-suffix ".emso")
;; (module-load "emdemo.so")
;; (load-file "emdemo.so")
(load-file-samedir  "emdemo.so")

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages '(company yasnippet lsp-mode hydra)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
