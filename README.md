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
sh -c "$(curl -fsSL https://raw.githubusercontent.com/tyom/dotfiles/master/install.sh)"
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
├── zsh/           # Zsh configuration (.zshrc)
├── oh-my-zsh/     # Oh-my-zsh custom theme
├── bin/           # Custom scripts (~/bin/)
├── shell/         # Shell modules (sourced by .zshrc, not symlinked)
└── scripts/       # Installation and setup scripts
```

See [STRUCTURE.md](./STRUCTURE.md) for detailed documentation.

## Customisation

These dotfiles are meant to be read-only. Additional configuration should be added to local dotfiles:

### `~/.zsh.local`

Add machine-specific shell configuration here.

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

To test dotfiles in a sandbox using Docker:

```bash
make test
```

This builds and runs a Docker container with the dotfiles installed, then validates the installation.

## Makefile Commands

| Command | Description |
|---------|-------------|
| `make install` | Run full installation |
| `make uninstall` | Remove all symlinks |
| `make backup` | Backup existing dotfiles |
| `make brew` | Install Homebrew packages |
| `make test` | Test in Docker container |
