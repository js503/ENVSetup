#!/usr/bin/env bash

# env_setup.sh - interactive helper for setting up a tmux environment.

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_PATH="${BASH_SOURCE[0]}"
readonly SCRIPT_NAME=$(basename "${SCRIPT_PATH}")
readonly SCRIPT_DIR=$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)
readonly PROJECT_ROOT="${SCRIPT_DIR}"
readonly MENU_OPTIONS=("Developer" "Default" "Exit")
readonly MENU_ARROW_TIMEOUT=1
readonly BANNER_LINE="============================================================="
readonly BANNER_TITLE="Environment Setup"
readonly INSTALL_ATTEMPTED_MSG="Attempting to install tmux automatically."
readonly GH_INSTALL_ATTEMPTED_MSG="Attempting to install GitHub CLI automatically."
readonly PROFILE_ROOT="${PROJECT_ROOT}/profile_config"
readonly DEFAULT_PROFILE="default"
readonly DEVELOPER_PROFILE="developer"
readonly TMUX_CONFIG_TARGET_DEFAULT="${HOME}/.tmux.conf"
readonly SHELL_CONFIG_TARGET_DEFAULT="${HOME}/.zshrc"
readonly TMUX_MENU_SOURCE_DEFAULT="${PROJECT_ROOT}/menu_helpers/tmux_menu.sh"
readonly TMUX_MENU_TARGET_DEFAULT="${HOME}/.local/bin/tmux_menu.sh"
TMUX_CONFIG_TARGET_PATH="${TMUX_CONFIG_TARGET:-$TMUX_CONFIG_TARGET_DEFAULT}"
readonly TMUX_CONFIG_TARGET_PATH
SHELL_CONFIG_TARGET_PATH="${SHELL_CONFIG_TARGET:-$SHELL_CONFIG_TARGET_DEFAULT}"
readonly SHELL_CONFIG_TARGET_PATH
TMUX_MENU_SOURCE_PATH="${TMUX_MENU_SOURCE:-$TMUX_MENU_SOURCE_DEFAULT}"
readonly TMUX_MENU_SOURCE_PATH
TMUX_MENU_TARGET_PATH="${TMUX_MENU_TARGET:-$TMUX_MENU_TARGET_DEFAULT}"
readonly TMUX_MENU_TARGET_PATH
readonly PROFILE_MENU_DESCRIPTION="Use arrow keys to choose a profile and press Enter to select."
readonly RELOAD_MENU_DESCRIPTION="Choose how to handle configuration reloads after setup."

declare MENU_SELECTION=""
MENU_DESCRIPTION="$PROFILE_MENU_DESCRIPTION"
AUTO_RELOAD_TMUX=false
AUTO_SOURCE_ZSH=false

print_usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [options]

Options:
  -h, --help    Show this help message and exit.
EOF
}

log_info() {
  printf "[INFO] %s\n" "$*"
}

log_error() {
  printf "[ERROR] %s\n" "$*" >&2
}

resolve_profile_path() {
  local profile=$1
  printf "%s/%s" "${PROFILE_ROOT}" "${profile}"
}

ensure_directory() {
  local dir=$1
  if [[ -d $dir ]]; then
    return 0
  fi
  if mkdir -p "$dir"; then
    return 0
  fi
  log_error "Unable to create directory: ${dir}"
  return 1
}

backup_file() {
  local target=$1
  local timestamp
  timestamp=$(date +"%Y%m%d%H%M%S")
  local backup_path="${target}.backup-${timestamp}"

  if cp "$target" "$backup_path"; then
    log_info "Created backup: ${backup_path}"
    return 0
  fi

  log_error "Failed to create backup for ${target}"
  return 1
}

copy_if_different() {
  local source=$1
  local target=$2

  if [[ -f $target ]] && cmp -s "$source" "$target"; then
    log_info "Target already up to date: ${target}"
    return 0
  fi

  if [[ -f $target ]]; then
    backup_file "$target" || return 1
  else
    ensure_directory "$(dirname "$target")" || return 1
  fi

  if cp "$source" "$target"; then
    log_info "Wrote updated file: ${target}"
    return 0
  fi

  log_error "Failed to write ${target}"
  return 1
}

reload_tmux_config() {
  if ! command -v tmux >/dev/null 2>&1; then
    log_info "Skipping tmux reload because tmux is not on PATH."
    return 0
  fi

  local target_config=${TMUX_CONFIG_TARGET_PATH/#\~/$HOME}

  log_info "Reloading tmux configuration from ${target_config}."
  tmux start-server >/dev/null 2>&1 || true
  if tmux source-file "$target_config" >/dev/null 2>&1; then
    log_info "tmux configuration reloaded into current server."
    return 0
  fi

  log_info "No active tmux server to reload; configuration will apply on next session."
  return 0
}

validate_zsh_config() {
  if ! command -v zsh >/dev/null 2>&1; then
    log_info "Skipping zsh reload because zsh is not on PATH."
    return 0
  fi

  local target_config=${SHELL_CONFIG_TARGET_PATH/#\~/$HOME}
  if [[ ! -f $target_config ]]; then
    log_info "Skipping zsh reload because target config does not exist."
    return 0
  fi

  log_info "Validating zsh configuration via non-interactive zsh shell."
  if zsh -ic "source \"$target_config\"" >/dev/null 2>&1; then
    log_info "zsh configuration validated successfully."
    return 0
  fi

  log_error "Failed to source zsh configuration; check ${target_config} for issues."
  return 1
}

source_zsh_config_now() {
  local target_config=${SHELL_CONFIG_TARGET_PATH/#\~/$HOME}

  if [[ ! -f $target_config ]]; then
    log_error "zsh configuration not found at ${target_config}."
    return 1
  fi

  if ! command -v zsh >/dev/null 2>&1; then
    log_error "zsh binary not found; cannot source configuration automatically."
    return 1
  fi

  if zsh -ic "source \"$target_config\"" >/dev/null 2>&1; then
    log_info "Sourced zsh configuration via non-interactive zsh shell."
    return 0
  fi

  log_error "Encountered an error while sourcing ${target_config}."
  return 1
}

apply_tmux_config() {
  local profile=${1:-$DEFAULT_PROFILE}
  local profile_dir
  profile_dir=$(resolve_profile_path "$profile")

  if [[ ! -d $profile_dir ]]; then
    log_error "Profile directory not found: ${profile_dir}"
    return 1
  fi

  local source_config="${profile_dir}/tmux.conf"
  if [[ ! -f $source_config ]]; then
    log_error "tmux configuration not found for profile '${profile}' (expected ${source_config})."
    return 1
  fi

  local target_config=${TMUX_CONFIG_TARGET_PATH/#\~/$HOME}
  log_info "Applying tmux config from profile '${profile}' to ${target_config}."

  copy_if_different "$source_config" "$target_config"
}

apply_shell_config() {
  local profile=${1:-$DEFAULT_PROFILE}
  local profile_dir
  profile_dir=$(resolve_profile_path "$profile")

  if [[ ! -d $profile_dir ]]; then
    log_error "Profile directory not found: ${profile_dir}"
    return 1
  fi

  local source_config="${profile_dir}/zshrc"
  if [[ ! -f $source_config ]]; then
    log_error "zsh configuration not found for profile '${profile}' (expected ${source_config})."
    return 1
  fi

  local target_config=${SHELL_CONFIG_TARGET_PATH/#\~/$HOME}
  log_info "Applying zsh config from profile '${profile}' to ${target_config}."

  copy_if_different "$source_config" "$target_config"
}

install_tmux_menu_helper() {
  local source=${TMUX_MENU_SOURCE_PATH}
  local target=${TMUX_MENU_TARGET_PATH/#\~/$HOME}

  if [[ ! -f $source ]]; then
    log_error "tmux menu helper not found at ${source}"
    return 1
  fi

  log_info "Installing tmux menu helper to ${target}."
  copy_if_different "$source" "$target" || return 1

  if chmod +x "$target"; then
    log_info "Ensured tmux menu helper is executable."
  else
    log_error "Failed to mark ${target} as executable."
    return 1
  fi

  return 0
}

choose_reload_strategy() {
  local previous_description=$MENU_DESCRIPTION
  MENU_DESCRIPTION="$RELOAD_MENU_DESCRIPTION"

  AUTO_RELOAD_TMUX=false
  AUTO_SOURCE_ZSH=false

  local options=(
    "Reload tmux & zsh after setup"
    "Skip reload; show manual commands"
    "Cancel setup"
  )

  interactive_menu "${options[@]}"
  local choice=$MENU_SELECTION

  MENU_DESCRIPTION="$previous_description"

  case $choice in
    "Reload tmux & zsh after setup")
      AUTO_RELOAD_TMUX=true
      AUTO_SOURCE_ZSH=true
      log_info "Selected: reload tmux and zsh after setup."
      return 0
      ;;
    "Skip reload; show manual commands")
      AUTO_RELOAD_TMUX=false
      AUTO_SOURCE_ZSH=false
      log_info "Selected: skip automatic reloads; manual commands will be provided."
      return 0
      ;;
    "Cancel setup"|"Exit")
      log_info "Reload preference selection canceled."
      return 1
      ;;
    *)
      log_error "Unexpected selection while choosing reload preference."
      return 1
      ;;
  esac
}

detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macOS" ;;
    Linux) echo "Linux" ;;
    *) echo "unknown" ;;
  esac
}

detect_package_manager() {
  if command -v brew >/dev/null 2>&1; then
    echo "brew"
    return 0
  fi
  if command -v apt-get >/dev/null 2>&1; then
    echo "apt-get"
    return 0
  fi
  return 1
}

install_tmux() {
  local manager
  if ! manager=$(detect_package_manager); then
    log_error "Unable to detect a supported package manager. Install tmux manually and re-run."
    return 1
  fi

  case "$manager" in
    brew)
      log_info "$INSTALL_ATTEMPTED_MSG Using Homebrew."
      if brew list --formula tmux >/dev/null 2>&1; then
        log_info "tmux already available via Homebrew."
        return 0
      fi
      if brew install tmux; then
        log_info "tmux installed successfully with Homebrew."
        return 0
      fi
      ;;
    apt-get)
      log_info "$INSTALL_ATTEMPTED_MSG Using apt-get."
      local sudo_cmd=()
      if command -v sudo >/dev/null 2>&1; then
        sudo_cmd=(sudo)
        if sudo -n true >/dev/null 2>&1; then
          log_info "Running apt-get with sudo (non-interactive)."
        else
          log_info "sudo may prompt for a password."
        fi
      else
        log_info "sudo not available; attempting apt-get without elevation."
      fi
      if "${sudo_cmd[@]}" apt-get update && "${sudo_cmd[@]}" apt-get install -y tmux; then
        log_info "tmux installed successfully with apt-get."
        return 0
      fi
      ;;
    *)
      log_error "Package manager '$manager' is not supported by this script."
      return 1
      ;;
  esac

  log_error "tmux installation failed using $manager."
  return 1
}

ensure_tmux_installed() {
  if command -v tmux >/dev/null 2>&1; then
    local tmux_path tmux_version
    tmux_path=$(command -v tmux)
    tmux_version=$(tmux -V 2>/dev/null || echo "unknown version")
    log_info "tmux detected at ${tmux_path} (${tmux_version})."
    return 0
  fi

  log_info "tmux not detected on PATH."
  if install_tmux; then
    if command -v tmux >/dev/null 2>&1; then
      local tmux_version
      tmux_version=$(tmux -V 2>/dev/null || echo "unknown version")
      log_info "tmux available after installation (${tmux_version})."
      return 0
    fi
    log_error "tmux installation reported success but binary is still missing."
    return 1
  fi

  return 1
}

install_github_cli() {
  local manager
  if ! manager=$(detect_package_manager); then
    log_error "Unable to detect a supported package manager. Install GitHub CLI manually and re-run."
    return 1
  fi

  case "$manager" in
    brew)
      log_info "$GH_INSTALL_ATTEMPTED_MSG Using Homebrew."
      if brew list --formula gh >/dev/null 2>&1; then
        log_info "GitHub CLI already available via Homebrew."
        return 0
      fi
      if brew install gh; then
        log_info "GitHub CLI installed successfully with Homebrew."
        return 0
      fi
      ;;
    apt-get)
      log_info "$GH_INSTALL_ATTEMPTED_MSG Using apt-get."
      local sudo_cmd=()
      if command -v sudo >/dev/null 2>&1; then
        sudo_cmd=(sudo)
        if sudo -n true >/dev/null 2>&1; then
          log_info "Running apt-get with sudo (non-interactive)."
        else
          log_info "sudo may prompt for a password."
        fi
      else
        log_info "sudo not available; attempting apt-get without elevation."
      fi
      if "${sudo_cmd[@]}" apt-get update && "${sudo_cmd[@]}" apt-get install -y gh; then
        log_info "GitHub CLI installed successfully with apt-get."
        return 0
      fi
      ;;
    *)
      log_error "Package manager '$manager' is not supported by this script."
      return 1
      ;;
  esac

  log_error "GitHub CLI installation failed using $manager."
  return 1
}

ensure_github_cli_installed() {
  if command -v gh >/dev/null 2>&1; then
    local gh_path gh_version
    gh_path=$(command -v gh)
    gh_version=$(gh --version 2>/dev/null | head -n1 | awk '{print $3}' || echo "unknown version")
    log_info "GitHub CLI detected at ${gh_path} (${gh_version})."
    return 0
  fi

  log_info "GitHub CLI not detected on PATH."
  if install_github_cli; then
    if command -v gh >/dev/null 2>&1; then
      local gh_version
      gh_version=$(gh --version 2>/dev/null | head -n1 | awk '{print $3}' || echo "unknown version")
      log_info "GitHub CLI available after installation (${gh_version})."
      return 0
    fi
    log_error "GitHub CLI installation reported success but binary is still missing."
    return 1
  fi

  return 1
}

clear_screen() {
  if command -v tput >/dev/null 2>&1; then
    tput clear || printf "\033[2J\033[H"
  else
    printf "\033[2J\033[H"
  fi
}

draw_menu() {
  local selected=$1
  shift
  local options=("$@")

  clear_screen
  printf "%s\n%s\n%s\n\n" "$BANNER_LINE" "$BANNER_TITLE" "$BANNER_LINE"
  printf "%s\n" "$MENU_DESCRIPTION"
  printf "Press 'q' at any time to exit. Vim keys (j/k) also work.\n\n"

  for idx in "${!options[@]}"; do
    if [[ $idx -eq $selected ]]; then
      printf "> %s\n" "${options[$idx]}"
    else
      printf "  %s\n" "${options[$idx]}"
    fi
  done
  printf "\n%s\n" "$BANNER_LINE"
}

# Presents an arrow-key driven menu and stores the user's choice in MENU_SELECTION.
interactive_menu() {
  local options=("$@")
  local selected=0
  local key

  while true; do
    draw_menu "$selected" "${options[@]}"

    if ! read -rsn1 key; then
      continue
    fi

    case $key in
      $'\x1b')
        # Expecting an escape sequence such as ESC [ A / ESC [ B for arrow keys.
        if ! read -rsn1 -t "$MENU_ARROW_TIMEOUT" key || [[ $key != "[" ]]; then
          continue
        fi
        if ! read -rsn1 -t "$MENU_ARROW_TIMEOUT" key; then
          continue
        fi
        case $key in
          A)
            selected=$(( (selected - 1 + ${#options[@]}) % ${#options[@]} ))
            ;;
          B)
            selected=$(( (selected + 1) % ${#options[@]} ))
            ;;
        esac
        ;;
      k|K)
        selected=$(( (selected - 1 + ${#options[@]}) % ${#options[@]} ))
        ;;
      j|J)
        selected=$(( (selected + 1) % ${#options[@]} ))
        ;;
      "")
        MENU_SELECTION="${options[$selected]}"
        clear_screen
        return 0
        ;;
      q|Q)
        MENU_SELECTION="Exit"
        clear_screen
        return 0
        ;;
    esac
  done
}

handle_profile_setup() {
  local profile=${1:-$DEFAULT_PROFILE}
  local os_name
  os_name=$(detect_os)

  log_info "Profile '${profile}' selected."
  log_info "Operating system detected: ${os_name}."

  if [[ $os_name == "unknown" ]]; then
    log_error "Unsupported operating system. Aborting setup."
    return 1
  fi

  if ensure_github_cli_installed; then
    log_info "GitHub CLI is ready to use."
  else
    log_error "GitHub CLI setup did not complete successfully."
    return 1
  fi

  if ensure_tmux_installed; then
    log_info "tmux is ready to use."
  else
    log_error "tmux setup did not complete successfully."
    return 1
  fi

  if apply_tmux_config "$profile"; then
    log_info "tmux configuration applied successfully."
  else
    log_error "Failed to apply tmux configuration."
    return 1
  fi

  if apply_shell_config "$profile"; then
    log_info "zsh configuration applied successfully."
  else
    log_error "Failed to apply zsh configuration."
    return 1
  fi

  if validate_zsh_config; then
    log_info "zsh configuration validation succeeded."
  else
    log_error "zsh configuration validation failed."
    return 1
  fi

  if install_tmux_menu_helper; then
    log_info "tmux menu helper installed successfully."
  else
    log_error "Failed to install tmux menu helper."
    return 1
  fi
  local tmux_cmd="tmux source-file ${TMUX_CONFIG_TARGET_PATH/#\~/$HOME}"
  if [[ $AUTO_RELOAD_TMUX == true ]]; then
    if reload_tmux_config; then
      log_info "tmux configuration reload attempted automatically (active servers updated)."
    else
      log_error "Automatic tmux reload reported an error."
    fi
    log_info "Manual command (if needed): ${tmux_cmd}"
  else
    log_info "tmux reload skipped. Run this command later: ${tmux_cmd}"
  fi

  local zsh_cmd="source ${SHELL_CONFIG_TARGET_PATH/#\~/$HOME}"
  if [[ $AUTO_SOURCE_ZSH == true ]]; then
    if source_zsh_config_now; then
      log_info "zsh configuration sourced via non-interactive zsh. Run '${zsh_cmd}' in your active terminal to apply aliases."
    else
      log_error "Automatic zsh sourcing reported an error."
      log_info "Manual command (from your shell): ${zsh_cmd}"
    fi
  else
    log_info "zsh sourcing skipped. Run this later in your shell: ${zsh_cmd}"
  fi
}

parse_args() {
  if [[ $# -eq 0 ]]; then
    return 0
  fi

  case $1 in
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      print_usage >&2
      exit 1
      ;;
  esac
}

main() {
  parse_args "$@"

  MENU_DESCRIPTION="$PROFILE_MENU_DESCRIPTION"
  interactive_menu "${MENU_OPTIONS[@]}"
  local profile_choice=$MENU_SELECTION

  printf "%s\n%s\n%s\n" "$BANNER_LINE" "$BANNER_TITLE" "$BANNER_LINE"
  log_info "Selected profile: ${profile_choice:-<none>}"

  if [[ $profile_choice == "Exit" ]]; then
    log_info "Goodbye!"
    printf "\n%s\n" "$BANNER_LINE"
    return 0
  fi

  if ! choose_reload_strategy; then
    printf "\n%s\n" "$BANNER_LINE"
    return 0
  fi

  case $profile_choice in
    Default)
      handle_profile_setup "$DEFAULT_PROFILE"
      ;;
    Developer)
      handle_profile_setup "$DEVELOPER_PROFILE"
      ;;
    *)
      log_error "No valid profile selection detected."
      printf "\n%s\n" "$BANNER_LINE"
      exit 1
      ;;
  esac

  printf "\n%s\n" "$BANNER_LINE"
}

main "$@"
