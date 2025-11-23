# Dotfiles

This is a collection of Tyom's dotfiles and settings.

![Shell screenshot](https://raw.githubusercontent.com/tyom/dotfiles/master/shell.png)
![Vim screenshot](https://raw.githubusercontent.com/tyom/dotfiles/master/vim.png)

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
curl -fsSL https://raw.githubusercontent.com/tyom/dotfiles/master/install.sh | bash
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

### `~/.zshrc.bak`

Your original `.zshrc` is automatically backed up during installation and sourced at the end of the new `.zshrc`. Machine-specific shell configuration is preserved here.

### `~/.gitconfig.local`

Add your personal git configuration:

```ini
[user]
    name = Your Name
    email = your@email.com
```

### `~/.vimrc.local`

Add machine-specific vim configuration here.

### iTerm2

To configure iTerm settings set "Load preferences from a custom folder or URL" to `iterm2` URL in this repo:

```
~/.dotfiles/iterm2
```

## What Gets Installed

### Homebrew Packages

- `stow` - Symlink management
- `bat` - Better cat with syntax highlighting
- `git-delta` - Syntax highlighter for git diffs
- `scmpuff` - Numbered shortcuts for git commands
- `tree` - Directory tree viewer
- `wget` - File downloader
- `httpie` - HTTP client
- `gh` - GitHub CLI
- `n` - Node version manager
- `fx` - JSON processor
- `yarn` - JavaScript package manager

### Shell Tools

- Zsh with Oh-my-zsh
- Custom theme with git status, node version, and conda environment display
- fzf integration for fuzzy finding

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
| `make docker-shell` | Start persistent shell in Docker   |
| `make docker-setup` | Run setup and drop into shell      |
| `make docker-clean` | Remove persistent Docker container |
