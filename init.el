;;; init.el --- Personal Emacs settings -*- lexical-binding: t; -*-

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
;; Codex IDE's generated autoloads define Transient menus during package setup.
(require 'transient)
(package-initialize)
(require 'use-package)
(setq use-package-always-ensure t)

;; Readable light theme with a softly tinted background.
(load-theme 'modus-operandi-tinted t)

;; The saved desktop can restore a frame with its previous font.
(defun kprokopenko-apply-font ()
  "Use JetBrains Mono at 14 points in graphical frames."
  (set-face-attribute 'default nil :family "JetBrains Mono" :height 140)
  (let ((font (font-spec :family "JetBrains Mono" :size 14.0)))
    (dolist (frame (frame-list))
      (when (display-graphic-p frame)
        (set-frame-font font nil (list frame) t)))))

(add-hook 'emacs-startup-hook #'kprokopenko-apply-font)
(with-eval-after-load 'desktop
  (add-hook 'desktop-after-read-hook #'kprokopenko-apply-font))

;; Show tabs as two columns and use spaces for indentation by default.
;; Go mode selects real tabs for Go files; gofmt keeps their formatting.
(setq-default tab-width 2
              indent-tabs-mode nil)

;; Revert unchanged file buffers immediately; keep the confirmation for edits.
(setq revert-without-query '(".*"))

;; Show recently modified files first in Dired.
(setq dired-listing-switches "-alt")

;; Finder/Spotlight-launched apps do not always inherit the shell's PATH.
(when (eq system-type 'darwin)
  (dolist (directory
           (list "/opt/homebrew/bin"
                 (expand-file-name ".local/bin" "~")
                 (expand-file-name "go/bin" "~")
                 (expand-file-name
                  ".local/share/emacs-lsp/node_modules/.bin" "~")))
    (when (file-directory-p directory)
      (add-to-list 'exec-path directory)
      (unless (member directory (split-string (getenv "PATH") path-separator t))
        (setenv "PATH" (concat directory path-separator (getenv "PATH")))))))

;; Match the RussianWin layout for Emacs's built-in C-\ input toggle.
(setq default-input-method "russian-computer")

;; Swap physical Command (Super) and Option (Meta) throughout Emacs.
;; Command-F moves by word; Control keeps its usual bindings.
(when (eq system-type 'darwin)
  (setq ns-control-modifier 'control
        ns-command-modifier 'meta
        ns-option-modifier 'super))

;; macOS uses Command-Space to switch input sources on this machine.
;; Translate command keys typed in RussianWin back to their Latin positions.
(use-package reverse-im
  :demand t
  :init
  (setq reverse-im-input-methods '("russian-computer"))
  :config
  (reverse-im-mode 1))

;; Mirror these two Meta commands on Option (Super).
(keymap-global-set "s-v" #'scroll-down-command)
(keymap-global-set "s-w" #'kill-ring-save)
;; Keep code navigation on Option (Super).
(keymap-global-set "s-." #'xref-find-definitions)
(keymap-global-set "s->" #'xref-find-references)

(defvar-local kprokopenko-scroll-history nil
  "Cursor and window-start markers saved before scrolling this buffer.")

(defun kprokopenko-scroll-remember (scroll &rest args)
  "Save the cursor and visible page before SCROLL changes the view using ARGS."
  (let ((window (selected-window))
        (origin (point-marker))
        (start (copy-marker (window-start))))
    (prog1 (apply scroll args)
      (when (and (eq (window-buffer window) (marker-buffer origin))
                 (or (/= (window-point window) origin)
                     (/= (window-start window) start)))
        (with-current-buffer (marker-buffer origin)
          (push (cons origin start) kprokopenko-scroll-history)
          (setcdr (nthcdr (1- (min (length kprokopenko-scroll-history)
                                  (max 1 mark-ring-max)))
                          kprokopenko-scroll-history)
                  nil))))))

;; Page commands and the mouse wheel both use these scrolling primitives.
(advice-add 'scroll-up :around #'kprokopenko-scroll-remember)
(advice-add 'scroll-down :around #'kprokopenko-scroll-remember)

(defun kprokopenko-go-back ()
  "Go back in xref history, then scroll history, then this buffer's marks."
  (interactive)
  (require 'xref)
  (cond
   ((not (xref-marker-stack-empty-p)) (xref-go-back))
   (kprokopenko-scroll-history
    (let ((location (pop kprokopenko-scroll-history)))
      (goto-char (car location))
      (set-window-start (selected-window) (cdr location))
      (set-marker (car location) nil)
      (set-marker (cdr location) nil)))
   (t (pop-to-mark-command))))

(keymap-global-set "M-," #'kprokopenko-go-back)
(keymap-global-set "s-," #'kprokopenko-go-back)
(keymap-global-set "C-c l" #'display-line-numbers-mode)

(defun kprokopenko-kill-region-or-backward-word ()
  "Kill the active region, or kill one word before point."
  (interactive)
  (if (use-region-p)
      (kill-region (region-beginning) (region-end))
    (backward-kill-word 1)))

(keymap-global-set "C-w" #'kprokopenko-kill-region-or-backward-word)

;; Search completion candidates by substrings and by words in any order.
;; Emacs 31 uses the leading wildcard for substring file completion.
(use-package orderless
  :demand t
  :init
  (setq completion-styles '(orderless basic)
        completion-category-overrides '((file (styles partial-completion)))
        completion-pcm-leading-wildcard t))

(use-package vertico
  :bind (:map vertico-map
              ("C-l" . vertico-directory-up))
  :init
  (setq vertico-count 15
        vertico-resize t
        vertico-cycle t)
  (vertico-mode 1))

(use-package marginalia
  :init
  (marginalia-mode 1))

;; Consult presents xref results with grouping, filtering and live preview.
(use-package consult
  :demand t
  :bind (("C-x b" . consult-buffer)
         ("s-f" . consult-line)
         ("s-F" . consult-ripgrep))
  :config
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref))

(defun kprokopenko-find-file ()
  "Find a file in the current project, or anywhere outside a project."
  (interactive)
  (if (project-current nil)
      (project-find-file)
    (call-interactively #'find-file)))

(keymap-global-set "s-o" #'kprokopenko-find-file)

;; Wrap Codex chat at 150 columns, keeping the text left-aligned.
(use-package visual-fill-column
  :ensure t
  :commands visual-fill-column-mode
  :hook (codex-ide-session-mode . kprokopenko-codex-text-width)
  :init
  (defun kprokopenko-codex-text-width ()
    "Limit the Codex text area to 150 columns without centering."
    (setq-local visual-fill-column-width 150
                visual-fill-column-center-text nil)
    (visual-fill-column-mode 1)))

;; codex-ide uses the installed Codex CLI and its existing ChatGPT sign-in.
;; Set the Emacs model independently of the shared Codex CLI default.
;; Keep the explicit reasoning effort aligned with ~/.codex/config.toml.
(use-package codex-ide
  :vc (:url "https://github.com/kprokopenko/emacs-codex-ide"
       :branch "fork-dev"
       :rev :newest)
  :demand t
  :init
  ;; This package sends an explicit effort; match ~/.codex/config.toml.
  (setq codex-ide-model "gpt-6.1-sol"
        codex-ide-reasoning-effort "high")
  :bind (("C-c x" . codex-ide-menu)
         ("C-c a" . codex-ide-annotate-region)
         ("s-t" . codex-ide)
         ("M-t" . codex-ide))
  :config
  ;; New and restored sessions replace the selected window's buffer.
  (setq codex-ide-new-session-split nil
        codex-ide-buffer-display-when-approval-required nil
        codex-ide-display-buffer-pop-up-action
        '((display-buffer-same-window)))
  ;; Accept MCP elicitation requests from every server without a prompt.
  (defun kprokopenko-codex-ide-accept-mcp-elicitation (_params)
    "Accept an MCP elicitation without prompting."
    t)
  (advice-add 'codex-ide-mcp-bridge-request-exempt-from-approval-p
              :override #'kprokopenko-codex-ide-accept-mcp-elicitation)
  ;; Show the live session buffer list in the selected window.
  (add-to-list 'display-buffer-alist
               (cons (rx string-start "*Codex Session Buffers*" string-end)
                     '((display-buffer-same-window)))))

;; Keep pending requests visible without displaying or selecting Codex windows.
(defun kprokopenko-codex-pending-requests ()
  "Return unresolved Codex requests, oldest first."
  (let (requests)
    (dolist (session codex-ide--sessions)
      (when (buffer-live-p (codex-ide-session-buffer session))
        (dolist (request (codex-ide-approvals-data-unresolved-list session))
          (push (cons session request) requests))))
    (sort requests
          (lambda (left right)
            (time-less-p (plist-get (cdr left) :created-at)
                         (plist-get (cdr right) :created-at))))))

(defvar kprokopenko-codex-review-origin nil
  "Marker and review buffer saved when visiting a pending Codex request.")

(defun kprokopenko-codex-review-request ()
  "Visit the oldest pending Codex request, or return to the previous buffer."
  (interactive)
  (if (and kprokopenko-codex-review-origin
           (eq (current-buffer)
               (plist-get kprokopenko-codex-review-origin :review-buffer)))
      (let ((origin (plist-get kprokopenko-codex-review-origin :point)))
        (setq kprokopenko-codex-review-origin nil)
        (when (marker-buffer origin)
          (switch-to-buffer (marker-buffer origin))
          (goto-char origin))
        (set-marker origin nil))
    (let* ((pending (car (kprokopenko-codex-pending-requests)))
           (session (car pending))
           (request (cdr pending)))
      (unless pending
        (user-error "No pending Codex requests"))
      (when kprokopenko-codex-review-origin
        (set-marker (plist-get kprokopenko-codex-review-origin :point) nil))
      (setq kprokopenko-codex-review-origin
            (unless (eq (current-buffer) (codex-ide-session-buffer session))
              (list :point (point-marker)
                    :review-buffer (codex-ide-session-buffer session))))
      (switch-to-buffer (codex-ide-session-buffer session))
      (let ((start (codex-ide-approvals-data-view-get request :start-marker)))
        (goto-char (if (and (markerp start) (marker-position start))
                       start
                     (point-max)))))))

(defvar kprokopenko-codex-approval-mode-line-map
  (let ((map (make-sparse-keymap)))
    (define-key map [mode-line mouse-1] #'kprokopenko-codex-review-request)
    map)
  "Mouse binding for the pending Codex request indicator.")

(defun kprokopenko-codex-approval-indicator ()
  "Show the number of pending Codex requests in every mode line."
  (let ((count (length (kprokopenko-codex-pending-requests))))
    (when (> count 0)
      (propertize (format " Appr[%d]" count)
                  'face 'warning
                  'mouse-face 'mode-line-highlight
                  'help-echo "Click to review a pending Codex request"
                  'local-map kprokopenko-codex-approval-mode-line-map))))

(add-to-list 'global-mode-string
             '(:eval (kprokopenko-codex-approval-indicator))
             t)

(defface kprokopenko-codex-idle-mode-line
  '((t :weight bold))
  "Bold indicator for Codex chats that are ready for input."
  :group 'codex-ide)

(defun kprokopenko-codex-idle-sessions ()
  "Return live Codex sessions that are idle."
  (seq-filter (lambda (session)
                (and (buffer-live-p (codex-ide-session-buffer session))
                     (equal (codex-ide-session-status session) "idle")))
              codex-ide--sessions))

(defvar kprokopenko-codex-idle-origin nil
  "Marker and chat buffer saved when visiting an idle Codex chat.")

(defun kprokopenko-codex-visit-idle ()
  "Visit an idle Codex chat, or return to the previous buffer."
  (interactive)
  (if (and kprokopenko-codex-idle-origin
           (eq (current-buffer)
               (plist-get kprokopenko-codex-idle-origin :chat-buffer)))
      (let ((origin (plist-get kprokopenko-codex-idle-origin :point)))
        (setq kprokopenko-codex-idle-origin nil)
        (when (marker-buffer origin)
          (switch-to-buffer (marker-buffer origin))
          (goto-char origin))
        (set-marker origin nil))
    (let* ((buffers (mapcar #'codex-ide-session-buffer
                            (kprokopenko-codex-idle-sessions)))
           (buffer (pcase buffers
                     ('nil (user-error "No idle Codex chats"))
                     (`(,only) only)
                     (_ (get-buffer
                         (completing-read "Idle Codex chat: "
                                          (mapcar #'buffer-name buffers)
                                          nil t))))))
      (when kprokopenko-codex-idle-origin
        (set-marker (plist-get kprokopenko-codex-idle-origin :point) nil))
      (setq kprokopenko-codex-idle-origin
            (unless (eq (current-buffer) buffer)
              (list :point (point-marker) :chat-buffer buffer)))
      (switch-to-buffer buffer)
      (goto-char (point-max)))))

(defvar kprokopenko-codex-idle-mode-line-map
  (let ((map (make-sparse-keymap)))
    (define-key map [mode-line mouse-1] #'kprokopenko-codex-visit-idle)
    map)
  "Mouse binding for the idle Codex chat indicator.")

(defun kprokopenko-codex-idle-indicator ()
  "Show the number of idle Codex chats in every mode line."
  (let ((count (length (kprokopenko-codex-idle-sessions))))
    (when (> count 0)
      (propertize (format " Idle[%d] " count)
                  'face 'kprokopenko-codex-idle-mode-line
                  'mouse-face 'mode-line-highlight
                  'help-echo "Click to visit an idle Codex chat / return"
                  'local-map kprokopenko-codex-idle-mode-line-map))))

(add-to-list 'global-mode-string
             '(:eval (kprokopenko-codex-idle-indicator))
             t)

(defun kprokopenko-codex-visit-ready ()
  "Visit a pending Codex request, otherwise an idle chat."
  (interactive)
  (if (kprokopenko-codex-pending-requests)
      (kprokopenko-codex-review-request)
    (kprokopenko-codex-visit-idle)))

(keymap-global-set "C-x v" #'kprokopenko-codex-visit-ready)

(defun kprokopenko-codex-notify-interactive-request (session message-text)
  "Notify about a Codex request without changing the window layout."
  (message message-text (buffer-name (codex-ide-session-buffer session))))

(advice-add 'codex-ide--notify-interactive-request
            :override #'kprokopenko-codex-notify-interactive-request)
(add-hook 'codex-ide-session-event-hook
          (lambda (_event _session _payload)
            (force-mode-line-update t)))
(transient-append-suffix 'codex-ide-menu "l"
                         '("v" "Visit approval / idle / return"
                           kprokopenko-codex-visit-ready))

;; Chat and in-buffer rewriting through the ChatGPT subscription.
;; OAuth credentials are stored separately from the Codex CLI sign-in.
(use-package gptel
  :vc (:url "https://github.com/karthink/gptel" :rev :newest)
  :commands (gptel gptel-send gptel-menu gptel-rewrite gptel-add gptel-add-file)
  :config
  (setq gptel-model 'gpt-6-sol
        gptel-backend
        (gptel-make-openai-oauth
         "OpenAI subscription"
         :request-params '(:reasoning (:effort "high")))
        gptel-display-buffer-action
        '((display-buffer-same-window)
          (body-function . select-window))))

(use-package magit
  :bind ("C-x g" . magit-status))

;; Browse GitHub pull requests from Magit and review their diffs in Emacs.
(use-package forge
  :after magit)

(use-package github-review
  :commands (github-review-start github-review-forge-pr-at-point))

;; Open Markdown as a rendered document in the same buffer.  Option-E
;; switches between the read-only rendering and the editable source.
(use-package textui
  :vc (:url "https://github.com/yibie/textui" :rev :newest))

(use-package md-mode
  :vc (:url "https://github.com/yibie/md-mode" :rev :newest)
  :mode (("\\.md\\'" . md-mode)
         ("\\.markdown\\'" . md-mode))
  :hook (md-mode . md-mode-render)
  :bind (:map md-mode-map
              ("s-e" . md-mode-toggle-markup)))

;; JSON and JSON with comments: syntax, formatting and JSON path commands.
(use-package json-mode
  :mode (("\\.json\\'" . json-mode)
         ("\\.jsonc\\'" . jsonc-mode)
         ("\\.code-workspace\\'" . jsonc-mode)))

;; YAML files use Eglot for diagnostics, schemas and completion.
(use-package yaml-mode
  :mode ("\\.ya?ml\\'" . yaml-mode))

;; Terraform syntax highlighting and formatting commands.
(use-package terraform-mode
  :mode ("\\.tf\\(vars\\)?\\'" . terraform-mode))

;; Go's major mode also handles go.mod and go.work.
(use-package go-mode
  :mode (("\\.go\\'" . go-mode)
         ("go\\.mod\\'" . go-dot-mod-mode)
         ("go\\.work\\'" . go-dot-work-mode))
  :config
  (keymap-set go-mode-map "C-c g t" #'go-test-current-test)
  (keymap-set go-mode-map "C-c g f" #'go-test-current-file)
  (keymap-set go-mode-map "C-c g a" #'kprokopenko-go-test-module)
  (keymap-set go-mode-map "C-c g r" #'go-test-current-test-cache)
  (keymap-set go-mode-map "C-c g v" #'kprokopenko-go-vet-module)
  (keymap-set go-mode-map "C-c g s" #'kprokopenko-go-staticcheck-module)
  (keymap-set go-mode-map "C-c g i" #'eglot-code-action-organize-imports)
  (keymap-set go-mode-map "C-c g d" #'dape))

(use-package gotest
  :commands (go-test-current-test go-test-current-file
             go-test-current-test-cache))

;; Use a project's virtual environment for its REPL, tests and debugger.
(defun kprokopenko-python-venv-python ()
  "Return the active or nearest project virtual environment's Python."
  (let* ((root (locate-dominating-file default-directory ".venv/bin/python"))
         (local-python (and root (expand-file-name ".venv/bin/python" root)))
         (active (getenv "VIRTUAL_ENV"))
         (active-python (and active (expand-file-name "bin/python" active))))
    (cond ((and local-python (file-executable-p local-python)) local-python)
          ((and active-python (file-executable-p active-python)) active-python))))

(defun kprokopenko-python-interpreter ()
  "Return the Python interpreter for the current buffer."
  (or (kprokopenko-python-venv-python)
      (executable-find "python3")
      (executable-find "python")))

(defun kprokopenko-python-setup ()
  "Use the project Python for the interactive shell."
  (setq-local python-shell-interpreter (kprokopenko-python-interpreter)))

(add-hook 'python-base-mode-hook #'kprokopenko-python-setup)

(defun kprokopenko-python-unittest-project-p (root)
  "Return non-nil if ROOT has only unittest test files."
  (let ((test-directory (expand-file-name "tests" root)))
    (and (file-directory-p test-directory)
         (let ((files (directory-files-recursively
                       test-directory "test[^/]*\\.py\\'")))
           (and files
                (catch 'mixed
                  (dolist (file files)
                    (with-temp-buffer
                      (insert-file-contents file)
                      (goto-char (point-min))
                      (unless (search-forward "unittest.TestCase" nil t)
                        (throw 'mixed nil))
                      (goto-char (point-min))
                      (when (re-search-forward
                             "^\\(?:async \\)?def test_\\|^\\(?:from\\|import\\) pytest\\_>"
                             nil t)
                        (throw 'mixed nil))))
                  t))))))

(defun kprokopenko-python-unittest-command (python target)
  "Build a unittest command for Python and pytest-style TARGET."
  (let ((base (concat (shell-quote-argument python)
                      " -m unittest discover -s ")))
    (if (equal target ".")
        (concat base "tests -v")
      (let* ((parts (split-string target "::"))
             (file (car parts))
             (selector (mapconcat #'identity (cdr parts) "."))
             (command (concat base
                              (shell-quote-argument
                               (directory-file-name (file-name-directory file)))
                              " -p "
                              (shell-quote-argument (file-name-nondirectory file)))))
        (when (cdr parts)
          (unless (string-match-p "\\`[[:word:]_]+\\.[[:word:]_]+\\'" selector)
            (user-error "Select a unittest.TestCase method"))
          (setq command (concat command " -k "
                                (shell-quote-argument (concat "*." selector)))))
        (concat command " -v")))))

(defun kprokopenko-python-test (target)
  "Run TARGET with pytest, or unittest when pytest is unavailable."
  (let* ((project (project-current nil))
         (default-directory (if project (project-root project) default-directory))
         (python (kprokopenko-python-venv-python))
         (pytest (if python
                     (when (eq 0 (call-process python nil nil nil
                                               "-c" "import pytest"))
                       (concat (shell-quote-argument python) " -m pytest"))
                   (executable-find "pytest"))))
    (cond
     (pytest
      (compile (concat pytest " " (shell-quote-argument target))))
     ((kprokopenko-python-unittest-project-p default-directory)
      (compile (kprokopenko-python-unittest-command (kprokopenko-python-interpreter) target)))
     (t
      (user-error "pytest is not installed in the project Python environment")))))

(defun kprokopenko-python-test-at-point ()
  "Run the Python test at point."
  (interactive)
  (unless buffer-file-name
    (user-error "This Python buffer has no file"))
  (let ((test (python-info-current-defun)))
    (unless test
      (user-error "Point is not inside a Python test"))
    (kprokopenko-python-test
     (concat buffer-file-name "::"
             (replace-regexp-in-string "\\." "::" test)))))

(defun kprokopenko-python-test-file ()
  "Run tests in the current Python file."
  (interactive)
  (unless buffer-file-name
    (user-error "This Python buffer has no file"))
  (kprokopenko-python-test buffer-file-name))

(defun kprokopenko-python-test-project ()
  "Run all Python tests in the current project."
  (interactive)
  (kprokopenko-python-test "."))

(defun kprokopenko-python-lint-project ()
  "Run Ruff checks in the current project."
  (interactive)
  (let* ((project (project-current nil))
         (default-directory (if project (project-root project) default-directory)))
    (compile "ruff check .")))

(defvar-local kprokopenko-diagnostics-enabled nil
  "Whether Flymake diagnostics are visible in this buffer.")

(defun kprokopenko-python-ruff-backend (report-fn &rest _args)
  "Report Ruff findings from the current buffer to Flymake."
  (let ((source (current-buffer))
        (filename (or buffer-file-name
                      (expand-file-name "stdin.py" default-directory))))
    (condition-case err
        (with-temp-buffer
          (let* ((output (current-buffer))
                 (status
                  (with-current-buffer source
                    (save-restriction
                      (widen)
                      (call-process-region
                       (point-min) (point-max) (executable-find "ruff")
                       nil output nil "check" "--output-format" "json"
                       "--stdin-filename" filename "-")))))
            (if (not (memq status '(0 1)))
                (funcall report-fn :panic :explanation (buffer-string))
              (goto-char (point-min))
              (let ((findings (json-parse-buffer :array-type 'list
                                                 :object-type 'hash-table)))
                (funcall report-fn
                         (delq nil
                               (mapcar
                                (lambda (finding)
                                  (let* ((location (gethash "location" finding))
                                         (region
                                          (flymake-diag-region
                                           source (gethash "row" location)
                                           (gethash "column" location))))
                                    (when region
                                      (flymake-make-diagnostic
                                       source (car region) (cdr region) :note
                                       (format "Ruff %s: %s"
                                               (gethash "code" finding)
                                               (gethash "message" finding))))))
                                findings)))))))
      (error (funcall report-fn :panic
                      :explanation (error-message-string err))))))

(defun kprokopenko-diagnostics-default-off ()
  "Keep Flymake diagnostics hidden until explicitly enabled."
  (when (and flymake-mode (not kprokopenko-diagnostics-enabled))
    (flymake-mode -1)))

;; Eglot enables Flymake before this hook can turn it off.  Do not start an
;; asynchronous check in that brief interval; the toggle starts it explicitly.
(setq flymake-start-on-flymake-mode nil)
(add-hook 'flymake-mode-hook #'kprokopenko-diagnostics-default-off)

(defun kprokopenko-diagnostics-toggle ()
  "Toggle all available Flymake diagnostics in this buffer."
  (interactive)
  (require 'flymake)
  (if (and kprokopenko-diagnostics-enabled flymake-mode)
      (progn
        (setq-local kprokopenko-diagnostics-enabled nil)
        (remove-hook 'flymake-diagnostic-functions
                     #'kprokopenko-python-ruff-backend t)
        (flymake-mode -1)
        (message "Diagnostics off"))
    (when (and (derived-mode-p 'python-base-mode)
               (not (executable-find "ruff")))
      (user-error "Ruff is not installed"))
    (setq-local kprokopenko-diagnostics-enabled t)
    (when (derived-mode-p 'python-base-mode)
      (add-hook 'flymake-diagnostic-functions
                #'kprokopenko-python-ruff-backend nil t))
    (flymake-mode 1)
    (flymake-start)
    (message "Diagnostics on")))

(keymap-global-set "C-c p h" #'kprokopenko-diagnostics-toggle)

(with-eval-after-load 'python
  (keymap-set python-base-mode-map "C-c p t" #'kprokopenko-python-test-at-point)
  (keymap-set python-base-mode-map "C-c p f" #'kprokopenko-python-test-file)
  (keymap-set python-base-mode-map "C-c p a" #'kprokopenko-python-test-project)
  (keymap-set python-base-mode-map "C-c p l" #'kprokopenko-python-lint-project)
  (keymap-set python-base-mode-map "C-c p h" #'kprokopenko-diagnostics-toggle)
  (keymap-set python-base-mode-map "C-c p r" #'run-python)
  (keymap-set python-base-mode-map "C-c p d" #'dape))

(use-package ruff-format
  :commands ruff-format-buffer)

(defun kprokopenko-eglot-imenu-for-new-terraform-file (original)
  "Ignore a missing-file symbol response for a new Terraform buffer."
  (condition-case err
      (funcall original)
    (jsonrpc-error
     (let ((message (alist-get 'jsonrpc-error-message (cdr err))))
       (if (and (derived-mode-p 'terraform-mode)
                buffer-file-name
                (not (file-exists-p buffer-file-name))
                (equal (alist-get 'jsonrpc-error-code (cdr err)) -32098)
                (stringp message)
                (string-suffix-p "file not found" message))
           nil
         (signal (car err) (cdr err)))))))

(use-package eglot
  :ensure nil
  :hook ((python-base-mode . eglot-ensure)
         (go-mode . eglot-ensure)
         (go-dot-mod-mode . eglot-ensure)
         (go-dot-work-mode . eglot-ensure)
         (json-mode . eglot-ensure)
         (jsonc-mode . eglot-ensure)
         (yaml-mode . eglot-ensure)
         (terraform-mode . eglot-ensure))
  :config
  (add-to-list 'eglot-server-programs
               '((python-mode python-ts-mode)
                 "basedpyright-langserver" "--stdio"))
  (advice-add 'eglot-imenu :around
              #'kprokopenko-eglot-imenu-for-new-terraform-file))

(use-package eldoc-box
  :bind (:map eglot-mode-map
              ("C-c d" . eldoc-box-help-at-point)))

(use-package corfu
  :hook ((prog-mode . corfu-mode)
         (json-mode . corfu-mode)
         (jsonc-mode . corfu-mode)
         (yaml-mode . corfu-mode)
         (terraform-mode . corfu-mode))
  :init
  (setq corfu-auto t
        corfu-cycle t))

(use-package dape
  :commands dape
  :config
  ;; The adapter lives in pipx; the debugged process uses the project's Python.
  (dolist (name '(debugpy debugpy-module))
    (let ((config (alist-get name dape-configs)))
      (setf (plist-get config 'command) "debugpy-adapter"
            (plist-get config 'command-args)
            '("--host" "127.0.0.1" "--port" :autoport)
            (plist-get config 'ensure) #'dape-ensure-command
            (plist-get config :python) [kprokopenko-python-interpreter])
      (setf (alist-get name dape-configs) config))))

(defun kprokopenko-go-module-directory ()
  "Return the nearest Go module root or the current directory."
  (or (locate-dominating-file default-directory "go.mod")
      default-directory))

(defun kprokopenko-go-test-module ()
  "Run all tests in the nearest Go module."
  (interactive)
  (let ((default-directory (kprokopenko-go-module-directory)))
    (compile "go test ./...")))

(defun kprokopenko-go-vet-module ()
  "Run go vet in the nearest Go module."
  (interactive)
  (let ((default-directory (kprokopenko-go-module-directory)))
    (compile "go vet ./...")))

(defun kprokopenko-go-staticcheck-module ()
  "Run staticcheck in the nearest Go module."
  (interactive)
  (let ((default-directory (kprokopenko-go-module-directory)))
    (compile "staticcheck ./...")))

(defun kprokopenko-format-before-save ()
  "Format this buffer with its available code formatter."
  (cond
   ((derived-mode-p 'python-base-mode)
    (ruff-format-buffer))
   ((derived-mode-p 'terraform-mode)
    (terraform-format-buffer))
   ((derived-mode-p 'go-mode)
    (if (eglot-managed-p)
        (eglot-format-buffer)
      (gofmt)))
   ((and (eglot-managed-p)
         (eglot-server-capable :documentFormattingProvider))
    (eglot-format-buffer))))

(defun kprokopenko-enable-format-on-save ()
  "Enable code formatting when this buffer is saved."
  (add-hook 'before-save-hook #'kprokopenko-format-before-save nil t))

(add-hook 'prog-mode-hook #'kprokopenko-enable-format-on-save)
(dolist (hook '(json-mode-hook jsonc-mode-hook yaml-mode-hook
                terraform-mode-hook))
  (add-hook hook #'kprokopenko-enable-format-on-save))

;; Restore the previous session after all major-mode hooks are configured.
(save-place-mode 1)
(savehist-mode 1)
(recentf-mode 1)
(setq desktop-load-locked-desktop 'check-pid)
(setq desktop-save t)
(desktop-save-mode 1)

;; Command is Meta after the modifier swap; keep Command-Up/Down navigation.
(keymap-global-set "M-<up>" #'beginning-of-buffer)
(keymap-global-set "M-<down>" #'end-of-buffer)

;; Copy a link to the current source location.
(require 'subr-x)
(require 'url-util)

(defun kprokopenko--git-output (directory &rest args)
  "Return Git output for ARGS in DIRECTORY, or nil on failure."
  (let ((default-directory directory))
    (with-temp-buffer
      (when (eq 0 (apply #'process-file "git" nil t nil args))
        (string-trim (buffer-string))))))

(defun kprokopenko--github-repository (remote)
  "Return OWNER/REPO from a GitHub REMOTE, or nil."
  (when remote
    (let ((url (string-remove-suffix ".git" (string-remove-suffix "/" remote))))
      (cond
       ((string-match "\\`\\(?:https?://\\|ssh://git@\\)github\\.com/\\([^?#]+\\)\\'" url)
        (match-string 1 url))
       ((string-match "\\`git@github\\.com:\\([^?#]+\\)\\'" url)
        (match-string 1 url))))))

(defvar kprokopenko-code-link-functions nil
  "Functions called with a path to return a source URL, or nil.
The first non-nil result takes precedence over GitHub links.")

(defun kprokopenko-copy-code-link ()
  "Copy a source link for the current file or Dired entry."
  (interactive)
  (let* ((in-dired (derived-mode-p 'dired-mode))
         (path (if in-dired (dired-get-file-for-visit) (buffer-file-name)))
         (directory (when path (if (file-directory-p path)
                                   path
                                 (file-name-directory path))))
         (line (if (or in-dired (not path) (file-directory-p path))
                   ""
                 (format "#L%d" (line-number-at-pos))))
         (base
          (cond
           ((and path (run-hook-with-args-until-success
                       'kprokopenko-code-link-functions path)))
           (directory
            (let* ((git-root (kprokopenko--git-output directory "rev-parse" "--show-toplevel"))
                   (remote (and git-root
                                (kprokopenko--git-output directory "remote" "get-url" "origin")))
                   (repo (kprokopenko--github-repository remote))
                   (revision (and repo (kprokopenko--git-output directory "rev-parse" "HEAD"))))
              (unless (and git-root repo revision)
                (user-error "Current file is outside a GitHub repository with origin"))
              (let ((relative (file-relative-name path git-root)))
                (concat "https://github.com/" repo "/"
                        (if (file-directory-p path) "tree" "blob")
                        "/" revision
                        (unless (member relative '("." "./"))
                          (concat "/" relative))))))
           (t (user-error "Current buffer does not visit a file")))))
    (let ((url (concat (url-encode-url base) line)))
      (kill-new url)
      (message "Copied: %s" url)
      url)))

(keymap-global-set "C-c L" #'kprokopenko-copy-code-link)

;; Load private settings when available.
(load (expand-file-name "local/init.el" user-emacs-directory) t t)

;;; init.el ends here
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(codex codex-ide consult corfu csv-mode dape eldoc-box forge
           github-review go-mode gotest gptel json-mode marginalia
           md-mode orderless reverse-im ruff-format terraform-mode
           vertico visual-fill-column yaml-mode)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
