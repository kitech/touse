
;(setq debug-on-quit t)
;; (setq  toggle-debug-on-error t)
;; Disable automatic native compilation
(setq inhibit-automatic-native-compilation t)
(show-paren-mode)
(setq inhibit-startup-message t)
(setq dired-kill-when-opening-new-dired-buffer t)
;; (setq global-tab-line-mode t)
;; (jit-lock-mode nil)
;; fix this https://github.com/Alexander-Miller/treemacs/issues/157
;; (jit-lock-debug-mode nil)
;; (tab-line-mode)

; hide title bar and enable resize
(setq default-frame-alist '((undecorated . t)))
(add-to-list 'default-frame-alist '(drag-internal-border . 1))
(add-to-list 'default-frame-alist '(internal-border-width . 5))

(global-tab-line-mode)
(setq  tab-line-exclude-modes nil)
(scroll-bar-mode 0) ; todo auto show/hide scroll bar

;; Automatically save and restore sessions
; remove desktop-saved-frameset, nouse and slow startup
(setq desktop-restore-frames nil)
(setq desktop-dirname             user-emacs-directory
; (setq desktop-dirname             "~/.emacs.d/desktop/"
      desktop-base-file-name      "emacs.desktop"
      desktop-base-lock-name      "lock"
      desktop-path                (list desktop-dirname)
      desktop-save                t
      desktop-files-not-to-save   "^$" ;reload tramp paths
      desktop-load-locked-desktop nil
      desktop-auto-save-timeout   30)
(defun my-desktop ()
  "Load the desktop and enable autosaving"
  (interactive)
  (let ((desktop-load-locked-desktop "ask"))
    (desktop-read)
    ;; (setq desktop-saved-frameset [])
    (desktop-save-mode 1)))
;; (my-desktop)
; (desktop-save-mode 1)
(add-hook 'window-setup-hook 'my-desktop)

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))

(set-frame-font "Source Code Pro 12" nil t)
;; Older versions of Emacs 23.1
;; (set-default-font "Source Code Pro 13" nil t)
(custom-set-faces
 ;; set the default text and background colors
 '(default ((t (:foreground "#DCDCCC" :background "#1C1C1C"))))
 ;; set colors for comments
 '(font-lock-comment-face ((t (:foreground "#7F9F7F"))))
 ;; set colors for keywords (like 'if', 'for', etc.)
 '(font-lock-keyword-face ((t (:foreground "#FC5555"))))
 ;; set colors for string literals
 '(font-lock-string-face ((t (:foreground "#CC9393"))))
)

;; menu bar and tool bar theme
(set-face-attribute 'menu nil :background "#1C1C1C" :foreground "#DCDCCC" :bold t)
(set-face-attribute 'tool-bar nil :background "#1C1C1C" :foreground "#DCDCCC" :bold t)
(when (member "Segoe UI Emoji" (font-family-list))
  (set-fontset-font
    t 'symbol (font-spec :family "Segoe UI Emoji") nil 'prepend))

; (setq initial-frame-alist '((width . 120) (height . 32)))
(setq initial-frame-alist '((top . 0) (left . 90) (width . 120) (height . 32)))
; (add-to-list 'initial-frame-alist '(fullscreen . maximized))


;; todo put to menubar tail
(defun my-custom-command ()
  "A custom command for demonstration."
  (interactive)
  (message "Hello, world!"))

(require 'easymenu)
; (easy-menu-add-item global-map '("Tools")
;                     '("My Custom Command" . my-custom-command)
;                     "Version Control")
(defvar my-menu-bar-menu-devin (make-sparse-keymap "Devin"))
(define-key-after global-map [menu-bar my-menu-devin] (cons "Devin" my-menu-bar-menu-devin ) 'Tools)
(define-key my-menu-bar-menu-devin [my-cmd1] '("GC Collect" . my-custom-command))
(define-key my-menu-bar-menu-devin [my-cmd2] '("Inspect Fn" . my-custom-command))
(define-key my-menu-bar-menu-devin [my-cmd3] '("My Command 3" . my-custom-command))

(defvar my-menu-bar-menu1 (make-sparse-keymap "Mine1"))
(define-key-after global-map [menu-bar my-menu1] (cons "Mine1" my-menu-bar-menu1) 'Tools)
(define-key my-menu-bar-menu1 [my-cmd1] '("My Command 1" . my-custom-command))
(define-key my-menu-bar-menu1 [my-cmd2] '("My Command 2" . my-custom-command))
(define-key my-menu-bar-menu1 [my-cmd3] '("My Command 3" . my-custom-command))

(defvar my-menu-bar-menu2 (make-sparse-keymap "Mine2"))
(define-key-after global-map [menu-bar my-menu2] (cons "Mine2" my-menu-bar-menu2) 'Tools)
(define-key my-menu-bar-menu2 [my2-cmd1] '("My2 Command 1" . my-custom-command))
(define-key my-menu-bar-menu2 [my2-cmd2] '("My2 Command 2" . my-custom-command))
(define-key my-menu-bar-menu2 [my2-cmd3] '("My2 Command 3" . my-custom-command))

(defvar my-menu-bar-menu3 (make-sparse-keymap "Mine3"))
(define-key-after global-map [menu-bar my-menu3] (cons "Mine3" my-menu-bar-menu3) 'Tools)
(define-key my-menu-bar-menu3 [my3-cmd1] '("My3 Command 1" . my-custom-command))
(define-key my-menu-bar-menu3 [my3-cmd2] '("My3 Command 2" . my-custom-command))
(define-key my-menu-bar-menu3 [my3-cmd3] '("My3 Command 3" . my-custom-command))

 (require 'package)
;; ;; Add MELPA to the list of package archives
;; ; (add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(setq package-archives '(("gnu-cn" . "https://mirrors.ustc.edu.cn/elpa/gnu/")
                         ("melpa-cn" . "https://mirrors.ustc.edu.cn/elpa/melpa/")
                         ("nongnu-cn" . "https://mirrors.ustc.edu.cn/elpa/nongnu/")))

;; Initialize the package system
(package-initialize) ;; seem not connect to net

(defvar my-lost-pkgs '("item1" "item2" "item3")
  "A documentation string explaining what this list is for.")

(if (not (package-installed-p 'treemacs))
    (add-to-list 'my-lost-pkgs 'treemacs))

(defun myset-user-config-langs ()
    (setq history-length 100)
    ;;(put 'minibuffer-history 'history-length 50)
    ;;(put 'evil-ex-history 'history-length 50)
    ;;(put 'kill-ring 'history-length 25)
    (setq indent-tabs-mode nil)
    (setq default-tab-width 4)
    (setq tab-width 4)
    (setq c-basic-offset 4)
    (setq cmake-indent 4)
    (setq-default c-basic-offset 4)
    (setq-default flycheck-global-modes nil) ;; case go's flycheck will run 'go build', use too much memory for big project.
    (setq go-indent-level 4)
    (setq go-tab-width 4)
    (setq go-format-before-save nil)
    (setq gofmt-command "goimports")
    (setq php-indent-level 4)
    (setq python-indent-level 4)
    (setq python-indent-offset 4)
    (setq python-indent 4)
    (setq ruby-indent-level 4)
    (setq enh-ruby-indent-level 4)
    (setq js-indent-level 4)
    (setq crystal-indent-level 4)
    (setq dart-indent-level 4)
    (setq-default flycheck-flake8-maximum-line-length 100)
    ;; (setq projectile-switch-project-action 'neotree-projectile-action)
    ;; (setq-default treemacs-use-follow-mode t)
    (setq-default treemacs-width 25)
    (setq-default treemacs-use-git-mode 'simple)
    ;; (setq-default treemacs-no-png-images t)
    ;; (define-key treemacs-mode-map [mouse-1] #'treemacs-single-click-expand-action)
    ;;(treemacs)
    ;;(setq neo-show-hidden-files t)
    ;;(setq neo-smart-open t)
    ;;(setq neo-window-width 25) ;; it's defualt
    ;;(neotree-show)
    ;;       '((minibuffer-complete . ido)))

    ;; (push '("^\*helm.+\*$" :regexp t) popwin:special-display-config)
    ;; (add-hook 'helm-after-initialize-hook (lambda ()
    ;;            (popwin:display-buffer helm-buffer t)
    ;;            (popwin-mode -1)))
    ;;  Restore popwin-mode after a Helm session finishes.
    ;; (add-hook 'helm-cleanup-hook (lambda () (popwin-mode 1)))

    ;; (global-company-mode)
    ;; (menu-bar-mode t)
    ;; (scroll-bar-mode t)
    ;; (setq desktop-save nil)
    ;; (desktop-save-mode nil) ; save/read session
    ;; (setq desktop-path '("~/.emacs.d/.cache/"))
    ;; (desktop-read)
    (size-indication-mode t)
    (show-paren-mode t)
    (global-display-line-numbers-mode 1) ; emacs 26+
    ;; ctrl + Mouse-1 = goto define
    )

;; emacs-locale menu/message i18n
;; https://sourceforge.net/projects/emacslocale/
;; (require 'menu-bar)
;; (load-file "/etc/emacs/site-start.d/86_emacs30.2_locale-zh-cn.el")

(defun myon-window-setup1 ()
    (interactive)
    (message "hehehhehehe1")

)

(defun myon-window-setup2 ()
    (interactive)
    (message "hehehhehehe2"))

(defun myon-window-setup3 ()
    (interactive)
    (message "hehehhehehe3")
    (myset-user-config-langs)
    (message "heheh leave")
    
    ;; so put at function end
    ;; treemacs--expand-root-node: No file notification package available
    (require 'filenotify)
    (if (package-installed-p 'treemacs)
        (progn
	  (treemacs-add-and-display-current-project)
	  (next-window-any-frame))
      (add-to-list 'my-lost-pkgs 'treemacs)
    )
    )

(defun myon-window-setup4 ()
    (interactive)
    (message "hehehhehehe4"))

(add-hook 'after-init-hook 'myon-window-setup1)
(add-hook 'emacs-startup-hook 'myon-window-setup2)
(add-hook 'window-setup-hook 'myon-window-setup3)
(add-hook 'minibuffer-with-setup-hook 'myon-window-setup4)
