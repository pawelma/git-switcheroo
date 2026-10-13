load test_helper

setup() {
  setup_sandbox
  make_repo
  add_worktree feature
  mkdir -p "$XDG_CONFIG_HOME/git-switcheroo"
  echo 'commands="co"' >"$XDG_CONFIG_HOME/git-switcheroo/config"
}

in_bash() {
  run bash --norc -ic "source '$SWITCHEROO_ROOT/shell/git-switcheroo.sh'; $1"
}

in_zsh() {
  command -v zsh >/dev/null || skip "zsh not installed"
  run zsh -fic "source '$SWITCHEROO_ROOT/shell/git-switcheroo.sh'; $1"
}

@test "bash: git co hops the shell into the worktree subdirectory" {
  in_bash "cd '$REPO/app'; git co feature; echo \"PWD=\$PWD\""
  [ "$status" -eq 0 ]
  assert_output_contains "PWD=$WT/app"
}

@test "zsh: git co hops the shell into the worktree" {
  in_zsh "cd '$REPO'; git co feature; echo \"PWD=\$PWD\""
  [ "$status" -eq 0 ]
  assert_output_contains "PWD=$WT"
}

@test "bash: git sr works even with no config file" {
  rm "$XDG_CONFIG_HOME/git-switcheroo/config"
  in_bash "cd '$REPO'; git sr feature; echo \"PWD=\$PWD\""
  assert_output_contains "PWD=$WT"
}

@test "bash: commands not selected at install stay plain git" {
  in_bash "cd '$REPO'; git sw feature; echo \"PWD=\$PWD\""
  assert_output_contains "already used by worktree"
  assert_output_contains "PWD=$REPO"
}

@test "bash: the core's exit code comes back through the wrapper" {
  git worktree lock "$WT"
  rm -rf "$WT"
  in_bash "cd '$REPO'; git co feature; echo \"RC=\$?\""
  assert_output_contains "RC=1"
  assert_output_contains "✗ feature held by locked worktree"
}

@test "bash: other git commands pass through" {
  in_bash "cd '$REPO'; git rev-parse --abbrev-ref HEAD"
  assert_output_contains "main"
}

@test "bash: non-interactive shells get no git function" {
  run bash --norc -c "source '$SWITCHEROO_ROOT/shell/git-switcheroo.sh'; type -t git"
  [ "$output" = "file" ]
}

@test "bash: falls back to plain git when git-switcheroo is not on PATH" {
  in_bash "PATH=\$(dirname \"\$(command -v git)\"):/usr/bin:/bin; cd '$REPO'; git co feature; echo \"PWD=\$PWD\""
  assert_output_contains "already used by worktree"
  refute_output_contains "command not found"
}
