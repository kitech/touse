;; package-install RET lsp-mode company
;; lsp-mode with v-analyzer wroks fine

(require 'v-mode)

(require 'lsp-mode)

;;https://emacs-lsp.github.io/lsp-mode/page/adding-new-language/
(add-to-list 'lsp-language-id-configuration '(v-mode . "v"))
;; (add-to-list 'lsp-language-id-configuration '(".*\\.svelte$" . "svelte"))

(lsp-register-client (make-lsp-client
                      :new-connection (lsp-stdio-connection "v-analyzer")
                      :activation-fn (lsp-activate-on "v")
                      :server-id 'v-analyzer))
(add-hook 'v-mode-hook 'lsp-mode)
