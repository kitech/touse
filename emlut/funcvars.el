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

(add-hook 'window-configuration-change-hook 'update-scroll-bars)
(add-hook 'buffer-list-update-hook 'update-scroll-bars)

(defun my-server-start ()
  (require 'server)
  (message server-socket-dir)
  (if (file-exists-p (concat server-socket-dir "/server"))
      (progn
	(message "File %s already exists" server-socket-dir)
	(setq server-socket-dir (concat server-socket-dir ".2"))
	))
  ;; (setq server-socket-dir (concat server-socket-dir ".2"))
  ;; (setq server-socket-dir "/run/user/1000/emacsv")
  (server-start)
  )

(add-hook 'window-setup-hook 'my-server-start)


(defun return-file-buffers ()
  (let ((bufs)
        (buffers (buffer-list)))
    (dolist (buf buffers)
      (when (buffer-file-name buf)
        (push buf bufs)))
    bufs))


(defun fixed-return-file-buffers ()
  (let* ((old-buffers (window-parameter nil 'tab-line-buffers))
         (buffer-positions (let ((index-table (make-hash-table :test 'eq)))
                             (seq-do-indexed
                              (lambda (buf idx) (puthash buf idx index-table))
                              old-buffers)
                             index-table))
         (new-buffers (sort (return-file-buffers)
                            :key (lambda (buffer)
                                   (gethash buffer buffer-positions
                                            most-positive-fixnum)))))
    (set-window-parameter nil 'tab-line-buffers new-buffers)
    new-buffers))

;; (setq tab-line-tabs-function #'buffer-list)
(setq tab-line-tabs-function 'fixed-return-file-buffers)

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

