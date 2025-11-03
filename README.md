# ENVSetup

Tools and notes for automating the local tmux environment setup.

## Layout

- `design/` – working notes and implementation plan.
- `env_setup.sh` – interactive shell script that installs required tooling and applies profile configs.
- `profile_config/` – reusable tmux/zsh profile sources (`default/`, `developer/`, etc.).
- `menu_helpers/` – helper scripts invoked by shell shortcuts (e.g., `tmux_menu.sh`).

## Getting Started

```bash
chmod +x env_setup.sh
./env_setup.sh
# Reload current shell aliases (if still in the same terminal)
source ~/.zshrc
# Reload tmux configuration for existing sessions
tmux source-file ~/.tmux.conf
```

The script first asks which profile to apply, then lets you choose whether to reload tmux/zsh automatically or just print manual commands.

Refer to `design/design_steps.md` for the checklist guiding development.
