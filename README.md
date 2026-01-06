# Dotfiles

This is a collection of Tyom's dotfiles and settings.

![Shell screenshot](https://tyom.github.io/dotfiles/shell.png)
![Vim screenshot](https://tyom.github.io/dotfiles/vim.png)

## Installation

Installation may take a few minutes as it will download and install a number of packages.

Setup can be run multiple times. It will update if necessary.

Admin password will be required during the setup process.

```bash
git clone https://github.com/tyom/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
make install
```

### Remote Installation

```bash
curl -fsSL https://tyom.github.io/dotfiles/install.sh | bash
```

You can customise the installation:

```bash
# Install to a different directory
DOTFILES_DIR=~/my-dotfiles curl -fsSL ... | bash

# Install from a different branch
DOTFILES_BRANCH=next curl -fsSL ... | bash
```

### Uninstall

To remove all symlinks:

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
│   └── bin/           # Shell scripts
├── git/               # Git config (included via ~/.gitconfig)
├── zsh/               # Zsh config + theme (sourced/symlinked)
├── shell/             # Shell modules
├── claude-plugin/     # Claude Code plugin (registered directly)
└── scripts/           # Installation scripts
```

See [docs/STRUCTURE.md](./docs/STRUCTURE.md) for detailed documentation.

## Customisation

The dotfiles in this repository are meant to be read-only. Your local configuration files are preserved and extended:

### `~/.gitconfig`

Your existing `.gitconfig` is preserved. The installer adds an `[include]` directive to load the dotfiles config. Add your personal git configuration directly to `~/.gitconfig`:

```ini
[user]
    name = Your Name
    email = your@email.com

[include]
    path = /path/to/dotfiles/git/.gitconfig
```

### `~/.gitignore`

A global `.gitignore` is copied to your home directory during setup (if one doesn't exist). You can edit it freely.

### `~/.zshrc`

Your existing `.zshrc` is preserved. The installer adds a single source line to load the dotfiles config. Add machine-specific shell configuration directly to `~/.zshrc`.

### `~/.vimrc.local`

Add machine-specific vim configuration here.

## What Gets Installed

### Core Tools

- **Bun** - Fast JavaScript runtime and package manager
- **Volta** - Node.js version manager
- **Node.js** - Installed via Volta

### Homebrew Packages

See [scripts/install/brew.sh](./scripts/install/brew.sh) for the list of installed packages.

### Shell Tools

- Zsh with Oh-my-zsh
- Custom theme with git status, node version, and conda environment display
- fzf integration for fuzzy finding

## Installation Flow

The installation process follows this sequence:

```
install.sh (entry point)
├── If run from existing repo: use that location
└── Otherwise: clone to ~/.dotfiles (or DOTFILES_DIR)
    └── Execute scripts/setup.sh

setup.sh (orchestrator)
├── 1. Confirm user wants to proceed
├── 2. Install Homebrew and packages (optional)
├── 3. Install Bun and Volta (JS tooling)
├── 4. Install Node.js via Volta
├── 5. Set up Zsh and Oh My Zsh (scripts/zsh.sh)
│   ├── Install zsh if missing
│   ├── Install Oh My Zsh if missing
│   ├── Modify ~/.zshrc to source dotfiles
│   └── Create ~/.dotfiles.zsh with DOTFILES_DIR embedded
├── 6. Create symlinks (scripts/stow.sh)
│   └── Symlink packages: vim, oh-my-zsh, bin
├── 7. Set up git (scripts/git.sh)
│   ├── Add [include] to ~/.gitconfig
│   └── Copy ~/.gitignore if missing
├── 8. Install Vim plugins (scripts/install/vim.sh)
│   ├── Install vim-plug
│   └── Run PlugInstall
├── 9. Install Claude Code plugin dependencies
└── 10. Validate installation (scripts/validate.sh)
```

### Zsh Configuration Chain

The shell configuration is loaded in this order:

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

### Symlinked Files

GNU Stow creates these symlinks from `stow/` to your home directory:

| Source                | Target             |
| --------------------- | ------------------ |
| `stow/.vimrc`         | `~/.vimrc`         |
| `stow/.vimrc.bundles` | `~/.vimrc.bundles` |
| `stow/bin/*`          | `~/bin/*`          |

The zsh theme is symlinked separately by `zsh.sh`:

- `zsh/tyom.zsh-theme` → `~/.oh-my-zsh/custom/themes/tyom.zsh-theme`

Git configuration is handled separately (not via stow):

- `~/.gitconfig` - An `[include]` directive is added to load the dotfiles config
- `~/.gitignore` - Copied during setup (if it doesn't exist) so you can customise it

### Interactive Prompts

During installation, you'll be asked:

1. **Confirmation to proceed** - "Warning: this will modify your dotfiles configuration." [Y/n]
2. **Homebrew installation** - "Install Homebrew and useful packages?" [Y/n]

To skip prompts (for CI/automation), set `YES_OVERRIDE=true`.

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

Test the remote install script in isolation:

```bash
# Test local changes via HTTP server (before deployment)
make docker-test-remote-local

# Smoke test the deployed URL (after merge to master)
make docker-test-remote
```

The `docker-test-remote-local` command starts a local HTTP server to serve `docs/install.sh`, simulating the remote install flow without requiring deployment. This is useful for testing changes to the install script before merging.

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

The `claude-plugin/` directory contains a local [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin with custom commands, agents, and skills.

### Commands

- `/explain-code` - Analyse and explain code functionality
- `/review-code` - Review code for bugs, security, and quality issues
- `/refactor-code` - Refactor code with analysis and pattern application

### Agents

- `code-quality-reviewer` - Proactively reviews code after completing features

### Skills

- `ungit` - Fetch code from GitHub repositories as LLM-friendly context
