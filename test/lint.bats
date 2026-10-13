load test_helper

@test "shellcheck passes on POSIX scripts" {
  command -v shellcheck >/dev/null || skip "shellcheck not installed"
  run shellcheck "$SWITCHEROO_ROOT/bin/git-switcheroo" "$SWITCHEROO_ROOT/install.sh"
  [ "$status" -eq 0 ]
  run shellcheck -s bash "$SWITCHEROO_ROOT/shell/git-switcheroo.sh"
  [ "$status" -eq 0 ]
}

@test "fish wrapper parses" {
  command -v fish >/dev/null || skip "fish not installed"
  run fish --no-execute "$SWITCHEROO_ROOT/shell/git-switcheroo.fish"
  [ "$status" -eq 0 ]
}
