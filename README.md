# Emacs configuration

Open `/Applications/Emacs.app` to start Emacs in macOS fullscreen.
Use `Command-P` to open the Emacs command prompt (`M-x`).

## Russian input

Use the existing macOS `Command-Space` shortcut to switch between U.S. and
RussianWin. The `reverse-im` package keeps Emacs shortcuts on the same physical
letter keys when RussianWin is active.

As an alternative, leave the macOS source on U.S. and use Emacs's built-in
`C-\` to toggle `russian-computer` in the current buffer. This Emacs input
method is local to each buffer. Use one switching method at a time.

`Command-Space` is handled by macOS as a global input-source shortcut; Emacs
cannot intercept it while that system shortcut is enabled. On this machine,
`Control-Space` opens Spotlight.

Run `M-x codex` to start Codex in the current project. `C-c x` opens the
Codex command map. The integration runs the installed Codex CLI and uses its
existing ChatGPT sign-in and `~/.codex/config.toml`; credentials are never
copied into this repository.

The Emacs daemon is deliberately not enabled for this initial setup. This
small configuration starts quickly, while a daemon requires a separate
macOS login service and changes the lifetime of buffers and sessions.

To reinstall the Codex package and its dependencies, run:

```sh
emacs --batch --init-directory "$HOME/.emacs.d" -l "$HOME/.emacs.d/install.el"
```
