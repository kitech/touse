
;; (global-unset-key (kbd "C-s"))
(global-unset-key (kbd "C-r"))
(global-unset-key (kbd "C-f"))
(global-unset-key (kbd "C-z"))

;; (global-set-key (kbd "C-s") 'save-buffer)
(global-set-key (kbd "C-f") 'isearch-forward)
(global-set-key (kbd "C-r") 'replace-string)
(global-set-key (kbd "C-z") 'undo)

(global-set-key (kbd "C-<tab>") 'switch-to-next-buffer)
(global-set-key (kbd "C-<iso-lefttab>") 'switch-to-prev-buffer)
(global-set-key (kbd "C-o") 'find-file)
(global-set-key (kbd "C-c d") 'duplicate-line)
(global-set-key (kbd "C-/") 'comment-line)


