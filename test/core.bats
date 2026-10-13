load test_helper

setup() {
  setup_sandbox
  make_repo
}

@test "prints usage without arguments" {
  run git-switcheroo
  [ "$status" -eq 64 ]
  assert_output_contains "usage: git-switcheroo"
}

@test "unknown command passes straight to git" {
  run git-switcheroo status
  [ "$status" -eq 0 ]
  assert_output_contains "On branch main"
}

@test "flags pass through to the underlying command" {
  run git-switcheroo co -b brand-new
  [ "$status" -eq 0 ]
  [ "$(git symbolic-ref --short HEAD)" = "brand-new" ]
  refute_output_contains "✓"
}

@test "a file path passes through to checkout" {
  echo "dirty" >app/models/user.rb
  run git-switcheroo co app/models/user.rb
  [ "$status" -eq 0 ]
  [ "$(cat app/models/user.rb)" = "class User; end" ]
}

@test "sr uses switch, which refuses file paths" {
  echo "dirty" >app/models/user.rb
  run git-switcheroo sr app/models/user.rb
  [ "$status" -ne 0 ]
  assert_output_contains "invalid reference"
  [ "$(cat app/models/user.rb)" = "dirty" ]
}

@test "outside a repository passes through to git" {
  cd "$TEST_ROOT"
  run git-switcheroo co main
  [ "$status" -ne 0 ]
  assert_output_contains "not a git repository"
  refute_output_contains "✗"
}

@test "an alias that is not checkout or switch passes through as itself" {
  git config --global alias.st status
  run git-switcheroo st
  [ "$status" -eq 0 ]
  assert_output_contains "On branch main"
}

@test "checks out a free branch in place and confirms it" {
  git branch feature
  run git-switcheroo co feature
  [ "$status" -eq 0 ]
  [ "$(git symbolic-ref --short HEAD)" = "feature" ]
  assert_output_contains "✓ on feature ("
  assert_output_contains "Initial commit"
}

@test "says so when already on the branch" {
  run git-switcheroo co main
  [ "$status" -eq 0 ]
  assert_output_contains "✓ already on main"
}

@test "a failed checkout is loud and keeps git's exit code" {
  git checkout -q -b feature
  echo "feature version" >app/models/user.rb
  git commit -qam "Change user"
  git checkout -q main
  echo "local edit" >app/models/user.rb
  run git-switcheroo co feature
  [ "$status" -eq 1 ]
  assert_output_contains "would be overwritten"
  assert_output_contains "✗ checkout failed — still on main"
  [ "$(git symbolic-ref --short HEAD)" = "main" ]
}

@test "flags a checkout that exits 0 but leaves HEAD elsewhere" {
  git branch feature
  mkdir -p "$TEST_ROOT/stub"
  cat >"$TEST_ROOT/stub/git" <<STUB
#!/bin/sh
[ "\$1" = checkout ] && exit 0
exec "$(command -v git)" "\$@"
STUB
  chmod +x "$TEST_ROOT/stub/git"
  PATH="$TEST_ROOT/stub:$PATH" run git-switcheroo co feature
  [ "$status" -eq 1 ]
  assert_output_contains "✗ expected feature, HEAD is main"
}

@test "creates a tracking branch for a branch that only exists on one remote" {
  git branch remote-only
  git clone -q "$REPO" "$TEST_ROOT/clone"
  cd "$TEST_ROOT/clone"
  run git-switcheroo co remote-only
  [ "$status" -eq 0 ]
  [ "$(git symbolic-ref --short HEAD)" = "remote-only" ]
  assert_output_contains "✓ on remote-only"
}

@test "a branch on two remotes is left to git" {
  git branch shared
  git clone -q "$REPO" "$TEST_ROOT/clone"
  cd "$TEST_ROOT/clone"
  git remote add upstream "$REPO"
  git fetch -q upstream
  run git-switcheroo co shared
  [ "$status" -ne 0 ]
  refute_output_contains "✓"
}

cd_file() {
  CD_FILE="$TEST_ROOT/cd-target"
  : >"$CD_FILE"
}

@test "hops to the worktree that has the branch" {
  add_worktree feature
  git -C "$WT" commit -q --allow-empty -m "Agent work"
  cd_file
  run env SWITCHEROO_CD_FILE="$CD_FILE" git-switcheroo co feature
  [ "$status" -eq 0 ]
  [ "$(cat "$CD_FILE")" = "$WT" ]
  assert_output_contains "↪ feature lives in $WT — hopping"
  assert_output_contains "Agent work"
  [ "$(git symbolic-ref --short HEAD)" = "main" ]
}

@test "lands in the same subdirectory when it exists there" {
  add_worktree feature
  cd app/models
  cd_file
  run env SWITCHEROO_CD_FILE="$CD_FILE" git-switcheroo co feature
  [ "$status" -eq 0 ]
  [ "$(cat "$CD_FILE")" = "$WT/app/models" ]
}

@test "lands at the worktree root when the subdirectory is missing there" {
  add_worktree feature
  mkdir -p only-here
  cd only-here
  cd_file
  run env SWITCHEROO_CD_FILE="$CD_FILE" git-switcheroo co feature
  [ "$status" -eq 0 ]
  [ "$(cat "$CD_FILE")" = "$WT" ]
}

@test "without a cd file it refuses loudly and says where to go" {
  add_worktree feature
  run git-switcheroo co feature
  [ "$status" -eq 2 ]
  assert_output_contains "✗ feature is checked out at $WT — cd there"
}

@test "the git sr alias keeps the subdirectory via GIT_PREFIX" {
  git config --global alias.sr '!git-switcheroo sr'
  add_worktree feature
  cd app/models
  cd_file
  run env SWITCHEROO_CD_FILE="$CD_FILE" git sr feature
  [ "$status" -eq 0 ]
  [ "$(cat "$CD_FILE")" = "$WT/app/models" ]
}

@test "dash resolves to the previous branch and hops if another worktree took it" {
  git checkout -q -b feature
  git checkout -q main
  add_worktree feature
  cd_file
  run env SWITCHEROO_CD_FILE="$CD_FILE" git-switcheroo co -
  [ "$status" -eq 0 ]
  [ "$(cat "$CD_FILE")" = "$WT" ]
}

@test "dash after a detached HEAD is left to git" {
  git checkout -q --detach
  git checkout -q main
  run git-switcheroo co -
  refute_output_contains "✓"
  refute_output_contains "↪"
}

@test "hops into a worktree whose path contains spaces" {
  add_worktree feature "$TEST_ROOT/agent worktrees/feature one"
  cd_file
  run env SWITCHEROO_CD_FILE="$CD_FILE" git-switcheroo co feature
  [ "$status" -eq 0 ]
  [ "$(cat "$CD_FILE")" = "$TEST_ROOT/agent worktrees/feature one" ]
}

@test "hops for branch names with slashes" {
  add_worktree feature/login
  cd_file
  run env SWITCHEROO_CD_FILE="$CD_FILE" git-switcheroo co feature/login
  [ "$status" -eq 0 ]
  [ "$(cat "$CD_FILE")" = "$WT" ]
}

@test "from inside an agent worktree it hops back to the main checkout" {
  add_worktree feature
  cd "$WT"
  cd_file
  run env SWITCHEROO_CD_FILE="$CD_FILE" git-switcheroo co main
  [ "$status" -eq 0 ]
  [ "$(cat "$CD_FILE")" = "$REPO" ]
}
