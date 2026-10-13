load test_helper

setup() {
  setup_sandbox
  BIN="$HOME/.local/bin"
  CONFIG="$XDG_CONFIG_HOME/git-switcheroo"
  touch "$HOME/.zshrc"
}

install_with() {
  run env SWITCHEROO_COMMANDS="$1" sh "$SWITCHEROO_ROOT/install.sh"
}

answer() {
  printf '%s\n' "$1" >"$TEST_ROOT/answers"
  run env SWITCHEROO_TTY="$TEST_ROOT/answers" sh "$SWITCHEROO_ROOT/install.sh"
}

source_line_count() {
  grep -c "git-switcheroo.sh" "$1" || true
}

@test "installs the core, wrappers, config and sr alias" {
  install_with "co"
  [ "$status" -eq 0 ]
  [ -x "$BIN/git-switcheroo" ]
  [ -f "$CONFIG/git-switcheroo.sh" ]
  [ "$(cat "$CONFIG/config")" = 'commands="co"' ]
  [ "$(git config --global alias.sr)" = '!git-switcheroo sr' ]
  [ "$(git config --global alias.co)" = "checkout" ]
  assert_output_contains "✓ git-switcheroo installed"
}

@test "adds the source line only to rc files that exist, once" {
  install_with "co"
  install_with "co"
  [ "$(source_line_count "$HOME/.zshrc")" -eq 1 ]
  [ ! -e "$HOME/.bashrc" ]
}

@test "honours ZDOTDIR for zsh" {
  mkdir -p "$TEST_ROOT/zdot"
  touch "$TEST_ROOT/zdot/.zshrc"
  run env ZDOTDIR="$TEST_ROOT/zdot" SWITCHEROO_COMMANDS=co sh "$SWITCHEROO_ROOT/install.sh"
  [ "$(source_line_count "$TEST_ROOT/zdot/.zshrc")" -eq 1 ]
}

@test "installs the fish wrapper when fish config exists" {
  mkdir -p "$XDG_CONFIG_HOME/fish"
  install_with "co"
  [ -f "$XDG_CONFIG_HOME/fish/conf.d/git-switcheroo.fish" ]
}

@test "the prompt lists bare checkout/switch aliases plus opt-in commands" {
  git config --global alias.cob "checkout -b"
  answer "1 4"
  [ "$status" -eq 0 ]
  assert_output_contains "1) [x] co — alias for checkout"
  assert_output_contains "2) [x] sw — alias for switch"
  assert_output_contains "3) [ ] checkout"
  assert_output_contains "4) [ ] switch"
  refute_output_contains "cob"
  [ "$(cat "$CONFIG/config")" = 'commands="co switch"' ]
}

@test "an empty answer keeps the pre-selected aliases" {
  answer ""
  [ "$(cat "$CONFIG/config")" = 'commands="co sw"' ]
}

@test "0 selects nothing but sr" {
  answer "0"
  [ "$(cat "$CONFIG/config")" = 'commands=""' ]
}

@test "reinstall pre-selects the previous choice" {
  install_with "checkout"
  answer ""
  assert_output_contains "3) [x] checkout"
  assert_output_contains "1) [ ] co"
  [ "$(cat "$CONFIG/config")" = 'commands="checkout"' ]
}

@test "warns when the bin dir is not on PATH" {
  install_with "co"
  assert_output_contains "⚠ $BIN is not on your PATH"
}

@test "curl | sh mode downloads every file from GitHub raw" {
  mkdir -p "$TEST_ROOT/fakebin"
  cat >"$TEST_ROOT/fakebin/curl" <<FAKE
#!/bin/sh
url="" out=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    -o) out=\$2; shift 2 ;;
    -*) shift ;;
    *) url=\$1; shift ;;
  esac
done
echo "\$url" >>"$TEST_ROOT/curl.log"
cp "$SWITCHEROO_ROOT/\${url#https://raw.githubusercontent.com/pawelma/git-switcheroo/v9/}" "\$out"
FAKE
  chmod +x "$TEST_ROOT/fakebin/curl"
  mkdir -p "$XDG_CONFIG_HOME/fish"
  run env PATH="$TEST_ROOT/fakebin:$PATH" SWITCHEROO_REF=v9 SWITCHEROO_COMMANDS=co sh -c "sh <'$SWITCHEROO_ROOT/install.sh'"
  [ "$status" -eq 0 ]
  grep -qx "https://raw.githubusercontent.com/pawelma/git-switcheroo/v9/bin/git-switcheroo" "$TEST_ROOT/curl.log"
  grep -qx "https://raw.githubusercontent.com/pawelma/git-switcheroo/v9/shell/git-switcheroo.sh" "$TEST_ROOT/curl.log"
  grep -qx "https://raw.githubusercontent.com/pawelma/git-switcheroo/v9/shell/git-switcheroo.fish" "$TEST_ROOT/curl.log"
  cmp "$BIN/git-switcheroo" "$SWITCHEROO_ROOT/bin/git-switcheroo"
}

@test "uninstall removes everything it added and leaves other aliases" {
  mkdir -p "$XDG_CONFIG_HOME/fish"
  install_with "co"
  run sh "$SWITCHEROO_ROOT/install.sh" --uninstall
  [ "$status" -eq 0 ]
  [ ! -e "$BIN/git-switcheroo" ]
  [ ! -e "$CONFIG" ]
  [ ! -e "$XDG_CONFIG_HOME/fish/conf.d/git-switcheroo.fish" ]
  [ "$(source_line_count "$HOME/.zshrc")" -eq 0 ]
  run git config --global alias.sr
  [ "$status" -ne 0 ]
  [ "$(git config --global alias.co)" = "checkout" ]
}

@test "rejects unknown arguments" {
  run sh "$SWITCHEROO_ROOT/install.sh" --bogus
  [ "$status" -eq 64 ]
}

@test "running from inside a clone uses local files, not the network" {
  mkdir -p "$TEST_ROOT/fakebin"
  printf '#!/bin/sh\nexit 56\n' >"$TEST_ROOT/fakebin/curl"
  chmod +x "$TEST_ROOT/fakebin/curl"
  cd "$SWITCHEROO_ROOT"
  run env PATH="$TEST_ROOT/fakebin:$PATH" SWITCHEROO_COMMANDS=co sh install.sh
  [ "$status" -eq 0 ]
  cmp "$BIN/git-switcheroo" "$SWITCHEROO_ROOT/bin/git-switcheroo"
}

@test "warns when no shell will load the wrapper" {
  rm "$HOME/.zshrc"
  mkdir -p "$TEST_ROOT/tools"
  for tool in git sh sed grep tr mkdir cp chmod mv dirname cat rm rmdir; do
    ln -s "$(command -v "$tool")" "$TEST_ROOT/tools/$tool"
  done
  run env PATH="$TEST_ROOT/tools" SWITCHEROO_COMMANDS=co "$TEST_ROOT/tools/sh" "$SWITCHEROO_ROOT/install.sh"
  [ "$status" -eq 0 ]
  assert_output_contains "⚠ no shell config found to load git-switcheroo"
  assert_output_contains ". \"$CONFIG/git-switcheroo.sh\""
}

@test "keeps an existing sr alias that is not ours" {
  git config --global alias.sr "status -sb"
  install_with "co"
  [ "$status" -eq 0 ]
  [ "$(git config --global alias.sr)" = "status -sb" ]
  assert_output_contains "⚠ alias.sr is already set"
}
