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
