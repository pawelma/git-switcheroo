load test_helper

setup() {
  setup_sandbox
  make_repo
  CD_FILE="$TEST_ROOT/cd-target"
  : >"$CD_FILE"
}

land() {
  run env SWITCHEROO_CD_FILE="$CD_FILE" git-switcheroo land "$@"
}

commit_ignore() {
  printf '%s\n' "$@" >"$REPO/.gitignore"
  git -C "$REPO" add .gitignore
  git -C "$REPO" commit -qm "Ignore $*"
}

assert_landed() {
  [ "$(git -C "$REPO" symbolic-ref --short HEAD)" = "feature" ]
  [ ! -d "$WT" ]
  [ "$(git -C "$REPO" worktree list | wc -l)" -eq 1 ]
}

@test "lands the current branch from inside its worktree" {
  add_worktree feature
  git -C "$WT" commit -q --allow-empty -m "Agent work"
  cd "$WT"
  land
  [ "$status" -eq 0 ]
  assert_landed
  [ "$(cat "$CD_FILE")" = "$REPO" ]
  assert_output_contains "✓ landed feature in $REPO"
  assert_output_contains "Agent work"
  assert_output_contains "removed worktree $WT"
}

@test "lands a named branch from the main checkout" {
  add_worktree feature
  land feature
  [ "$status" -eq 0 ]
  assert_landed
  [ "$(cat "$CD_FILE")" = "$REPO" ]
}

@test "carries staged, unstaged and untracked changes" {
  add_worktree feature
  echo "staged" >"$WT/app/models/user.rb"
  git -C "$WT" add app/models/user.rb
  echo "unstaged" >"$WT/app/models/user.rb"
  echo "todo" >"$WT/notes.txt"
  cd "$WT"
  land
  [ "$status" -eq 0 ]
  assert_landed
  [ "$(git -C "$REPO" diff --cached --name-only)" = "app/models/user.rb" ]
  [ "$(git -C "$REPO" diff --name-only)" = "app/models/user.rb" ]
  [ "$(git -C "$REPO" show :app/models/user.rb)" = "staged" ]
  [ "$(cat "$REPO/app/models/user.rb")" = "unstaged" ]
  [ "$(git -C "$REPO" ls-files --others --exclude-standard)" = "notes.txt" ]
  assert_output_contains "carried uncommitted changes from $WT"
  [ -z "$(git -C "$REPO" stash list)" ]
}

@test "a clean worktree lands without touching the stash" {
  add_worktree feature
  land feature
  [ "$status" -eq 0 ]
  [ -z "$(git stash list)" ]
  refute_output_contains "carried"
}

@test "keeps the subdirectory" {
  add_worktree feature
  cd "$WT/app/models"
  land
  [ "$status" -eq 0 ]
  [ "$(cat "$CD_FILE")" = "$REPO/app/models" ]
}

@test "ignored files do not block removal" {
  commit_ignore node_modules
  add_worktree feature
  mkdir "$WT/node_modules"
  touch "$WT/node_modules/x"
  land feature
  [ "$status" -eq 0 ]
  assert_landed
}

@test "refuses when the main checkout has modifications" {
  add_worktree feature
  echo "local edit" >"$REPO/app/models/user.rb"
  land feature
  [ "$status" -eq 1 ]
  assert_output_contains "✗ $REPO has uncommitted changes — clean it up first, then git land feature"
  assert_output_contains "app/models/user.rb"
  [ "$(git -C "$WT" symbolic-ref --short HEAD)" = "feature" ]
  [ "$(git -C "$REPO" symbolic-ref --short HEAD)" = "main" ]
}

@test "refuses when the main checkout has untracked files" {
  add_worktree feature
  touch "$REPO/scratch.txt"
  land feature
  [ "$status" -eq 1 ]
  assert_output_contains "has uncommitted changes"
  assert_output_contains "scratch.txt"
  [ "$(git -C "$WT" symbolic-ref --short HEAD)" = "feature" ]
}

@test "the main checkout's other branch is left alone" {
  add_worktree feature
  git -C "$REPO" switch -q -c other
  git -C "$REPO" commit -q --allow-empty -m "Other work"
  other_sha=$(git rev-parse other)
  land feature
  [ "$status" -eq 0 ]
  assert_landed
  [ "$(git rev-parse other)" = "$other_sha" ]
}

@test "says so when the main checkout is already on the branch" {
  land main
  [ "$status" -eq 0 ]
  assert_output_contains "✓ already on main"
}

@test "already on the branch from a worktree hops to the main checkout" {
  add_worktree feature
  cd "$WT"
  land main
  [ "$status" -eq 0 ]
  assert_output_contains "✓ already on main"
  [ "$(cat "$CD_FILE")" = "$REPO" ]
  [ -d "$WT" ]
}

@test "nothing to land from the main checkout" {
  land
  [ "$status" -eq 1 ]
  assert_output_contains "✗ nothing to land here — run git land <branch>"
}

@test "a detached worktree needs a branch name" {
  add_worktree feature
  git -C "$WT" checkout -q --detach
  cd "$WT"
  land
  [ "$status" -eq 1 ]
  assert_output_contains "✗ HEAD is detached — run git land <branch>"
}

@test "a branch in no worktree is just checked out" {
  git branch free
  add_worktree feature
  cd "$WT"
  land free
  [ "$status" -eq 0 ]
  [ "$(git -C "$REPO" symbolic-ref --short HEAD)" = "free" ]
  [ "$(cat "$CD_FILE")" = "$REPO" ]
  [ -d "$WT" ]
}

@test "a missing branch fails with git's error" {
  land nope
  [ "$status" -ne 0 ]
  assert_output_contains "invalid reference"
}

@test "a stale worktree entry is cleaned up" {
  add_worktree feature
  rm -rf "$WT"
  land feature
  [ "$status" -eq 0 ]
  [ "$(git -C "$REPO" symbolic-ref --short HEAD)" = "feature" ]
  assert_output_contains "is gone"
}

@test "a locked worktree is refused" {
  add_worktree feature
  git worktree lock --reason "agent busy" "$WT"
  land feature
  [ "$status" -eq 1 ]
  assert_output_contains "✗ feature held by locked worktree $WT (agent busy) — git worktree unlock $WT first"
  [ "$(git -C "$WT" symbolic-ref --short HEAD)" = "feature" ]
}

@test "refuses in a bare-repository setup" {
  git clone -q --bare "$REPO" "$TEST_ROOT/bare.git"
  git -C "$TEST_ROOT/bare.git" worktree add -q "$TEST_ROOT/bare-wt" main
  cd "$TEST_ROOT/bare-wt"
  land
  [ "$status" -eq 1 ]
  assert_output_contains "✗ no main checkout to land in (bare repository)"
}

@test "without the wrapper it lands and says where to cd" {
  add_worktree feature
  run git-switcheroo land feature
  [ "$status" -eq 0 ]
  assert_landed
  assert_output_contains "⚠ no shell wrapper to hop — cd $REPO"
}

@test "an alias for land dispatches to land" {
  git config --global alias.la '!git-switcheroo land'
  add_worktree feature
  run env SWITCHEROO_CD_FILE="$CD_FILE" git-switcheroo la feature
  [ "$status" -eq 0 ]
  assert_landed
}

@test "git land through the alias works from a worktree subdirectory" {
  git config --global alias.land '!git-switcheroo land'
  add_worktree feature
  cd "$WT/app"
  run env SWITCHEROO_CD_FILE="$CD_FILE" git land
  [ "$status" -eq 0 ]
  assert_landed
  [ "$(cat "$CD_FILE")" = "$REPO/app" ]
}
