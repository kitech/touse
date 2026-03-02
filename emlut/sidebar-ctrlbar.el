;;;;;

(defvar my-ctrlbar-bufname "")
(setq my-ctrlbar-bufname "*sidebar-ctrlbar*")

(defun my-side-ctrlbar-switch-to (which)
  "Display the last 300 input events."
  (interactive)
  ;; (message (format "swito %s" which))
  (let ((sdlst (list "Treemacs-Buffer" "LSP Symbols" "Maagit")))
    (dolist (name sdlst)
      (let ((w (my-find-window-by-name name)))
	(message (format "%s %s" name w))
	(if w
	    (progn
	      (with-current-buffer (get-buffer (window-buffer w))
		(tab-line-mode -1)
		(setq header-line-format nil)
		(setq mode-line-format nil))
	      ;; (select-window w)
	      )
	  )
	)
      )
    )
  (let ((w (my-find-window-by-name which)))
    (if w
	(progn
	  (maximize-window w)
	  ;; (window-resize w 20)
	  )
      (message (format "w nil %s" which))
      ))
  )

(defun my-side-ctrlbar-switch-treemacs ()
  (interactive)
  (my-side-ctrlbar-switch-to "Treemacs-Buffer"))
(defun my-side-ctrlbar-switch-lspsyms ()
  (interactive)
  (my-side-ctrlbar-switch-to "LSP Symbols"))
(defun my-side-ctrlbar-switch-git ()
  (interactive)
  (my-side-ctrlbar-switch-to "Maagit"))

(defconst my-mode-line-map-treemacs
  (let ((map (make-sparse-keymap)))
    ;; Bind left mouse click to your function
    (define-key map [mode-line down-mouse-1] 'my-side-ctrlbar-switch-treemacs)
    map))

(defconst my-mode-line-button-treemacs
  (propertize " TM "
              'local-map my-mode-line-map-treemacs
               'mouse-face 'mode-line-highlight
              'help-echo "Switch treemacs view"))

(defconst my-mode-line-map-lspsyms
  (let ((map (make-sparse-keymap)))
    ;; Bind left mouse click to your function
    (define-key map [mode-line down-mouse-1] 'my-side-ctrlbar-switch-lspsyms)
    map))

(defconst my-mode-line-button-lspsyms
  (propertize " Syms "
              'local-map my-mode-line-map-lspsyms
              'mouse-face 'mode-line-highlight
              'help-echo "Switch LSP Symbols view"))

(defconst my-mode-line-map-git
  (let ((map (make-sparse-keymap)))
    ;; Bind left mouse click to your function
    (define-key map [mode-line down-mouse-1] 'my-side-ctrlbar-switch-git)
    map))

(defconst my-mode-line-button-git
  (propertize " Git "
              'local-map my-mode-line-map-git
              'mouse-face 'mode-line-highlight
              'help-echo "Switch Git view"))


;; 999 for most bottom
;; (display-buffer-in-side-window (get-buffer "*Messages*") '((side . left) (slot . 999)))

(defun my-side-ctrlbar-init ()
  (interactive)
  
  (display-buffer-in-side-window
   (get-buffer-create my-ctrlbar-bufname)
   '((side . left) (slot . 999)))
  (with-current-buffer (get-buffer-create my-ctrlbar-bufname)
    (setq cursor-type nil)
    (setq mode-line-format
	  (list my-mode-line-button-treemacs
		my-mode-line-button-lspsyms my-mode-line-button-git))
    (read-only-mode t)
    (tab-line-mode -1))

  ;; my ctrlbar window config
  ;; no cursor, readonly, min height
  (let ((w (my-find-window-by-name my-ctrlbar-bufname)))
    (select-window w)
    (set-window-dedicated-p w nil)
    (set-window-parameter w 'no-delete-other-windows t)

    (minimize-window w)
    )
  (next-window-any-frame)
  ;;(my-side-ctrlbar-switch-treemacs)
  )

;; (my-side-ctrlbar-init)
;; (add-hook 'window-setup-hook 'my-side-ctrlbar-init)
