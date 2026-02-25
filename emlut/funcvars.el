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

(defun veopen-file-dialog()
  (interactive)
  (let ((last-nonmenu-event nil)
        (use-dialog-box t)
        (use-file-dialog t))
    (call-interactively #'find-file))
  )

(defun update-scroll-bars ()
    (interactive)
    (mapc (lambda (win)
            (set-window-scroll-bars win nil))
          (window-list))
    ;; (message "%sx%s" (window-width (selected-window) t) (window-height (selected-window)))
    (if (and (> (window-width (selected-window) t) 500)
             (> (window-height (selected-window)) 15))
        (set-window-scroll-bars (selected-window) 7 'right)))

;; two step init/config logic
;
;; check package installed
; package installed hook
; if want require a package,
; first check if installed
; if not put to install list
;
; when init complete, check install list and install
; then, init/config newly installed package
