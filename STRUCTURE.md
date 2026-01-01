# Repository Structure

This repository uses [GNU Stow](https://www.gnu.org/software/stow/) for symlink management.

## Stow Packages

Each directory listed in `STOW_PACKAGES` (see `scripts/vars.sh`) is a stow package. Running `stow <package>` creates symlinks in your home directory mirroring the package structure.

| Package      | Contents                                     |
| ------------ | -------------------------------------------- |
| `git/`       | `.gitconfig`, `.gitignore`, `.gitattributes` |
| `vim/`       | `.vimrc`, `.vimrc.bundles`                   |
| `oh-my-zsh/` | Custom theme (`tyom.zsh-theme`)              |
| `bin/`       | Scripts: `color-test`, `gb`, `git-author`    |

## Non-Stowed Directories

| Directory      | Purpose                                                 |
| -------------- | ------------------------------------------------------- |
| `zsh/`         | Zsh config (copied to `~/.dotfiles.zsh`, not symlinked) |
| `shell/`       | Shell modules sourced by `zsh/config.zsh`               |
| `scripts/`     | Installation and setup scripts                          |
| `claude-code/` | Claude Code plugin (commands, agents, skills)           |

## Adding New Dotfiles

1. Create a package directory: `mkdir newpackage`
2. Add files mirroring home structure: `newpackage/.newconfig` → `~/.newconfig`
3. Add package name to `STOW_PACKAGES` in `scripts/vars.sh`
4. Run `make install`
