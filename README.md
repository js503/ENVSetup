# ENVSetup

Tools and notes for automating the local tmux environment setup.

## Layout

- `design/` – working notes and implementation plan.
- `env_setup.sh` – interactive shell script that installs required tooling and applies profile configs.
- `profile_config/` – reusable tmux/zsh profile sources (`default/`, `developer/`, etc.).
- `menu_helpers/` – helper scripts invoked by shell shortcuts (e.g., `tmux_menu.sh`, `env_setup_menu.sh`).
- `~/env_setup_backups/` – timestamped backups kept for the three most recent runs.

## Getting Started

```bash
chmod +x env_setup.sh
./env_setup.sh
# Reload current shell aliases (if still in the same terminal)
source ~/.zshrc
# Reload tmux configuration for existing sessions
tmux source-file ~/.tmux.conf
```

The script first asks which profile (or backup set) to apply, then lets you choose whether to reload tmux/zsh automatically or just print manual commands. Selecting “Backups” restores one of the saved timestamped configurations.

### Menu Flow

Initial profile selection:

```
=============================================================
Environment Setup
=============================================================

Use arrow keys to choose a profile and press Enter to select.
Press 'q' at any time to exit. Vim keys (j/k) also work.

> Developer
  Default
  Backups
  Exit
```

Reload preference menu (shown after choosing a profile or backup):

```
=============================================================
Environment Setup
=============================================================

Choose how to handle configuration reloads after setup.
Press 'q' at any time to exit. Vim keys (j/k) also work.

> Reload tmux & zsh after setup
  Skip reload; show manual commands
  Cancel setup
```

Backup restore picker (visible when “Backups” is selected):

```
=============================================================
Backup Restore
=============================================================

Select a backup timestamp to restore.
Press 'q' at any time to exit. Vim keys (j/k) also work.

> 20251102204244
  20251102204236
  Cancel
```

Backups are stored under `~/env_setup_backups/<timestamp>/` with paths relative to your home directory (e.g., `.tmux.conf`, `.zshrc`, `.local/bin/tmux_menu.sh`). Each run keeps a single timestamp for all files, and older backup sets are pruned so that only the three most recent remain.

Refer to `design/design_steps.md` for the checklist guiding development.
