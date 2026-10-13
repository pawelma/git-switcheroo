case $- in
  *i*) ;;
  *) return 0 ;;
esac

if alias git >/dev/null 2>&1; then
  printf '%s\n' "git-switcheroo: 'git' is an alias in this shell, so git co won't hop — remove the alias to enable it" >&2
  return 0
fi

_switcheroo_commands="sr $(sed -n 's/^commands=//p' "${XDG_CONFIG_HOME:-$HOME/.config}/git-switcheroo/config" 2>/dev/null | tr -d '"')"

_switcheroo_handles() {
  case " $_switcheroo_commands " in
    *" $1 "*) command -v git-switcheroo >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

git() {
  if [ $# -eq 0 ] || ! _switcheroo_handles "$1"; then
    command git "$@"
    return
  fi
  local cd_file rc
  cd_file=$(mktemp "${TMPDIR:-/tmp}/git-switcheroo.XXXXXX") || return 1
  SWITCHEROO_CD_FILE=$cd_file command git-switcheroo "$@"
  rc=$?
  if [ -s "$cd_file" ]; then
    cd -- "$(cat "$cd_file")" || rc=1
  fi
  rm -f "$cd_file"
  return $rc
}
