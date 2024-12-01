;; (require 'myemod)

(setq inhibit-startup-message t)
;; (setq global-tab-line-mode t)
;; (tab-line-mode)
(global-tab-line-mode)

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

(message (f-this-file))
