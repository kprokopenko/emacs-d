;;; init.el --- Personal Emacs settings -*- lexical-binding: t; -*-

;; Finder/Spotlight-launched apps do not always inherit the shell's PATH.
(when (eq system-type 'darwin)
  (let ((homebrew-bin "/opt/homebrew/bin"))
    (when (file-directory-p homebrew-bin)
      (add-to-list 'exec-path homebrew-bin)
      (unless (member homebrew-bin (split-string (getenv "PATH") path-separator t))
        (setenv "PATH" (concat homebrew-bin path-separator (getenv "PATH")))))))

;; codex.el launches the existing Codex CLI, which reads ~/.codex/config.toml
;; and the current ChatGPT sign-in. Leave model and reasoning settings unset
;; here so Emacs follows the same defaults as the CLI and Codex desktop app.
(when (require 'codex nil t)
  (global-set-key (kbd "C-c x") codex-command-map))

;;; init.el ends here
