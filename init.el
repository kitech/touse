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
(scroll-bar-mode 0)

(set-frame-font "Source Code Pro 12" nil t)
;; Older versions of Emacs 23.1
;; (set-default-font "Source Code Pro 13" nil t)

(defun update-scroll-bars ()
  (interactive)
  (mapc (lambda (win)
          (set-window-scroll-bars win nil))
        (window-list))
  ;; (message "%sx%s" (window-width (selected-window) t) (window-height (selected-window)))
  (if (and (> (window-width (selected-window) t) 500)
           (> (window-height (selected-window)) 15))
      (set-window-scroll-bars (selected-window) 7 'right)))

(add-hook 'window-configuration-change-hook 'update-scroll-bars)
(add-hook 'buffer-list-update-hook 'update-scroll-bars)

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
;; (load-file-samedir  "emjoplin.so")

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
