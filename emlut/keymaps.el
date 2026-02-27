
(global-unset-key (kbd "C-s"))
(global-unset-key (kbd "C-r"))
(global-unset-key (kbd "C-f"))
(global-unset-key (kbd "C-z"))
(global-unset-key (kbd "C-d"))

(global-set-key (kbd "C-s") 'save-buffer)
(global-set-key (kbd "C-f") 'isearch-forward)
(define-key isearch-mode-map "\C-f" 'isearch-repeat-forward)
(global-set-key (kbd "C-r") 'replace-string)
(global-set-key (kbd "C-z") 'undo)
(global-set-key (kbd "s-w") 'kill-current-buffer)
(global-set-key (kbd "<f4>") 'delete-window)
(global-set-key (kbd "<f3>") 'split-window-below)
;; (global-set-key (kbd "<f2>") 'split-window-right)

;; but not update years https://github.com/kostafey/popup-switcher
(if (package-installed-p 'popup-switcher)
    (progn
      (global-set-key (kbd "C-<tab>") 'psw-switch-buffer)
      (global-set-key (kbd "C-<iso-lefttab>") 'psw-switch-buffer)
      )
  (global-set-key (kbd "C-<tab>") 'switch-to-next-buffer)
  (global-set-key (kbd "C-<iso-lefttab>") 'switch-to-prev-buffer)
)

(global-set-key (kbd "C-o") 'find-file)
(global-set-key (kbd "C-d") 'duplicate-line)
;; (global-set-key (kbd "C-c d") 'duplicate-line)
(global-set-key (kbd "C-/") 'comment-line)

; if has selected region, eval-region, else if at end, eval-last-expr
(defun eval-region-or-last ()
  (interactive)
  (if (region-active-p)
      (eval-region (region-beginning) (region-end))
    (if (eolp)
	(eval-last-sexp nil)
      (message "no region or line end")
      )
    )
  )
(global-set-key (kbd "<f5>") 'eval-region-or-last)

