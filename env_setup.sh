#!/usr/bin/env bash

# env_setup.sh - interactive helper for setting up a tmux environment.

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}")
readonly MENU_OPTIONS=("Setup" "Exit")

declare MENU_SELECTION=""

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
  printf "ENVSetup Menu\n"
  printf "Use arrow keys to navigate and press Enter to select.\n"
  printf "Press 'q' at any time to exit.\n\n"

  for idx in "${!options[@]}"; do
    if [[ $idx -eq $selected ]]; then
      printf "> %s\n" "${options[$idx]}"
    else
      printf "  %s\n" "${options[$idx]}"
    fi
  done
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
        if ! read -rsn1 -t 0.1 key || [[ $key != "[" ]]; then
          continue
        fi
        if ! read -rsn1 -t 0.1 key; then
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

handle_setup() {
  log_info "Setup routine selected. (Implementation pending.)"
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

  interactive_menu "${MENU_OPTIONS[@]}"
  log_info "Selected: ${MENU_SELECTION:-<none>}"

  case $MENU_SELECTION in
    Setup)
      handle_setup
      ;;
    Exit)
      log_info "Goodbye!"
      ;;
    *)
      log_error "No valid selection detected."
      exit 1
      ;;
  esac
}

main "$@"
