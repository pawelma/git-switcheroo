SWITCHEROO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup_sandbox() {
  TEST_ROOT="$(cd "$BATS_TEST_TMPDIR" && pwd -P)"
  export HOME="$TEST_ROOT/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  export GIT_CONFIG_NOSYSTEM=1
  unset XDG_BIN_HOME GIT_PREFIX SWITCHEROO_CD_FILE SWITCHEROO_COMMANDS SWITCHEROO_TTY ZDOTDIR NO_COLOR
  mkdir -p "$HOME"
  git config --global user.name "Test"
  git config --global user.email "test@example.com"
  git config --global init.defaultBranch main
  git config --global advice.detachedHead false
  git config --global alias.co checkout
  git config --global alias.sw switch
  export PATH="$SWITCHEROO_ROOT/bin:$PATH"
}

make_repo() {
  REPO="$TEST_ROOT/repo"
  git init -q "$REPO"
  mkdir -p "$REPO/app/models"
  echo "class User; end" >"$REPO/app/models/user.rb"
  git -C "$REPO" add .
  git -C "$REPO" commit -qm "Initial commit"
  cd "$REPO"
}

add_worktree() {
  local branch=$1
  WT=${2:-$TEST_ROOT/wt-${branch//\//-}}
  if git -C "$REPO" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$REPO" worktree add -q "$WT" "$branch"
  else
    git -C "$REPO" worktree add -q -b "$branch" "$WT"
  fi
}
