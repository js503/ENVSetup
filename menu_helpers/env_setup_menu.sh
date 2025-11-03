#!/usr/bin/env bash

# env_setup_menu.sh - shared menu utilities for env_setup.sh.

set -euo pipefail
IFS=$'\n\t'

readonly ENVSETUP_MENU_ARROW_TIMEOUT=1
readonly ENVSETUP_MENU_PRIMARY_BANNER="============================================================="
readonly ENVSETUP_MENU_SECONDARY_BANNER="============================================================="

envsetup_menu_log_info() {
  printf "[INFO] %s\n" "$*"
}

envsetup_menu_log_error() {
  printf "[ERROR] %s\n" "$*" >&2
}

envsetup_menu_clear_screen() {
  if command -v tput >/dev/null 2>&1; then
    tput clear || printf "\033[2J\033[H"
  else
    printf "\033[2J\033[H"
  fi
}

envsetup_menu_draw() {
  local title=$1
  local description=$2
  local selected=$3
  shift 3
  local options=("$@")

  envsetup_menu_clear_screen
  printf "%s\n%s\n%s\n\n" "$ENVSETUP_MENU_PRIMARY_BANNER" "$title" "$ENVSETUP_MENU_SECONDARY_BANNER"
  printf "%s\n" "$description"
  printf "Press 'q' at any time to exit. Vim keys (j/k) also work.\n\n"

  for idx in "${!options[@]}"; do
    if [[ $idx -eq $selected ]]; then
      printf "> %s\n" "${options[$idx]}"
    else
      printf "  %s\n" "${options[$idx]}"
    fi
  done
  printf "\n%s\n" "$ENVSETUP_MENU_SECONDARY_BANNER"
}

envsetup_menu_interactive_select() {
  local title=$1
  local description=$2
  shift 2
  local options=("$@")
  local selected=0
  local key

  while true; do
    envsetup_menu_draw "$title" "$description" "$selected" "${options[@]}"

    if ! read -rsn1 key; then
      continue
    fi

    case $key in
      $'\x1b')
        if ! read -rsn1 -t "$ENVSETUP_MENU_ARROW_TIMEOUT" key || [[ $key != "[" ]]; then
          continue
        fi
        if ! read -rsn1 -t "$ENVSETUP_MENU_ARROW_TIMEOUT" key; then
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
        ENVSETUP_MENU_SELECTION="${options[$selected]}"
        envsetup_menu_clear_screen
        return 0
        ;;
      q|Q)
        ENVSETUP_MENU_SELECTION="Exit"
        envsetup_menu_clear_screen
        return 0
        ;;
    esac
  done
}

envsetup_menu_select_profile() {
  local title=$1
  local description=$2
  shift 2
  local options=("$@")

  ENVSETUP_MENU_SELECTION=""
  envsetup_menu_interactive_select "$title" "$description" "${options[@]}"
  ENVSETUP_SELECTED_PROFILE="${ENVSETUP_MENU_SELECTION:-}"
}

envsetup_menu_select_backup() {
  local title=$1
  local description=$2
  shift 2
  local options=("$@")

  ENVSETUP_MENU_SELECTION=""
  envsetup_menu_interactive_select "$title" "$description" "${options[@]}"
  ENVSETUP_SELECTED_BACKUP="${ENVSETUP_MENU_SELECTION:-}"
}

envsetup_menu_choose_reload() {
  local description=$1
  local options=("Reload tmux & zsh after setup" "Skip reload; show manual commands" "Cancel setup")

  ENVSETUP_MENU_SELECTION=""
  envsetup_menu_interactive_select "Environment Setup" "$description" "${options[@]}"
  case "${ENVSETUP_MENU_SELECTION:-}" in
    "Reload tmux & zsh after setup")
      ENVSETUP_RELOAD_MODE="auto"
      ;;
    "Skip reload; show manual commands")
      ENVSETUP_RELOAD_MODE="manual"
      ;;
    "Cancel setup"|"Exit")
      ENVSETUP_RELOAD_MODE="cancel"
      ;;
    *)
      ENVSETUP_RELOAD_MODE="unknown"
      ;;
  esac
}
