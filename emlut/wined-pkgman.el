;; -*- lexical-binding: t; -*-

(require 'package)

;; 预定义的中文安装源（三个）
(defvar my-package-sources
  '(("GNU ELPA" . (("gnu" . "https://elpa.gnu.org/packages/")))
    ("MELPA" . (("melpa" . "https://melpa.org/packages/")))
    ("Org ELPA" . (("org" . "https://orgmode.org/elpa/")))
    ("清华源" . (("gnu"   . "https://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
                 ("melpa" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/")
                 ("org"   . "https://mirrors.tuna.tsinghua.edu.cn/elpa/org/")))
    ("中科大源" . (("gnu"   . "http://mirrors.ustc.edu.cn/elpa/gnu/")
                   ("melpa" . "http://mirrors.ustc.edu.cn/elpa/melpa/")
                   ("org"   . "http://mirrors.ustc.edu.cn/elpa/org/")))
    ("阿里源" . (("gnu"   . "https://mirrors.aliyun.com/elpa/gnu/")
                 ("melpa" . "https://mirrors.aliyun.com/elpa/melpa/")
                 ("org"   . "https://mirrors.aliyun.com/elpa/org/"))))
  "可选安装源列表，每个元素为 (名称 . (档案名 . URL) 列表)。")

(defvar my-package-buffer "*my-package-manager*"
  "包管理窗口使用的 buffer 名称。")

(defvar my-package-frame nil
  "包管理窗口的框架对象。")

(defvar my-package-current-filter nil
  "当前的包名过滤字符串（正则表达式）。")

(defvar my-package-status-filter 'all
  "当前的包状态过滤：'all, 'installed, 'not-installed, 'upgradable。")

(defvar my-package-current-source-name "清华源"
  "当前正在使用的源名称，用于显示。")

(defvar my-package-total-count 0
  "当前源中有效包的总数（排除无效条目）。")

(defvar my-package-installed-count 0
  "已安装的包数量（基于有效包）。")

;; ---------------------------------------------------------------------
;; 包信息缓存（加速搜索）
;; ---------------------------------------------------------------------
(defvar my-package-cached-packages nil
  "缓存包信息列表，每个元素为 (name version pkg-sym installed upgradable)。")

(defun my-package-build-cache ()
  "从 package-archive-contents 构建缓存。"
  (setq my-package-cached-packages nil)
  (let ((packages (sort (mapcar #'car package-archive-contents) #'string<))
        (total 0))
    (dolist (pkg-sym packages)
      (let* ((name (symbol-name pkg-sym))
             (desc (cadr (assq pkg-sym package-archive-contents))))
        (when (and desc (package-desc-p desc))
          (cl-incf total)
          (let* ((version (package-version-join (package-desc-version desc)))
                 (inst (package-installed-p pkg-sym))
                 (upgradable (and inst
                                  (let* ((installed-desc (cadr (assq pkg-sym package-alist)))
                                         (inst-ver (and installed-desc
                                                        (package-desc-p installed-desc)
                                                        (package-desc-version installed-desc))))
                                    (and inst-ver (version-list-< inst-ver (package-desc-version desc)))))))
            (push (list name version pkg-sym inst upgradable) my-package-cached-packages)))))
    (setq my-package-total-count total
          my-package-cached-packages (nreverse my-package-cached-packages))))


;; ---------------------------------------------------------------------
;; 窗口拖动功能
;; ---------------------------------------------------------------------
(defvar my-package-drag-start nil
  "拖动开始时记录的框架位置和鼠标位置，格式为 (frame-left frame-top mouse-x mouse-y)。")

(defun my-package-start-drag (event)
  "开始拖动窗口，记录初始位置并进入拖动循环。"
  (interactive "e")
  (let* ((frame my-package-frame)
         (frame-pos (frame-position frame))
         (mouse-pos (mouse-pixel-position))
         (mouse-x (cadr mouse-pos))
         (mouse-y (cddr mouse-pos)))
    (setq my-package-drag-start (list (car frame-pos) (cdr frame-pos) mouse-x mouse-y))
    (track-mouse
      (while (not (mouse-movement-p (setq event (read-event))))
        (when (mouse-movement-p event)
          (let* ((new-mouse-pos (mouse-pixel-position))
                 (new-mouse-x (cadr new-mouse-pos))
                 (new-mouse-y (cddr new-mouse-pos))
                 (dx (- new-mouse-x (nth 2 my-package-drag-start)))
                 (dy (- new-mouse-y (nth 3 my-package-drag-start)))
                 (new-x (+ (nth 0 my-package-drag-start) dx))
                 (new-y (+ (nth 1 my-package-drag-start) dy)))
            (set-frame-position frame new-x new-y)))))))


;; 拖动手柄的 keymap
(defvar my-package-drag-map
  (let ((map (make-sparse-keymap)))
    (define-key map [header-line down-mouse-1] 'my-package-start-drag)
    map))

;; ---------------------------------------------------------------------
;; 辅助函数：创建带点击属性的按钮字符串（使用 keymap）
;; ---------------------------------------------------------------------
(defun my-package-make-button (label command &optional help)
  "返回一个字符串 LABEL，点击时执行 COMMAND，并带有 HELP 提示。"
  (let ((map (make-sparse-keymap)))
    (define-key map [header-line mouse-1] command)
    (propertize label
                'mouse-face 'highlight
                'keymap map
                'help-echo (or help (format "点击 %s" label)))))

;; ---------------------------------------------------------------------
;; 设置 header-line（固定工具栏）
;; ---------------------------------------------------------------------
(defun my-package-set-header-line ()
  "根据当前状态设置 header-line-format，包含搜索、源、统计等。"
  (with-current-buffer my-package-buffer
    (let ((search-part
           (if my-package-current-filter
               (concat (my-package-make-button "🔍 搜索" 'my-package-search
                                               "点击修改搜索条件 C-f")
                       " "
                       (propertize (concat "[" my-package-current-filter "]")
                                   'face 'bold)
                       " "
                       (my-package-make-button "✕" 'my-package-clear-search
                                               "清除搜索过滤"))
             (my-package-make-button "🔍 搜索" 'my-package-search
                                     "点击输入搜索词 C-f"))))
      (setq header-line-format
            (list " "
		  ;; 拖动手柄（左侧）
                  (propertize "≡ " 'local-map my-package-drag-map 'mouse-face 'highlight)
                  ;; 当前源名称
                  (propertize (format "[%s]" my-package-current-source-name)
                              'face 'bold)
                  "  "
                  ;; 搜索部分
                  search-part
                  "  "
                  ;; 状态过滤按钮（弹出菜单）
                  (my-package-make-button
                   (format "📊 %s"
                           (pcase my-package-status-filter
                             ('all "所有包")
                             ('installed "已安装")
                             ('not-installed "未安装")
                             ('upgradable "有更新")))
                   'my-package-switch-status-popup
                   "点击切换显示状态")
                  "  "
                  ;; 切换源按钮（弹出菜单）
                  (my-package-make-button "🌐 切换源" 'my-package-switch-source-popup
                                          "点击切换中文安装源")
                  "  "
                  ;; 刷新按钮
                  (my-package-make-button "🔄 刷新" 'my-package-refresh-packages
                                          "手动刷新包列表")
                  "    "   ; 分隔
                  ;; 放大按钮
                  (my-package-make-button "➕ 放大" 'my-package-resize-enlarge
                                          "点击放大窗口")
                  "  "
                  ;; 缩小按钮
                  (my-package-make-button "➖ 缩小" 'my-package-resize-shrink
                                          "点击缩小窗口")
                  "  "
                  ;; 关闭按钮
                  (my-package-make-button "✕ 关闭" 'my-package-close
                                          "点击关闭窗口")
                  "  "
                  ;; 统计信息
                  (propertize (format "📦 %d/%d"
                                      my-package-installed-count
                                      my-package-total-count)
                              'face 'bold)
                  " ")))))

;; 为放大/缩小/关闭定义单独的命令
(defun my-package-resize-enlarge ()
  (interactive)
  (my-package-resize 5 2))

(defun my-package-resize-shrink ()
  (interactive)
  (my-package-resize -5 -2))

(defun my-package-close ()
  (interactive)
  (when (frame-live-p my-package-frame)
    (delete-frame my-package-frame)))

(defun my-package-clear-search ()
  "清除搜索过滤条件并刷新列表。"
  (interactive)
  (setq my-package-current-filter nil)
  (my-package-refresh-list))

;; ---------------------------------------------------------------------
;; 主窗口创建与关闭（使用 child frame，启用内部 minibuffer）
;; ---------------------------------------------------------------------
(defun my-package-popup ()
  "打开一个浮动包管理窗口，无标题栏，全鼠标操作。"
  (interactive)
  (if (and my-package-frame (frame-live-p my-package-frame))
      (progn
        (select-frame-set-input-focus my-package-frame)
        (setq default-minibuffer-frame my-package-frame))
    (my-package-create-frame)))

(defun my-package-create-frame ()
  "创建子框架并显示包管理界面。"
  (let ((buffer (get-buffer-create my-package-buffer)))
    (with-current-buffer buffer
      (my-package-refresh-list))
    (setq my-package-frame
          (make-frame
           `((parent-frame . ,(selected-frame))
             (minibuffer . t)                    ; 启用子框架自己的 minibuffer
             (undecorated . t)
             (menu-bar-lines . 0)
             (tool-bar-lines . 0)
             (width . 90)
             (height . 30)
             (left . 200)
             (top . 100)
             (name . "Package Manager")
             (visibility . t)
             (user-position . t)
             ;; (keep-ratio . t)
             (no-accept-focus . nil)
             (no-focus-on-map . nil))))
    (select-frame my-package-frame)
    (setq default-minibuffer-frame my-package-frame)
    (switch-to-buffer buffer)
    ;; 设置 buffer 为只读，防止意外编辑
    (setq buffer-read-only t)
    (setq mode-line-format nil)
    (setq cursor-type nil)
    (my-package-set-header-line)
    ;; 添加键盘绑定：按 ESC 关闭窗口
    (use-local-map
     (let ((map (make-sparse-keymap)))
       (define-key map (kbd "<escape>") 'my-package-close)
       map))))

;; ---------------------------------------------------------------------
;; 刷新包列表（重新生成 buffer 内容并更新统计）
;; ---------------------------------------------------------------------
(defun my-package-refresh-list ()
  "重新生成包管理界面，根据当前过滤条件和源。"
  (interactive)
  (let ((inhibit-read-only t))
    (with-current-buffer my-package-buffer
      (erase-buffer)
      (my-package-insert-packages)
      (goto-char (point-min))
      (my-package-set-header-line))))

(defun my-package-insert-packages ()
  "插入所有符合条件的包，并统计总数和已安装数。使用缓存加速。"
  ;; 确保包列表已刷新，必要时构建缓存
  (unless package-archive-contents
    (message "正在刷新包列表，请稍候...")
    (package-refresh-contents))
  (unless my-package-cached-packages
    (my-package-build-cache))
  (let ((count 0)
        (installed 0))
    (dolist (pkg-info my-package-cached-packages)
      (let ((name (nth 0 pkg-info))
            (version (nth 1 pkg-info))
            (pkg-sym (nth 2 pkg-info))
            (inst (nth 3 pkg-info))
            (upgradable (nth 4 pkg-info)))
        ;; 同时应用搜索过滤和状态过滤
        (when (and (or (null my-package-current-filter)
                       (string-match-p my-package-current-filter name))
                   (pcase my-package-status-filter
                     ('all t)
                     ('installed inst)
                     ('not-installed (not inst))
                     ('upgradable upgradable)))
          (cl-incf count)
          (when inst (cl-incf installed))
          (insert (format "%-25s %-12s %-8s" name version ""))
          (cond (inst
                 (insert-text-button "删除"
                                     'action `(lambda (_) (my-package-delete ',pkg-sym))
                                     'help-echo "点击卸载此包")
                 (insert " ")
                 (if upgradable
                     (insert-text-button "更新"
                                         'action `(lambda (_) (my-package-update ',pkg-sym))
                                         'help-echo "点击更新此包")
                   (insert-text-button "    " 'face 'shadow)))
                (t
                 (insert-text-button "安装"
                                     'action `(lambda (_) (my-package-install ',pkg-sym))
                                     'help-echo "点击安装此包")))
          (insert "\n"))))
    ;; 更新显示的已安装计数（仅当前过滤条件下）
    (setq my-package-installed-count installed)
    (when (= count 0)
      (insert "没有匹配的包。\n"))))

;; ---------------------------------------------------------------------
;; 操作函数：安装、删除、更新
;; ---------------------------------------------------------------------
(defun my-package-install (pkg)
  (message "正在安装 %s ..." pkg)
  (condition-case err
      (progn
        (package-install pkg)
        (message "安装 %s 成功。" pkg))
    (error (message "安装 %s 失败：%s" pkg (error-message-string err))))
  ;; 使缓存失效，下次刷新时重建
  (setq my-package-cached-packages nil)
  (my-package-refresh-list))

(defun my-package-delete (pkg)
  (let* ((desc (cadr (assq pkg package-alist))))
    (if (and desc (package-desc-p desc))
        (progn
          (message "正在删除 %s ..." pkg)
          (condition-case err
              (progn
                (package-delete desc)
                (message "删除 %s 成功。" pkg))
            (error (message "删除 %s 失败：%s" pkg (error-message-string err))))
          (setq my-package-cached-packages nil)
          (my-package-refresh-list))
      (message "包 %s 未安装或描述无效。" pkg))))

(defun my-package-update (pkg)
  (message "正在更新 %s ..." pkg)
  (condition-case err
      (progn
        (package-install pkg)
        (message "更新 %s 成功。" pkg))
    (error (message "更新 %s 失败：%s" pkg (error-message-string err))))
  (setq my-package-cached-packages nil)
  (my-package-refresh-list))

;; ---------------------------------------------------------------------
;; 搜索与源切换、状态切换
;; ---------------------------------------------------------------------
(defun my-package-search ()
  "通过子框架的 minibuffer 输入搜索词，过滤包列表。"
  (interactive)
  (let ((default-minibuffer-frame my-package-frame))
    (select-frame-set-input-focus my-package-frame)
    (let ((term (read-string "搜索包 (正则表达式): ")))
      (setq my-package-current-filter (if (string= term "") nil term))
      (my-package-refresh-list)
      (message "过滤条件: %s" (or my-package-current-filter "无")))))

(defun my-package-switch-source-popup ()
  "使用弹出菜单切换中文安装源。"
  (interactive)
  (let* ((items (mapcar (lambda (item)
                           (cons (car item)
                                 (lambda () (interactive)
                                   (my-package-set-source (car item)))))
                         my-package-sources))
         (menu (list "选择安装源" (cons "源列表" items))))
    (let ((choice (x-popup-menu t menu)))
      (when choice
        (funcall choice)))))

(defun my-package-set-source (source-name)
  "设置当前源为 SOURCE-NAME，并刷新。"
  (let ((source (cdr (assoc source-name my-package-sources))))
    (when source
      (setq package-archives source
            my-package-current-source-name source-name)
      (message "已切换到 %s，正在刷新包列表..." source-name)
      (package-refresh-contents)
      ;; 清空缓存，因为包列表已变
      (setq my-package-cached-packages nil)
      (my-package-refresh-list)
      (message "源切换完成。当前源：%s" source-name))))

(defun my-package-switch-status-popup ()
  "使用弹出菜单切换包状态过滤。"
  (interactive)
  (let* ((status-alist '((all . "所有包")
                         (installed . "已安装")
                         (not-installed . "未安装")
                         (upgradable . "有更新")))
         (items (mapcar (lambda (cell)
                          (cons (cdr cell)
                                (lambda () (interactive)
                                  (my-package-set-status (car cell)))))
                        status-alist))
         (menu (list "选择显示状态" (cons "状态" items))))
    (let ((choice (x-popup-menu t menu)))
      (when choice
        (funcall choice)))))

(defun my-package-set-status (status)
  "设置状态过滤器为 STATUS，并刷新。"
  (setq my-package-status-filter status)
  (my-package-refresh-list)
  (message "显示状态: %s" (pcase status
                            ('all "所有包")
                            ('installed "已安装")
                            ('not-installed "未安装")
                            ('upgradable "有更新"))))

(defun my-package-refresh-packages ()
  "手动刷新包列表（从当前源重新获取）。"
  (interactive)
  (message "正在刷新包列表，请稍候...")
  (package-refresh-contents)
  ;; 清空缓存，强制重建
  (setq my-package-cached-packages nil)
  (my-package-refresh-list)
  (message "包列表刷新完成。"))

;; ---------------------------------------------------------------------
;; 窗口大小调整
;; ---------------------------------------------------------------------
(defun my-package-resize (width-delta height-delta)
  (when (frame-live-p my-package-frame)
    (let ((new-width (+ (frame-width my-package-frame) width-delta))
          (new-height (+ (frame-height my-package-frame) height-delta)))
      (setq new-width (max 50 new-width)
            new-height (max 20 new-height))
      (set-frame-size my-package-frame new-width new-height))))

;; ---------------------------------------------------------------------
;; 提供功能
;; ---------------------------------------------------------------------
(provide 'my-package-manager)
