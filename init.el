;;; init.el --- Personal Emacs settings -*- lexical-binding: t; -*-

;; Finder/Spotlight-launched apps do not always inherit the shell's PATH.
(when (eq system-type 'darwin)
  (let ((homebrew-bin "/opt/homebrew/bin"))
    (when (file-directory-p homebrew-bin)
      (add-to-list 'exec-path homebrew-bin)
      (unless (member homebrew-bin (split-string (getenv "PATH") path-separator t))
        (setenv "PATH" (concat homebrew-bin path-separator (getenv "PATH")))))))

;; Match the RussianWin layout for Emacs's built-in C-\ input toggle.
(setq default-input-method "russian-computer")

;; macOS uses Command-Space to switch input sources on this machine.
;; Translate command keys typed in RussianWin back to their Latin positions.
(when (require 'reverse-im nil t)
  (setq reverse-im-input-methods '("russian-computer"))
  (reverse-im-mode 1))

;; Open the command prompt with Command-P, without moving Meta.
(keymap-global-set "s-p" #'execute-extended-command)

;; codex.el launches the existing Codex CLI, which reads ~/.codex/config.toml
;; and the current ChatGPT sign-in. Leave model and reasoning settings unset
;; here so Emacs follows the same defaults as the CLI and Codex desktop app.
(when (require 'codex nil t)
  (global-set-key (kbd "C-c x") codex-command-map))

;;; init.el ends here
