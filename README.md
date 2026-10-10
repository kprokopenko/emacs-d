# Emacs configuration

Open `/Applications/Emacs.app` to start Emacs in macOS fullscreen.

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
