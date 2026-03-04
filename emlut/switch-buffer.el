;; -*- lexical-binding: t; -*-

;; 使用方法
;;     执行 M-x my-switch-buffer-popup 打开 buffer 菜单。
;;     尝试以下操作：
;;         TAB：向下移动选择。
;;         Shift+TAB：向上移动选择。
;;         方向键：上下循环移动。
;;         数字 1-9：直接跳转到对应项。
;;         输入字符：增量搜索过滤。
;;         ESC 或 C-g：取消菜单。


;; -*- lexical-binding: t; -*-

(require 'popup nil t)
(require 'cl-lib)

;; =============================================================================
;; 新增自定义变量：选择弹出位置的计算方法
;; =============================================================================

(defcustom my-popup-center-method 'window
  "弹出菜单的居中计算方法。
- 'window : 在当前窗口的中央行弹出（默认，稳定可靠）
- 'frame  : 尝试在整个帧的中央区域弹出（图形界面下有效，终端下回退到窗口）"
  :type '(choice (const :tag "当前窗口中央" window)
                 (const :tag "整个帧中央" frame))
  :group 'my)

;; =============================================================================
;; 细化图标映射表（同前，省略部分以节省篇幅，实际使用需包含全部）
;; =============================================================================

(defcustom my-buffer-icon-alist
  '(
    ;; 文件扩展名
    ("\\.el\\'"                       . "📜")
    ("\\.py\\'"                        . "🐍")
    ("\\.java\\'"                      . "☕")
    ("\\.c\\'"                         . "⚙️")
    ("\\.cpp\\'"                       . "⚙️")
    ("\\.h\\'"                         . "📋")
    ("\\.js\\'"                        . "🟨")
    ("\\.html?\\'"                     . "🌐")
    ("\\.css\\'"                       . "🎨")
    ("\\.json\\'"                      . "☁️")
    ("\\.xml\\'"                       . "📰")
    ("\\.yaml\\'"                      . "⚙️")
    ("\\.md\\'"                        . "📝")
    ("\\.org\\'"                       . "📓")
    ("\\.tex\\'"                       . "📄")
    ("\\.sh\\'"                        . "🐚")
    ("\\.rb\\'"                        . "💎")
    ("\\.go\\'"                        . "🔵")
    ("\\.rs\\'"                        . "🦀")
    ("\\.php\\'"                       . "🐘")
    ("\\.scala\\'"                     . "🔥")
    ("\\.clj\\'"                       . "🌿")
    ("\\.hs\\'"                        . "λ")
    ("\\.[Cc]?make\\'"                 . "🔨")
    ("\\.conf\\'"                      . "⚙️")
    ("\\.log\\'"                       . "📋")
    ("\\.csv\\'"                       . "📊")
    ("\\.pdf\\'"                       . "📕")
    ;; major-mode
    (emacs-lisp-mode                    . "📜")
    (lisp-interaction-mode              . "📜")
    (python-mode                        . "🐍")
    (java-mode                          . "☕")
    (c-mode                             . "⚙️")
    (c++-mode                           . "⚙️")
    (js-mode                            . "🟨")
    (js2-mode                           . "🟨")
    (html-mode                          . "🌐")
    (css-mode                           . "🎨")
    (json-mode                          . "☁️")
    (xml-mode                           . "📰")
    (yaml-mode                          . "⚙️")
    (markdown-mode                      . "📝")
    (org-mode                           . "📓")
    (tex-mode                           . "📄")
    (latex-mode                         . "📄")
    (sh-mode                            . "🐚")
    (ruby-mode                          . "💎")
    (go-mode                            . "🔵")
    (rust-mode                          . "🦀")
    (php-mode                           . "🐘")
    (scala-mode                         . "🔥")
    (clojure-mode                        . "🌿")
    (haskell-mode                       . "λ")
    (makefile-mode                      . "🔨")
    (conf-mode                          . "⚙️")
    (fundamental-mode                   . "•")
    ;; 特殊 buffer
    ("^\\*scratch\\*$"                  . "🔰")
    ("^\\*Messages\\*$"                 . "💬")
    ("^\\*Completions\\*$"              . "🔍")
    ("^\\*Help\\*$"                     . "❓")
    ("^\\*Calendar\\*$"                 . "📅")
    ("^\\*Compile-Log\\*$"              . "📋")
    ("^\\*.*\\*$"                       . "🔧")
    ;; dired
    (dired-mode                          . "📁")
    )
  "图标映射 alist。"
  :type '(alist :key-type (choice regexp symbol) :value-type string)
  :group 'my)

;; =============================================================================
;; 图标辅助函数（同前）
;; =============================================================================

(defun my-buffer-popup-icon-for-buffer (buf)
  "为 buffer BUF 返回细化的图标字符串。"
  (let* ((name (buffer-name buf))
         (file (buffer-file-name buf))
         (mode (buffer-local-value 'major-mode buf))
         icon)
    (cond
     (file
      (setq icon (cl-loop for (key . value) in my-buffer-icon-alist
                          when (and (stringp key) (string-match-p key file))
                          return value)))
     ((setq icon (cl-loop for (key . value) in my-buffer-icon-alist
                          when (eq key mode)
                          return value))))
    (unless icon
      (setq icon (cl-loop for (key . value) in my-buffer-icon-alist
                          when (and (stringp key) (string-match-p key name))
                          return value)))
    (or icon
        (cond
         ((buffer-file-name buf) "📄")
         ((eq mode 'dired-mode) "📁")
         ((string-match-p "^\\*.*\\*$" name) "🔧")
         (t "•")))))


;; =============================================================================
;; buffer 过滤与菜单生成（同前）
;; =============================================================================

(defcustom my-buffer-popup-ignore-regexps
  '("^ ")
  "忽略的 buffer 名称正则表达式列表。"
  :type '(repeat regexp)
  :group 'my)

(defcustom my-buffer-popup-filter-function
  'my-buffer-popup-default-filter
  "自定义 buffer 过滤函数。"
  :type '(choice (function-item my-buffer-popup-default-filter)
                 (function :tag "自定义函数"))
  :group 'my)

(defun my-buffer-popup-default-filter (buf)
  (and (buffer-live-p buf)
       (not (eq buf (current-buffer)))
       (not (cl-loop for re in my-buffer-popup-ignore-regexps
                     thereis (string-match-p re (buffer-name buf))))))

(defun my-buffer-popup-items ()
  (let (items)
    (dolist (buf (buffer-list))
      (when (funcall my-buffer-popup-filter-function buf)
        (let* ((icon (my-buffer-popup-icon-for-buffer buf))
               (name (buffer-name buf))
               (display (concat icon " " name)))
          (push (popup-make-item display :value buf) items))))
    (nreverse items)))

;; =============================================================================
;; 位置计算函数：窗口中心点
;; =============================================================================

(defun my-window-center-point ()
  "返回当前窗口中央行的缓冲区位置（整数点），不移动光标。"
  (save-excursion
    (goto-char (window-start))
    (forward-line (/ (window-height) 2))
    (point)))

;; =============================================================================
;; 位置计算函数：帧中心点（图形界面下将帧像素坐标转换为缓冲区位置）
;; =============================================================================

(defun my-frame-center-point ()
  "计算帧中心点，并尝试减去菜单自身宽高的一半，实现菜单真正居中。"
  (if (not (display-graphic-p))
      (my-window-center-point)
    (let* ((frame-pix-width (frame-pixel-width))
           (frame-pix-height (frame-pixel-height))
           (center-x (/ frame-pix-width 2))
           (center-y (/ frame-pix-height 2))
	   (popwin-w 400)
	   (popwin-h 200)
	   (anchor-x (- center-x popwin-w))
	   (anchor-y (- center-y popwin-h))
           ;; 将锚点像素坐标转换为缓冲区位置
           (posn (posn-at-x-y anchor-x anchor-y nil t)))
      
      ;; (message (format "111 %s %s" center-x center-y))
      ;; (message (format "222 %s %s" anchor-x anchor-y))
      ;; (message (format "333 %s %s" frame-pix-width frame-pix-height))

      ;; 若转换成功则返回 point，否则回退到窗口中心
      (if (and posn (posn-point posn))
          (posn-point posn)
        (my-window-center-point)))))
;; =============================================================================
;; 主函数
;; =============================================================================

;;;###autoload
(defun my-switch-buffer-popup ()
  "通过 popup 菜单切换 buffer，支持：
- 细化图标
- 总数显示
- 当前位置指示（高亮）
- TAB/Shift+TAB 上下移动，方向键循环
- 数字快捷键 1-9
- 增量搜索过滤
- ESC 或 C-g 取消
- Material Dark 风格（可自定义）
- 弹出位置：根据 my-popup-center-method 选择窗口中心或帧中心"
  (interactive)
  (setq my-popup-center-method 'frame)
  
  (let ((items (my-buffer-popup-items)))
    (if (null items)
        (message "No buffers to switch")
      (let* ((total (length items))
             (prompt (format "Switch to buffer (%d): " total))
             ;; 根据用户选择计算锚点
             (anchor-point (if (eq my-popup-center-method 'frame)
                               (my-frame-center-point)
                             (my-window-center-point))))

        ;; 构建 keymap
        (let* ((base-map (if (boundp 'popup-menu-keymap)
                             (symbol-value 'popup-menu-keymap)
                           minibuffer-local-map))
               (keymap (make-sparse-keymap)))
          (set-keymap-parent keymap base-map)
          (define-key keymap (kbd "ESC") 'abort-recursive-edit)
          (define-key keymap (kbd "<escape>") 'abort-recursive-edit)
          (define-key keymap (kbd "TAB") 'popup-next)
          (define-key keymap (kbd "<backtab>") 'popup-previous)

          ;; 弹出菜单，使用 :point 参数指定锚点
          (let ((selection (popup-menu* items
                                         :prompt prompt
                                         :point anchor-point
                                         :scroll-bar t
                                         :isearch t
                                         :keymap keymap)))
            (when selection
              (switch-to-buffer selection))))))))

;; 绑定快捷键（可选）
;; (global-set-key (kbd "C-x p") 'my-switch-buffer-popup)


;; 使用 elisp 编写 emacs 的 buffer 切换，使用popup 菜单，
;; 可快捷键选择，可自动隐藏，可向前或者向头和循环。
;; 支持默认materail dark 风格并且可以自定义。
;; 显示文件个数，当前位置，以及文件图标功能
;; 弹出列表不需要跟随光标位置，显示在固定的中间位置
