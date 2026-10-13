#!/bin/sh
set -eu

raw_base="https://raw.githubusercontent.com/pawelma/git-switcheroo/${SWITCHEROO_REF:-main}"
bin_dir=${XDG_BIN_HOME:-$HOME/.local/bin}
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
config_dir=$config_home/git-switcheroo
config_file=$config_dir/config
fish_file=$config_home/fish/conf.d/git-switcheroo.fish
posix_wrapper=$config_dir/git-switcheroo.sh
source_line="[ -f \"$posix_wrapper\" ] && . \"$posix_wrapper\" # git-switcheroo"
bashrc=$HOME/.bashrc
zshrc=${ZDOTDIR:-$HOME}/.zshrc
tty=${SWITCHEROO_TTY:-/dev/tty}

say() { printf '%s\n' "$*" >&2; }

local_root=""
case "$0" in
  */install.sh) local_root=$(cd "$(dirname "$0")" && pwd) ;;
esac
[ -n "$local_root" ] && [ -f "$local_root/bin/git-switcheroo" ] || local_root=""

fetch() {
  if [ -n "$local_root" ]; then
    cp "$local_root/$1" "$2"
  else
    curl -fsSL "$raw_base/$1" -o "$2"
  fi
}

install_file() {
  mkdir -p "$(dirname "$2")"
  fetch "$1" "$2.tmp"
  chmod "$3" "$2.tmp"
  mv "$2.tmp" "$2"
}

checkout_aliases() {
  git config --global --get-regexp '^alias\.' 2>/dev/null | while read -r key value; do
    case "$value" in
      checkout | switch) printf '%s\n' "${key#alias.}" ;;
    esac
  done
}

previous_selection() {
  sed -n 's/^commands=//p' "$config_file" | tr -d '"'
}

describe() {
  case "$1" in
    checkout | switch) printf 'every interactive "git %s" (opt-in)' "$1" ;;
    *) printf 'alias for %s' "$(git config --global --get "alias.$1")" ;;
  esac
}

choose_commands() {
  options="$(checkout_aliases | tr '\n' ' ')checkout switch"
  if [ -f "$config_file" ]; then
    defaults=$(previous_selection)
  else
    defaults=$(checkout_aliases | tr '\n' ' ')
  fi

  if [ -n "${SWITCHEROO_COMMANDS+set}" ]; then
    printf '%s' "$SWITCHEROO_COMMANDS"
    return
  fi
  if ! (: <"$tty") 2>/dev/null; then
    printf '%s' "$defaults"
    return
  fi

  say ""
  say "Which commands should git-switcheroo take over? (git sr is always installed)"
  default_numbers=""
  i=0
  for name in $options; do
    i=$((i + 1))
    mark=" "
    case " $defaults " in
      *" $name "*)
        mark="x"
        default_numbers="$default_numbers $i"
        ;;
    esac
    say "  $i) [$mark] $name — $(describe "$name")"
  done
  printf 'Numbers separated by spaces, 0 for none [%s]: ' "${default_numbers# }" >&2
  answer=""
  read -r answer <"$tty" || true
  [ -n "$answer" ] || answer=$default_numbers

  selected=""
  for n in $answer; do
    i=0
    for name in $options; do
      i=$((i + 1))
      [ "$i" = "$n" ] && selected="$selected $name"
    done
  done
  printf '%s' "${selected# }"
}

add_source_line() {
  [ -f "$1" ] || return 0
  grep -qF "$source_line" "$1" && return 0
  printf '\n%s\n' "$source_line" >>"$1"
  say "  added source line to $1"
}

remove_source_line() {
  [ -f "$1" ] || return 0
  grep -qF "$source_line" "$1" || return 0
  grep -vF "$source_line" "$1" >"$1.switcheroo.tmp" || true
  cat "$1.switcheroo.tmp" >"$1"
  rm -f "$1.switcheroo.tmp"
  say "  removed source line from $1"
}

uninstall() {
  rm -f "$bin_dir/git-switcheroo" "$fish_file" "$posix_wrapper" "$config_file"
  rmdir "$config_dir" 2>/dev/null || true
  if [ "$(git config --global --get alias.sr 2>/dev/null)" = "!git-switcheroo sr" ]; then
    git config --global --unset alias.sr
  fi
  remove_source_line "$bashrc"
  remove_source_line "$zshrc"
  say "✓ git-switcheroo uninstalled — open a new shell"
}

install() {
  commands=$(choose_commands)

  install_file bin/git-switcheroo "$bin_dir/git-switcheroo" 755
  install_file shell/git-switcheroo.sh "$posix_wrapper" 644
  if command -v fish >/dev/null 2>&1 || [ -d "$config_home/fish" ]; then
    install_file shell/git-switcheroo.fish "$fish_file" 644
  fi
  printf 'commands="%s"\n' "$commands" >"$config_file"
  git config --global alias.sr '!git-switcheroo sr'
  add_source_line "$bashrc"
  add_source_line "$zshrc"

  say ""
  say "✓ git-switcheroo installed"
  say "  commands: sr${commands:+ $commands}"
  case ":$PATH:" in
    *":$bin_dir:"*) ;;
    *) say "⚠ $bin_dir is not on your PATH — add it (fish: fish_add_path $bin_dir)" ;;
  esac
  say "  open a new shell to start hopping"
}

case "${1:-}" in
  --uninstall) uninstall ;;
  "") install ;;
  *)
    say "usage: install.sh [--uninstall]"
    exit 64
    ;;
esac
