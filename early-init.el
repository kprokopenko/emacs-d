;;; early-init.el --- Early Emacs settings -*- lexical-binding: t; -*-

;; Initialize packages in init.el, after loading Transient.
(setq package-enable-at-startup nil)

;; Use macOS native fullscreen as soon as the first graphical frame appears.
;; This also applies to frames created by emacsclient if a daemon is enabled later.
(add-to-list 'default-frame-alist '(fullscreen . fullboth))

;;; early-init.el ends here
