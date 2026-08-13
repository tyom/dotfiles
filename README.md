<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/dotfiles-dark.svg">
    <img src="docs/dotfiles.svg" alt="dotfiles" width="300">
  </picture>
</p>

<p align="center">
  <a href="https://github.com/tyom/dotfiles/actions/workflows/smoke-test.yml"><img src="https://github.com/tyom/dotfiles/actions/workflows/smoke-test.yml/badge.svg" alt="Smoke Test"></a>
  <a href="https://github.com/tyom/dotfiles/actions/workflows/ci.yml"><img src="https://github.com/tyom/dotfiles/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
</p>

Personal dotfiles for macOS and Linux: Zsh with Oh My Zsh, Git config, Vim, a few
CLI tools like bat and fzf, and a Claude Code plugin. One command installs the
lot, then checks its own work.

How it behaves:

- Your `~/.zshrc` and `~/.gitconfig` are not overwritten. The installer adds one
  line to each and leaves the rest alone. Everything else is a symlink into this
  repo, so the file you edit here is the file your shell reads. There is nothing
  to sync.
- You choose what gets installed. Setup shows a checklist, and Homebrew packages,
  macOS apps and the Claude Code plugin start unchecked.
- You can run it again any time. Each step skips what it has already done, and
  the last step runs over 30 checks, including that every symlink still points
  into this repo. CI installs all of it on Linux, once with Homebrew and once
  without.

## What's Included

- **Shell**: Zsh and Oh My Zsh, with a prompt that shows git status, the Node
  version in use, and the active conda environment
- **Git**: short aliases (`git c`, `git co`, `git unstage`, `git who`), a global
  ignore file, and a config you include rather than replace
- **Terminal**: Ghostty set to a translucent black window, tabs in the titlebar,
  no traffic lights, and 16pt thickened text
- **Coding agents**: one set of global instructions that Claude Code and Codex
  both read, asking for plain language, opinions with a stated confidence, and no
  pushing to GitHub without being asked
- **Vim**: vim-plug plus gruvbox, airline, gitgutter and NERDTree
- **CLI tools**: bat, fzf, git-delta, [herdr](https://herdr.dev/) for running
  several coding agents in one terminal, and the rest of
  [scripts/install/brew.sh](./scripts/install/brew.sh)
- **Node**: Volta, and Node installed through it. Bun if you tick it.
- **Scripts on your PATH**: [`gl`, `gb`, `gw` and `git who`](#git-tools) for
  logs, branches, worktrees and line ownership, plus
  `color-test` and two of my tools from Homebrew:
  [`ungit`](https://github.com/tyom/ungit) reads a GitHub repo or subdirectory
  as text, and [`repo-intel`](https://github.com/tyom/repo-intel) builds a
  contributor dashboard for any git repo
- **Claude Code plugin**: `/explain-code`, `/review-code` and `/refactor-code`

## Installation

You do not need to clone anything. This gets the repo into `~/.dotfiles` and runs
setup:

```bash
curl -fsSL https://tyom.github.io/dotfiles/install.sh | bash
```

Setup shows a checklist. Toggle items by number, press <kbd>Enter</kbd> to
install, or <kbd>q</kbd> to quit. It takes a few minutes to download and set up
packages. At the end you get a summary and one line of validation results.

Without a terminal the checklist cannot be answered, so pass the choice as a
flag. With neither flag it installs the pre-ticked defaults (`dotfiles`, `node`).

```bash
# Install everything, no checklist (for CI or a fresh box)
curl -fsSL https://tyom.github.io/dotfiles/install.sh | bash -s -- -y

# Or pick the items yourself: dotfiles, agents, node, brew, casks, bun, claude-plugin
curl -fsSL https://tyom.github.io/dotfiles/install.sh | bash -s -- --select dotfiles,brew

# Somewhere other than ~/.dotfiles
curl -fsSL https://tyom.github.io/dotfiles/install.sh | DOTFILES_DIR=~/my-dotfiles bash

# From another branch
curl -fsSL https://tyom.github.io/dotfiles/install.sh | DOTFILES_BRANCH=next bash
```

### From a clone

Clone first if you plan to edit anything. The installer notices it is already
inside a repo and installs from there:

```bash
git clone https://github.com/tyom/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
make install
```

Add `VERBOSE=1` to see every validation check instead of the summary line
(`make install VERBOSE=1`, or `./scripts/setup.sh --verbose`). Docker test targets
always run verbose. `make install SELECT=dotfiles,brew` skips the checklist, the
same as `./scripts/setup.sh --select dotfiles,brew`.

### Uninstall

```bash
make uninstall
```

## Structure

```text
dotfiles/
├── home/              # Symlinked to ~/
│   ├── .vimrc
│   ├── .vimrc.bundles
│   ├── .config/       # ~/.config entries (ghostty)
│   ├── .claude/       # Claude Code instructions (imports the Codex file)
│   ├── .codex/        # Agent instructions, shared by both
│   └── bin/           # Shell scripts
├── git/               # Git config (included via ~/.gitconfig)
├── zsh/               # Zsh config + theme (sourced/symlinked)
├── shell/             # Shell modules
├── claude-plugin/     # Claude Code plugin
└── scripts/           # Installation scripts
```

To add a dotfile, put it under `home/` at the path it should have in your home
directory — `home/.newconfig` becomes `~/.newconfig` — and run `make install`.

## Customisation

The installer adds to your files, it does not replace them. Where a config
supports including or sourcing another file, this repo puts itself there and
leaves the rest of the file to you.

### `~/.gitconfig`

The installer adds an `[include]` directive to load the dotfiles config. Add your personal settings directly:

```ini
[user]
    name = Your Name
    email = your@email.com

[include]
    path = ~/.dotfiles/git/.gitconfig
```

### `~/.gitignore`

Copied once during setup, if you don't already have one. It's a copy rather than
a link, so later changes here do not reach it.

### `~/.zshrc`

The installer appends one source line. Everything else in the file stays yours.

### `~/.vimrc.local`

Read by `.vimrc` if it exists. Put settings for one machine here.

### `~/.config/ghostty/config.ghostty`

A symlink to the copy in this repo, so it makes no difference which path you
edit. Press <kbd>⌘⇧,</kbd> in Ghostty to load a change, and run
`ghostty +validate-config` to catch a typo, since Ghostty ignores option names
it doesn't recognise without saying so.

### `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`

Off by default. These steer every agent session on the machine, so tick **Global
agent instructions** in the installer menu to link them.

One file holds the rules: `~/.codex/AGENTS.md`. `~/.claude/CLAUDE.md` carries an
explanatory comment and a single line importing it, which is [the pattern Claude
Code documents][import] for a repo that already has an `AGENTS.md`. Codex reads
its file directly, Claude reads it through the import, and there is nothing to
build or keep in step.

Write shared rules in `home/.codex/AGENTS.md`. Claude-only rules go under the
import in `home/.claude/CLAUDE.md`, where Codex never sees them. Codex-only rules
have nowhere private to go — Claude reads the whole file — so they go under
`## Codex only` and name the agent in the bullet itself. Neither an import nor a
heading is enforcement, and a scope written into the rule survives being read on
its own. Run `/context` in a Claude session to confirm both files loaded.

[import]: https://code.claude.com/docs/en/memory#agents-md

## What Gets Installed

### Dev Tools

- **[Volta](https://volta.sh/)** pins the Node version per project
- **[Node.js](https://nodejs.org/)**, installed through Volta
- **[Bun](https://bun.sh/)**, if you tick it in the checklist

### Homebrew Packages (optional)

See [scripts/install/brew.sh](./scripts/install/brew.sh) for the full list.

### Shell

- Zsh with Oh-My-Zsh
- Custom theme with git status, Node version, and conda environment
- fzf integration for fuzzy finding

<details>
<summary><strong>Installation Flow</strong></summary>

```text
install.sh (entry point)
├── If run from existing repo: use that location
└── Otherwise: clone to ~/.dotfiles (or DOTFILES_DIR)
    └── Execute scripts/setup.sh

setup.sh (orchestrator)
├── 1. Show the install checklist (nothing selected = exit)
├── 2. Install Homebrew and packages (optional)
├── 3. Install Brew Cask / macOS apps (optional, macOS only)
├── 4. Install Bun (optional)
├── 5. Install Volta
├── 6. Install Node.js via Volta
├── 7. Set up Zsh and Oh My Zsh (scripts/zsh.sh)
│   ├── Install zsh if missing
│   ├── Install Oh My Zsh if missing
│   ├── Add source line to ~/.zshrc (exports DOTFILES_DIR)
│   └── Symlink custom theme
├── 8. Create symlinks (scripts/link.sh)
│   └── Symlink home/ contents to ~/
├── 9. Set up git (scripts/git.sh)
│   ├── Add [include] to ~/.gitconfig
│   └── Copy ~/.gitignore if missing
├── 10. Install Vim plugins (scripts/install/vim.sh)
│    ├── Install vim-plug
│    └── Run PlugInstall
├── 11. Install Claude Code plugin (optional)
│    ├── Install dependencies (bun or npm)
│    └── Register plugin (if claude installed)
└── 12. Validate installation (scripts/validate.sh)
```

</details>

<details>
<summary><strong>Zsh Configuration Chain</strong></summary>

```text
~/.zshrc
└── exports DOTFILES_DIR and sources $DOTFILES_DIR/zsh/dotfiles.zsh
    ├── sources zsh/config.zsh
    │   ├── sources shell/utils.sh
    │   ├── sources shell/exports.sh
    │   ├── sources shell/aliases.sh
    │   ├── sources shell/functions.sh
    │   └── configures oh-my-zsh plugins
    └── sources oh-my-zsh.sh
        └── loads theme and plugins
```

</details>

<details>
<summary><strong>Symlinked Files</strong></summary>

`link.sh` symlinks every file under `home/` to the matching path in your home
directory, creating the parent directories as it goes. The two agent files are
the exception: they are only linked when the `agents` option is selected. So
`home/.config/ghostty/config.ghostty` lands at `~/.config/ghostty/config.ghostty`,
and so on for the rest of the tree above.

An existing file at a target is never overwritten silently: an empty one is taken
over, and anything else prompts to override (keeping a `.bak`), skip or quit.
`make uninstall` removes only the links that still point into this repo.

The zsh theme is symlinked separately by `zsh.sh`:

- `zsh/tyom.zsh-theme` → `~/.oh-my-zsh/custom/themes/tyom.zsh-theme`

Git configuration is handled separately (not symlinked):

- `~/.gitconfig` - An `[include]` directive is added to load the dotfiles config
- `~/.gitignore` - Copied during setup (if it doesn't exist) so you can customise it

</details>

## Git tools

Four scripts on your PATH. `git who`, `gb` and `gw` explain themselves with
`-h`.

### `git who`

Who owns which part of the tree. Runs `git blame` over every tracked text file
at HEAD, ignoring whitespace-only changes, so the shares say who wrote the code
that is there now rather than who committed most.

- default: a tree, each directory with its top authors
- `-t, --top [n]`: the other way round, top authors first and where their lines
  sit
- `-i, --is [name]`: a page about a person instead of a table, with their
  addresses, lines, commits and how many of those were merges, the span they
  worked over with a bar of their activity month by month, and where their lines
  sit. With no name it reports the biggest contributors instead: as many as `-t`
  asks for, or ten if `-t` is absent. With `gh` installed and logged in to a
  GitHub remote it adds their profile, pull requests and reviews
- `-d, --depth n` sets the depth, `-v` writes names out in full, and a path
  roots the tree somewhere else

Counts are cached in `.git/git-who.cache`, so a second run only blames what
changed. `-c` starts the cache over.

### `gl`

Git log, one commit per line, with any refs on a continuation line underneath.
Takes the usual `git log` options.

### `gb`

Branches, most recently committed to first. The current one is a block, a tick
marks those already merged into HEAD. `-r` for remote branches, `-s` for name
and size only, largest first, where size is the disk taken by the objects a
branch holds that the default branch does not.

### `gw`

Worktrees mapped to their branches, newest first. `gw switch <branch|sha>`
changes to one, by branch name or by sha prefix, which is how a detached
worktree is reached. `gw prune` removes the worktrees whose branches are
merged, asking first and treating locked ones separately.

## Development

Install into a container instead of your machine:

```bash
# Run setup and validation
make docker-test

# Interactive shell (persistent state)
make docker-shell

# Run setup and drop into shell
make docker-setup

# Clean up persistent containers
make docker-clean
```

### Minimal Setup (No Homebrew/Bun)

Add `VARIANT=minimal` to install without Homebrew or Bun:

```bash
# Run minimal setup and validation
make docker-test VARIANT=minimal

# Interactive shell with minimal setup (persistent state)
make docker-shell VARIANT=minimal

# Run minimal setup and drop into shell
make docker-setup VARIANT=minimal
```

That variant builds on `ubuntu:24.04` rather than `homebrew/brew`, so it covers
the paths taken when `brew` and `bun` are missing. CI runs both.

### Testing Remote Install

```bash
# Test local changes via HTTP server (before deployment)
make docker-test-remote-local

# Smoke test the deployed URL (after merge to master)
make docker-test-remote
```

## Makefile Commands

Run `make` to see all available commands:

| Command                         | Description                               |
| ------------------------------- | ----------------------------------------- |
| `make install`                  | Install dotfiles on local machine         |
| `make uninstall`                | Remove dotfiles symlinks                  |
| `make brew`                     | Install Homebrew packages                 |
| `make docker-build`             | Build Docker test image                   |
| `make docker-test`              | Run setup and validation in Docker        |
| `make docker-setup`             | Run setup and drop into shell             |
| `make docker-shell`             | Start persistent shell in Docker          |
| `make docker-clean`             | Remove persistent Docker containers       |
| `make docker-test-remote`       | Smoke test remote install (deployed URL)  |
| `make docker-test-remote-local` | Test remote install via local HTTP server |

Docker commands support `VARIANT=minimal` for testing without Homebrew/Bun (e.g., `make docker-test VARIANT=minimal`).

## Claude Code Plugin

The `claude-plugin/` directory contains a [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin with custom commands, agents, and skills.

### Commands

- `/explain-code` - Analyse and explain code functionality
- `/review-code` - Review code for bugs, security, and quality issues
- `/refactor-code` - Refactor code with analysis and pattern application

### Agents

- `code-quality-reviewer` reads finished changes and reports quality and security problems

### Skills

- `ungit` - Fetch GitHub repos/subdirs as LLM-friendly text (supports include/exclude filters)
