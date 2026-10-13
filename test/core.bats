load test_helper

setup() {
  setup_sandbox
  make_repo
}

@test "prints usage without arguments" {
  run git-switcheroo
  [ "$status" -eq 64 ]
  [[ "$output" == *"usage: git-switcheroo"* ]]
}

@test "unknown command passes straight to git" {
  run git-switcheroo status
  [ "$status" -eq 0 ]
  [[ "$output" == *"On branch main"* ]]
}

@test "flags pass through to the underlying command" {
  run git-switcheroo co -b brand-new
  [ "$status" -eq 0 ]
  [ "$(git symbolic-ref --short HEAD)" = "brand-new" ]
  [[ "$output" != *"✓"* ]]
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
  [[ "$output" == *"invalid reference"* ]]
  [ "$(cat app/models/user.rb)" = "dirty" ]
}

@test "outside a repository passes through to git" {
  cd "$TEST_ROOT"
  run git-switcheroo co main
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a git repository"* ]]
  [[ "$output" != *"✗"* ]]
}

@test "an alias that is not checkout or switch passes through as itself" {
  git config --global alias.st status
  run git-switcheroo st
  [ "$status" -eq 0 ]
  [[ "$output" == *"On branch main"* ]]
}
