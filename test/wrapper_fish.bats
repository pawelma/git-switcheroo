load test_helper

setup() {
  command -v fish >/dev/null || skip "fish not installed"
  setup_sandbox
  make_repo
  add_worktree feature
  mkdir -p "$XDG_CONFIG_HOME/git-switcheroo"
  echo 'commands="co"' >"$XDG_CONFIG_HOME/git-switcheroo/config"
}

in_fish() {
  run fish --no-config -ic "source '$SWITCHEROO_ROOT/shell/git-switcheroo.fish'; $1"
}

@test "fish: git co hops the shell into the worktree subdirectory" {
  in_fish "cd '$REPO/app'; git co feature; echo PWD=\$PWD"
  [ "$status" -eq 0 ]
  assert_output_contains "PWD=$WT/app"
}

@test "fish: git sr works even with no config file" {
  rm "$XDG_CONFIG_HOME/git-switcheroo/config"
  in_fish "cd '$REPO'; git sr feature; echo PWD=\$PWD"
  assert_output_contains "PWD=$WT"
}

@test "fish: commands not selected at install stay plain git" {
  in_fish "cd '$REPO'; git sw feature; echo PWD=\$PWD"
  assert_output_contains "already used by worktree"
  assert_output_contains "PWD=$REPO"
}

@test "fish: the core's exit code comes back through the wrapper" {
  git worktree lock "$WT"
  rm -rf "$WT"
  in_fish "cd '$REPO'; git co feature; echo RC=\$status"
  assert_output_contains "RC=1"
  assert_output_contains "✗ feature held by locked worktree"
}

@test "fish: other git commands pass through" {
  in_fish "cd '$REPO'; git rev-parse --abbrev-ref HEAD"
  assert_output_contains "main"
}

@test "fish: non-interactive shells get no git function" {
  run fish --no-config -c "source '$SWITCHEROO_ROOT/shell/git-switcheroo.fish'; functions -q git; and echo function; or echo none"
  [ "$output" = "none" ]
}

@test "fish: falls back to plain git when git-switcheroo is not on PATH" {
  in_fish "set PATH (dirname (command -s git)) /usr/bin /bin; cd '$REPO'; git co feature; echo PWD=\$PWD"
  assert_output_contains "already used by worktree"
  assert_output_contains "PWD=$REPO"
}
