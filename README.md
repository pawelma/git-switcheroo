# git-switcheroo 🔀

**`git co my-branch` that actually lands on `my-branch` — even when it's checked out in another worktree.**

Running several AI agents (or just several tasks) in parallel `git worktree`s? Then you've seen this:

| Before | After |
|---|---|
| ![before: checkout fails, you test the wrong code](demo/before.gif) | ![after: your shell hops into the right worktree](demo/after.gif) |

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/pawelma/git-switcheroo/main/install.sh | sh
```

Open a new shell. That's it. Works in **fish**, **zsh** and **bash** (macOS & Linux).

The installer asks which of your commands it may take over — it finds your existing aliases for `checkout`/`switch` (like `co`, `sw`) and pre-selects them. Plain `git checkout` / `git switch` are offered too, but are never taken over unless you pick them. `git sr` is always added.

Run the same line again to update. Remove with:

```sh
curl -fsSL https://raw.githubusercontent.com/pawelma/git-switcheroo/main/install.sh | sh -s -- --uninstall
```

## Why

- **No more testing the wrong revision.** Every switch ends with one loud line: `✓ on feature-x` or `✗ … still on main`.
- **Branches live where they live.** If another worktree has the branch, your shell jumps there — same subdirectory, no copy-pasting paths.
- **Zero new habits.** Keep typing `git co`. Everything that isn't a plain branch switch (`-b`, files, SHAs, tags) is passed to git untouched.

## What happens when you `git co feature-x`

| Situation | Result |
|---|---|
| `feature-x` is checked out in another worktree | ↪ your shell `cd`s into that worktree (same subdirectory if it exists there) |
| You're already on it | ✓ already on feature-x |
| It's free | normal checkout, then verified: ✓ on feature-x (abc1234 Add login) |
| Checkout fails (dirty tree, conflicts…) | git's error, then ✗ checkout failed — still on main |
| Its worktree folder was deleted | ⚠ stale entry removed, then normal checkout |
| Its worktree folder was deleted but the worktree is locked | ✗ … git worktree unlock … first — nothing touched |
| `git co -` | resolves your previous branch, then all of the above |
| `git co -b new`, `git co -- file`, `git co v1.2.0` … | plain git, untouched |

## Scenarios

**Reviewing what an agent built.** Agent A works in `../shop-agent-login` on `feature-login`. From your main checkout, `git co feature-login` drops you into `../shop-agent-login` — you're looking at the agent's actual files, not a stale copy.

**Going back.** From inside an agent worktree, `git co main` hops you back to the main checkout.

**Deep in a subdirectory.** In `app/models`? You land in `app/models` of the other worktree.

**Agent cleaned up its folder.** `rm -rf`'d worktrees leave stale entries that make git refuse the branch forever. switcheroo removes just that entry (never `git worktree prune`, which would touch other agents' worktrees) and checks out.

**Scripts and AI agents.** The wrapper only exists in *interactive* shells, so agents and scripts calling `git co` get plain git. If something runs `git sr` without the wrapper, it can't move the shell — so it stops with `✗ feature-x is checked out at … — cd there` and exit code 2 instead of pretending.

## How it works

A program can't change its parent shell's directory, so switcheroo has two parts:

1. `git-switcheroo` — a small POSIX `sh` script that decides what to do and, for a hop, writes the target directory to a temp file.
2. A tiny `git` function for your shell (fish, or bash/zsh) that hands selected commands to it and `cd`s to whatever it wrote. Everything else goes straight to `command git`.

Installed files:

```
~/.local/bin/git-switcheroo
~/.config/fish/conf.d/git-switcheroo.fish
~/.config/git-switcheroo/git-switcheroo.sh   (sourced from ~/.bashrc / ~/.zshrc)
~/.config/git-switcheroo/config              (commands you picked)
git config --global alias.sr '!git-switcheroo sr'
```

`XDG_BIN_HOME`, `XDG_CONFIG_HOME` and `ZDOTDIR` are respected. On macOS, bash login shells read `~/.bash_profile` — make sure it sources `~/.bashrc`.

## FAQ

**Will it break my existing `co` alias?** No. Your aliases are never modified; the shell function intercepts `git co` before git sees it. In shells without the function, your alias works as before.

**Why `sr` and not `sw`?** `sr` (switcheroo) doesn't clash with common aliases. It behaves like `git switch` for anything that isn't a plain branch name.

**Non-interactive install?** `SWITCHEROO_COMMANDS="co sw" sh install.sh` skips the prompt. `SWITCHEROO_REF=<tag>` pins a version.

**Colors?** Only on a terminal; `NO_COLOR=1` turns them off.

## A short history

It started with a few AI agents, each in its own worktree of the same repo. Switching to review their work, `git checkout feature-x` would print `fatal: 'feature-x' is already used by worktree at …` — a line that's easy to scroll past when you're busy. The next step was manual testing… of `main`. Time lost, tokens burned explaining "bugs" that weren't there. git-switcheroo makes that failure impossible to miss, and in the common case makes it not a failure at all.

## Development

```sh
brew install bats-core shellcheck fish vhs   # or your package manager
bats test/                                   # full suite
vhs demo/before.tape && vhs demo/after.tape  # re-render the GIFs
```

CI runs the suite on Linux and macOS on every push.

## License

MIT
