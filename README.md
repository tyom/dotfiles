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

This repository uses [GNU Stow](https://www.gnu.org/software/stow/) for symlink management. Each top-level directory is a "stow package" that mirrors the home directory structure:

```
dotfiles/
├── git/           # Git configuration (.gitconfig, .gitignore, .gitattributes)
├── vim/           # Vim configuration (.vimrc, .vimrc.bundles)
├── zsh/           # Zsh configuration (sourced, not symlinked)
├── oh-my-zsh/     # Oh-my-zsh custom theme
├── bin/           # Custom scripts (~/bin/)
├── shell/         # Shell modules (sourced by .zshrc, not symlinked)
└── scripts/       # Installation and setup scripts
```

See [STRUCTURE.md](./STRUCTURE.md) for detailed documentation.

## Customisation

These dotfiles are meant to be read-only. Additional configuration should be added to local dotfiles:

### `~/.zshrc`

Your existing `.zshrc` is preserved. The installer adds a single source line to load the dotfiles config. Add machine-specific shell configuration directly to `~/.zshrc`.

### `~/.gitconfig.local`

Add your personal git configuration:

```ini
[user]
    name = Your Name
    email = your@email.com
```

### `~/.vimrc.local`

Add machine-specific vim configuration here.

## What Gets Installed

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
└── Clone/download repository to ~/.dotfiles
    └── Execute scripts/setup.sh

setup.sh (orchestrator)
├── 1. Confirm user wants to proceed
├── 2. Install Homebrew and packages (optional)
├── 3. Create ~/.dotfilesrc with DOTFILES_DIR
├── 4. Set up Zsh and Oh My Zsh (scripts/zsh.sh)
│   ├── Install zsh if missing
│   ├── Install Oh My Zsh if missing
│   ├── Modify ~/.zshrc to source dotfiles
│   └── Copy zsh/dotfiles.zsh to ~/.dotfiles.zsh
├── 5. Create symlinks (scripts/stow.sh)
│   └── Symlink packages: git, vim, oh-my-zsh, bin
├── 6. Install Vim plugins (scripts/install/vim.sh)
│   ├── Install vim-plug
│   └── Run PlugInstall
└── 7. Validate installation (scripts/validate.sh)
```

### Zsh Configuration Chain

The shell configuration is loaded in this order:

```
~/.zshrc
└── sources ~/.dotfiles.zsh
    ├── sources zsh/config.zsh (pre-oh-my-zsh setup)
    │   ├── sources shell/utils.sh
    │   ├── sources shell/exports.sh
    │   ├── sources shell/aliases.sh
    │   ├── sources shell/functions.sh
    │   └── configures oh-my-zsh plugins
    └── sources oh-my-zsh.sh
        └── loads theme and plugins
```

### Symlinked Files

GNU Stow creates these symlinks in your home directory:

| Package   | Source                            | Target                                      |
| --------- | --------------------------------- | ------------------------------------------- |
| git       | `git/.gitconfig`                  | `~/.gitconfig`                              |
| git       | `git/.gitignore`                  | `~/.gitignore`                              |
| git       | `git/.gitattributes`              | `~/.gitattributes`                          |
| vim       | `vim/.vimrc`                      | `~/.vimrc`                                  |
| vim       | `vim/.vimrc.bundles`              | `~/.vimrc.bundles`                          |
| oh-my-zsh | `oh-my-zsh/.oh-my-zsh/custom/...` | `~/.oh-my-zsh/custom/themes/tyom.zsh-theme` |
| bin       | `bin/bin/*`                       | `~/bin/*`                                   |

### Non-Symlinked Files

These files are copied or created (not symlinked):

| File              | Description                              |
| ----------------- | ---------------------------------------- |
| `~/.dotfilesrc`   | Sets `DOTFILES_DIR` environment variable |
| `~/.dotfiles.zsh` | Copied from `zsh/dotfiles.zsh`           |

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

# Clean up persistent container
make docker-clean
```

## Makefile Commands

Run `make` to see all available commands:

| Command             | Description                        |
| ------------------- | ---------------------------------- |
| `make install`      | Install dotfiles on local machine  |
| `make uninstall`    | Remove dotfiles symlinks           |
| `make brew`         | Install Homebrew packages          |
| `make docker-build` | Build Docker test image            |
| `make docker-test`  | Run setup and validation in Docker |
| `make docker-setup` | Run setup and drop into shell      |
| `make docker-shell` | Start persistent shell in Docker   |
| `make docker-clean` | Remove persistent Docker container |
