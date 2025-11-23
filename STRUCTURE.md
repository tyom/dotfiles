# Repository Structure

This document explains the organization of this dotfiles repository.

## Overview

This repository uses [GNU Stow](https://www.gnu.org/software/stow/) for symlink management. Stow creates symlinks from the home directory to files in this repository, making it easy to version control dotfiles.

## Stow Packages

Each top-level directory (except `scripts/`, `macOS/`, `test/`, and `shell/`) is a "stow package". When you run `stow <package>`, it creates symlinks in your home directory that mirror the package's structure.

### `git/`

Git configuration files:

```
git/
├── .gitconfig      → ~/.gitconfig
├── .gitignore      → ~/.gitignore (global)
└── .gitattributes  → ~/.gitattributes
```

The `.gitconfig` includes:
- Delta pager for beautiful diffs
- Useful aliases (gs, gl, gco, etc.)
- Color configuration
- Pull with rebase by default
- Local config inclusion (`~/.gitconfig.local`)

### `vim/`

Vim configuration:

```
vim/
├── .vimrc          → ~/.vimrc
└── .vimrc.bundles  → ~/.vimrc.bundles
```

Uses vim-plug for plugin management with:
- Gruvbox color scheme
- Airline status bar
- NERDTree file explorer
- Git gutter

### `zsh/`

Zsh configuration:

```
zsh/
└── .zshrc          → ~/.zshrc
```

The `.zshrc` sources modular config from the `shell/` directory.

### `oh-my-zsh/`

Custom Oh-my-zsh theme:

```
oh-my-zsh/
└── .oh-my-zsh/
    └── custom/
        └── themes/
            └── tyom.zsh-theme  → ~/.oh-my-zsh/custom/themes/tyom.zsh-theme
```

Features:
- User and hostname display
- Conda environment indicator
- Node.js version display
- Git status with custom symbols

### `bin/`

Custom executable scripts:

```
bin/
└── bin/
    ├── color-test   → ~/bin/color-test
    ├── gb           → ~/bin/gb
    ├── git-author   → ~/bin/git-author
    ├── icat         → ~/bin/icat
    └── ils          → ~/bin/ils
```

## Non-Stowed Directories

### `shell/`

Shell configuration modules that are **sourced** (not symlinked) by `.zshrc`:

```
shell/
├── aliases    # Command aliases
├── config     # Zsh settings (history, completion)
├── exports    # Environment variables and PATH
├── functions  # Custom shell functions
├── fzf        # Fuzzy finder configuration
└── utils      # Utility functions (used by install scripts too)
```

These files remain in the repository and are sourced via `$DOTFILES_DIR/shell/`.

### `scripts/`

Installation and setup scripts:

```
scripts/
├── setup.sh       # Main installation orchestrator
├── stow.sh        # Creates symlinks via Stow
├── unstow.sh      # Removes symlinks
├── backup.sh      # Backs up existing dotfiles
├── zsh.sh         # Installs zsh and oh-my-zsh
├── validate.sh    # Validates installation
├── vars           # Shared variables
└── install/
    ├── brew.sh      # Homebrew installation
    ├── brew-cask.sh # macOS apps via Homebrew
    └── vim.sh       # Vim plugin installation
```

## How Stow Works

When you run `stow -d /path/to/dotfiles -t ~ git`, Stow:

1. Looks at the `git/` directory
2. For each file, creates a symlink in `~` pointing to the original
3. Example: `~/.gitconfig` → `/path/to/dotfiles/git/.gitconfig`

Benefits:
- Files stay in the repository (easy to version control)
- Symlinks make them appear in the expected locations
- Easy to add/remove packages
- Supports nested directory structures

## Adding New Dotfiles

1. Create a new package directory: `mkdir newpackage`
2. Add files mirroring home directory structure:
   ```
   newpackage/
   └── .newconfig  # Will link to ~/.newconfig
   ```
3. Add the package name to `STOW_PACKAGES` in `scripts/vars`
4. Run `make install` or manually: `stow newpackage`

## Environment Variables

- `$DOTFILES_DIR` - Path to this repository (set in `~/.dotfilesrc`)
- `$YES_OVERRIDE` - Skip interactive prompts when `true`
