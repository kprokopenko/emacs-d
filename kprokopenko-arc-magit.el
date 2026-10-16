;;; kprokopenko-arc-magit.el --- Arc status with Magit sections -*- lexical-binding: t; -*-

(require 'json)
(require 'cl-lib)
(require 'subr-x)
(require 'magit-section)
(require 'diff-mode)

(defclass kprokopenko-arc-root-section (magit-section) ())
(defclass kprokopenko-arc-group-section (magit-section) ())
(defclass kprokopenko-arc-file-section (magit-section) ())

(defvar-local kprokopenko-arc-root nil)

(defun kprokopenko-arc-find-root (&optional directory)
  "Return the Arcadia root containing DIRECTORY, if any."
  (let ((root (locate-dominating-file (or directory default-directory)
                                    ".arcadia.root")))
    (when (and root (file-exists-p (expand-file-name ".arc" root)))
      (file-name-as-directory root))))

(defun kprokopenko-arc--run (&rest args)
  "Run Arc with ARGS at `kprokopenko-arc-root' and return its output."
  (let ((default-directory kprokopenko-arc-root))
    (with-temp-buffer
      (let ((exit (apply #'process-file "arc" nil
                         (list (current-buffer) t) nil args)))
        (unless (eq exit 0)
          (error "arc %s failed: %s" (car args) (string-trim (buffer-string))))
        (buffer-string)))))

(defun kprokopenko-arc--status-entries (output)
  "Parse the staged and unstaged file entries in Arc short status OUTPUT."
  (let (staged unstaged untracked)
    (dolist (line (split-string output "\n" t))
      (when (string-match "\\`\\(..\\) \\(.*\\)\\'" line)
        (let* ((state (match-string 1 line))
               (path (match-string 2 line))
               (entry (cons state path)))
          (cond ((equal state "??") (push entry untracked))
                (t
                 (unless (eq (aref state 0) ?\s) (push entry staged))
                 (unless (eq (aref state 1) ?\s) (push entry unstaged)))))))
    (list (cons 'staged (nreverse staged))
          (cons 'unstaged (nreverse unstaged))
          (cons 'untracked (nreverse untracked)))))

(defun kprokopenko-arc--file-path (entry)
  "Return the current path of status ENTRY, including a rename."
  (let ((path (cdr entry)))
    (if (string-match " -> \\(.*\\)\\'" path)
        (match-string 1 path)
      path)))

(defun kprokopenko-arc--insert-diff (layer path)
  (let ((output (cond ((eq layer 'staged)
                       (kprokopenko-arc--run "diff" "--cached" "--color=never" "--" path))
                      ((eq layer 'unstaged)
                       (kprokopenko-arc--run "diff" "--color=never" "--" path))
                      (t "Open the file to inspect its contents.\n"))))
    (if (string-empty-p output)
        (insert "  No textual diff.\n")
      (insert output)
      (unless (bolp) (insert "\n")))))

(defun kprokopenko-arc--insert-group (layer entries title)
  (when entries
    (magit-insert-section (kprokopenko-arc-group-section layer)
      (magit-insert-heading (format "%s (%d)" title (length entries)))
      (dolist (entry entries)
        (let ((path (kprokopenko-arc--file-path entry)))
          (magit-insert-section (kprokopenko-arc-file-section (cons layer path) t)
            (magit-insert-heading (format "  %s %s" (car entry) (cdr entry)))
            (magit-insert-section-body
              (kprokopenko-arc--insert-diff layer path)))))
      (insert "\n"))))

(defvar-keymap kprokopenko-arc-status-mode-map
  :parent magit-section-mode-map
  "g" #'kprokopenko-arc-refresh
  "s" #'kprokopenko-arc-stage
  "u" #'kprokopenko-arc-unstage
  "c" #'kprokopenko-arc-commit
  "d" #'kprokopenko-arc-diff
  "l" #'kprokopenko-arc-log
  "b" #'kprokopenko-arc-branch
  "F" #'kprokopenko-arc-pull
  "P" #'kprokopenko-arc-push
  "z" #'kprokopenko-arc-stash
  "!" #'kprokopenko-arc-command
  "RET" #'kprokopenko-arc-visit
  "?" #'kprokopenko-arc-help)

(define-derived-mode kprokopenko-arc-status-mode magit-section-mode "Arc-Status"
  "Show Arc status using Magit's collapsible sections.")

(defun kprokopenko-arc-status (&optional directory)
  "Show Arc status for DIRECTORY."
  (interactive)
  (let ((root (or (kprokopenko-arc-find-root directory)
                  (user-error "Not inside an Arcadia checkout"))))
    (let ((buffer (get-buffer-create (format "*arc-status: %s*" root))))
      (with-current-buffer buffer
        (unless (derived-mode-p 'kprokopenko-arc-status-mode)
          (kprokopenko-arc-status-mode))
        (setq-local kprokopenko-arc-root root)
        (setq default-directory root)
        (kprokopenko-arc-refresh))
      (pop-to-buffer buffer))))

(defun kprokopenko-arc-refresh ()
  "Refresh the Arc status buffer."
  (interactive)
  (let* ((info (json-parse-string (kprokopenko-arc--run "info" "--json")
                                  :object-type 'alist))
         (groups (kprokopenko-arc--status-entries
                  (kprokopenko-arc--run "status" "--short")))
         (position (point)))
    (let ((inhibit-read-only t))
      (erase-buffer)
      (setq magit-root-section nil)
      (magit-insert-section (kprokopenko-arc-root-section)
        (insert (format "Arcadia  %s\n" (alist-get 'branch info)))
        (insert (format "HEAD     %s\n\n" (alist-get 'hash info)))
        (kprokopenko-arc--insert-group 'staged (alist-get 'staged groups)
                                "Staged changes")
        (kprokopenko-arc--insert-group 'unstaged (alist-get 'unstaged groups)
                                "Unstaged changes")
        (kprokopenko-arc--insert-group 'untracked (alist-get 'untracked groups)
                                "Untracked files")
        (when (cl-every #'null (mapcar #'cdr groups))
          (insert "Working tree clean\n"))))
    (let ((magit-section-cache-visibility nil))
      (magit-section-show magit-root-section))
    (goto-char (min position (point-max)))
    (magit-section-update-highlight)
    (set-buffer-modified-p nil)))

(defun kprokopenko-arc--current-file (&optional heading-only)
  (let ((section (magit-current-section)))
    (unless (and section (object-of-class-p section 'kprokopenko-arc-file-section))
      (user-error "Select a file section first"))
    (when (and heading-only (> (point) (oref section content)))
      (user-error "Stage and unstage work on whole files; move to the file heading"))
    (oref section value)))

(defun kprokopenko-arc-stage ()
  "Stage the file at point using `arc add'."
  (interactive)
  (pcase-let ((`(,_layer . ,path) (kprokopenko-arc--current-file t)))
    (kprokopenko-arc--run "add" "--" path)
    (kprokopenko-arc-refresh)))

(defun kprokopenko-arc-unstage ()
  "Unstage the file at point using `arc reset HEAD'."
  (interactive)
  (pcase-let ((`(,layer . ,path) (kprokopenko-arc--current-file t)))
    (unless (eq layer 'staged)
      (user-error "Select a staged file to unstage"))
    (kprokopenko-arc--run "reset" "HEAD" path)
    (kprokopenko-arc-refresh)))

(defun kprokopenko-arc--show-output (title output &optional diff)
  (let ((buffer (get-buffer-create (format "*arc-%s*" title)))
        (root kprokopenko-arc-root))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert output)
        (goto-char (point-min))
        (if diff (diff-mode) (special-mode))
        (setq-local default-directory root)
        (setq-local kprokopenko-arc-root root)))
    (pop-to-buffer buffer)))

(defun kprokopenko-arc-diff (&optional scope)
  "Show an Arc diff for the selected file or SCOPE."
  (interactive)
  (let* ((section (magit-current-section))
         (file (and section (object-of-class-p section 'kprokopenko-arc-file-section)
                    (oref section value)))
         (scope (or (car-safe file)
                    scope
                    (intern (completing-read "Diff: "
                                             '("unstaged" "staged" "branch")
                                             nil t)))))
    (kprokopenko-arc--show-output
     "diff"
     (apply #'kprokopenko-arc--run
            (append (list "diff" "--color=never")
                    (pcase scope
                      ('staged '("--cached"))
                      ('branch '("-B"))
                      (_ nil))
                    (when file (list "--" (cdr file)))))
     t)))

(defun kprokopenko-arc-visit ()
  "Visit the file at point."
  (interactive)
  (pcase-let ((`(,_layer . ,path) (kprokopenko-arc--current-file)))
    (find-file (expand-file-name path kprokopenko-arc-root))))

(defun kprokopenko-arc-commit (message)
  "Commit staged changes with MESSAGE using Arc."
  (interactive (list (read-string "Commit message: ")))
  (when (string-empty-p message) (user-error "Commit message is empty"))
  (message "%s" (string-trim (kprokopenko-arc--run "commit" "-m" message)))
  (kprokopenko-arc-refresh))

(defun kprokopenko-arc-log ()
  "Show the latest 30 Arc commits."
  (interactive)
  (kprokopenko-arc--show-output "log" (kprokopenko-arc--run "log" "-n" "30" "--oneline")))

(defun kprokopenko-arc-branch ()
  "Create or switch to an Arc branch."
  (interactive)
  (let ((action (completing-read "Branch action: " '("checkout" "create") nil t))
        (name (read-string "Branch name: ")))
    (when (string-empty-p name) (user-error "Branch name is empty"))
    (if (equal action "create")
        (kprokopenko-arc--run "checkout" "-b" name "trunk")
      (kprokopenko-arc--run "checkout" name))
    (kprokopenko-arc-refresh)))

(defun kprokopenko-arc-pull (&optional from)
  "Pull from FROM, or the tracked branch when FROM is empty."
  (interactive (list (read-string "Pull from (empty for tracked branch): ")))
  (message "%s" (string-trim (if (string-empty-p (or from ""))
                                  (kprokopenko-arc--run "pull")
                                (kprokopenko-arc--run "pull" from))))
  (kprokopenko-arc-refresh))

(defun kprokopenko-arc-push ()
  "Push the current branch using Arc."
  (interactive)
  (let* ((info (json-parse-string (kprokopenko-arc--run "info" "--json")
                                  :object-type 'alist))
         (branch (alist-get 'branch info)))
    (message "%s"
             (string-trim
              (if (string-prefix-p "users/" branch)
                  (kprokopenko-arc--run "push" "-u" branch)
                (kprokopenko-arc--run "push")))))
  (kprokopenko-arc-refresh))

(defun kprokopenko-arc-stash ()
  "Run an Arc stash action."
  (interactive)
  (let ((action (completing-read "Stash action: " '("push" "pop" "list") nil t)))
    (pcase action
      ("push" (message "%s" (string-trim
                             (kprokopenko-arc--run "stash" "push" "-m"
                                            (read-string "Stash message: ")))))
      ("pop" (message "%s" (string-trim (kprokopenko-arc--run "stash" "pop"))))
      ("list" (kprokopenko-arc--show-output "stash" (kprokopenko-arc--run "stash" "list"))))
    (unless (equal action "list") (kprokopenko-arc-refresh))))

(defun kprokopenko-arc-command (command)
  "Run Arc COMMAND in this checkout, without a shell."
  (interactive (list (read-string "arc " )))
  (let ((args (split-string-and-unquote command)))
    (unless args (user-error "Arc command is empty"))
    (let ((output (apply #'kprokopenko-arc--run args)))
      (kprokopenko-arc-refresh)
      (kprokopenko-arc--show-output "command" output))))

(defun kprokopenko-arc-help ()
  "Show the Arc status key bindings."
  (interactive)
  (message "Arc: g refresh, TAB diff, RET file, s stage, u unstage, c commit, d diff, l log, b branch, F pull, P push, z stash, ! arc command"))

(defvar kprokopenko-arc--original-magit-status (symbol-function 'magit-status))

(defun kprokopenko-arc--magit-status-dispatch (&optional directory cache)
  "Open Arc status in Arcadia, otherwise invoke the original Magit command."
  (interactive)
  (if (kprokopenko-arc-find-root directory)
      (kprokopenko-arc-status directory)
    (if (called-interactively-p 'interactive)
        (call-interactively kprokopenko-arc--original-magit-status)
      (funcall kprokopenko-arc--original-magit-status directory cache))))

(fset 'magit-status #'kprokopenko-arc--magit-status-dispatch)

(provide 'kprokopenko-arc-magit)
;;; kprokopenko-arc-magit.el ends here
