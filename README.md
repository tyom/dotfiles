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
  repo, made with [GNU Stow](https://www.gnu.org/software/stow/), so the file you
  edit here is the file your shell reads. There is nothing to sync.
- You choose what gets installed. Setup shows a checklist, and Homebrew packages,
  macOS apps and the Claude Code plugin start unchecked.
- You can run it again any time. Each step skips what it has already done, and
  the last step runs over 30 checks, including that every symlink still points
  into this repo. CI installs all of it on Linux, once with Homebrew and once
  without.

## What's Included

- **Shell**: Zsh with Oh-My-Zsh and a custom theme displaying git status, Node version, and conda environment
- **Git**: Useful aliases, global gitignore, and streamlined configuration
- **Terminal**: Ghostty config (translucent blurred black, tabs titlebar, thickened 16pt text)
- **Vim**: Pre-configured with vim-plug and curated plugins
- **CLI Tools**: bat (syntax-highlighted cat), fzf (fuzzy finder), git-delta (better diffs), and more via Homebrew
- **Dev Tools**: Volta and Node.js; Bun (optional)
- **Bin Scripts**: Handy commands like `gb` and `git-author`, plus standalone tools installed via Homebrew: [`ungit`](https://github.com/tyom/ungit) (clone GitHub repos/subdirs as files or text) and [`repo-intel`](https://github.com/tyom/repo-intel) (contributor stats dashboard for any git repo)
- **Claude Code Plugin**: Custom commands for code review, explanation, and refactoring

## Installation

You do not need to clone anything. This gets the repo into `~/.dotfiles` and runs
setup:

```bash
curl -fsSL https://tyom.github.io/dotfiles/install.sh | bash
```

Setup shows a checklist. Toggle items by number, press <kbd>Enter</kbd> to
install, or <kbd>q</kbd> to quit. It takes a few minutes to download and set up
packages. At the end you get a summary and one line of validation results.

```bash
# Install everything, no checklist (for CI or a fresh box)
curl -fsSL https://tyom.github.io/dotfiles/install.sh | bash -s -- -y

# Somewhere other than ~/.dotfiles
DOTFILES_DIR=~/my-dotfiles curl -fsSL https://tyom.github.io/dotfiles/install.sh | bash

# From another branch
DOTFILES_BRANCH=next curl -fsSL https://tyom.github.io/dotfiles/install.sh | bash
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
always run verbose.

### Uninstall

```bash
make uninstall
```

## Structure

This repository uses [GNU Stow](https://www.gnu.org/software/stow/) for symlink management:

```
dotfiles/
├── stow/              # Symlinked to ~/
│   ├── .vimrc
│   ├── .vimrc.bundles
│   ├── .config/       # ~/.config entries (ghostty)
│   └── bin/           # Shell scripts
├── git/               # Git config (included via ~/.gitconfig)
├── zsh/               # Zsh config + theme (sourced/symlinked)
├── shell/             # Shell modules
├── claude-plugin/     # Claude Code plugin
└── scripts/           # Installation scripts
```

See [docs/STRUCTURE.md](./docs/STRUCTURE.md) for detailed documentation.

## Customisation

Your local configuration files are preserved and extended. The dotfiles in this repository are read-only.

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

A global `.gitignore` is copied during setup (if one doesn't exist). Edit it freely.

### `~/.zshrc`

The installer adds a single source line. Add machine-specific configuration directly to your `.zshrc`.

### `~/.vimrc.local`

Add machine-specific Vim configuration here.

### `~/.config/ghostty/config.ghostty`

Symlinked from this repo, so edit it from either side. Reload Ghostty with
<kbd>⌘⇧,</kbd> to apply changes, and check your edit with
`ghostty +validate-config`.

## What Gets Installed

### Dev Tools

- **[Volta](https://volta.sh/)** - JavaScript tool manager
- **[Node.js](https://nodejs.org/)** - Installed via Volta
- **[Bun](https://bun.sh/)** (optional) - Fast JavaScript runtime and package manager

### Homebrew Packages (optional)

See [scripts/install/brew.sh](./scripts/install/brew.sh) for the full list.

### Shell

- Zsh with Oh-My-Zsh
- Custom theme with git status, Node version, and conda environment
- fzf integration for fuzzy finding

<details>
<summary><strong>Installation Flow</strong></summary>

```
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
├── 8. Create symlinks (scripts/stow.sh)
│   └── Symlink stow/ contents to ~/
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

```
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

GNU Stow creates these symlinks from `stow/` to your home directory:

| Source                          | Target                        |
| ------------------------------- | ----------------------------- |
| `stow/.vimrc`                   | `~/.vimrc`                    |
| `stow/.vimrc.bundles`           | `~/.vimrc.bundles`            |
| `stow/.config/ghostty/config.ghostty` | `~/.config/ghostty/config.ghostty` |
| `stow/bin/*`                    | `~/bin/*`                     |

`stow.sh` creates `~/bin` and `~/.config/ghostty` before stowing. Stow replaces a
whole directory with a single symlink when the target does not exist yet, so
without those directories, `~/.config` itself would become a link into this repo.

The zsh theme is symlinked separately by `zsh.sh`:

- `zsh/tyom.zsh-theme` → `~/.oh-my-zsh/custom/themes/tyom.zsh-theme`

Git configuration is handled separately (not via stow):

- `~/.gitconfig` - An `[include]` directive is added to load the dotfiles config
- `~/.gitignore` - Copied during setup (if it doesn't exist) so you can customise it

</details>

## Development

Test dotfiles in a Docker sandbox:

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

Test the fallback paths without Homebrew or Bun using the `VARIANT=minimal` flag:

```bash
# Run minimal setup and validation
make docker-test VARIANT=minimal

# Interactive shell with minimal setup (persistent state)
make docker-shell VARIANT=minimal

# Run minimal setup and drop into shell
make docker-setup VARIANT=minimal
```

The minimal variant uses a bare Ubuntu image instead of the Homebrew base image, testing that the dotfiles install correctly when Homebrew and Bun are not available.

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

- `code-quality-reviewer` - Proactively reviews code after completing features

### Skills

- `ungit` - Fetch GitHub repos/subdirs as LLM-friendly text (supports include/exclude filters)
