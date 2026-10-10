;;; install.el --- Install Emacs packages -*- lexical-binding: t; -*-

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)
(package-refresh-contents)
(unless (package-installed-p 'inheritenv '(0 2))
  (package-install 'inheritenv))
(unless (package-installed-p 'eat '(0 9 4))
  (package-install 'eat))
(unless (package-installed-p 'reverse-im)
  (package-install 'reverse-im))
(require 'package-vc)
(unless (package-installed-p 'codex)
  (package-vc-install "https://github.com/benthamite/codex"))

;;; install.el ends here
