# Repository Structure

This repository uses [GNU Stow](https://www.gnu.org/software/stow/) for symlink management.

## Stow Directory

The `stow/` directory mirrors `$HOME`. Everything in it gets symlinked:

```
stow/
├── .vimrc              → ~/.vimrc
├── .vimrc.bundles      → ~/.vimrc.bundles
├── .claude/CLAUDE.md   → ~/.claude/CLAUDE.md   (generated, see src/agents/)
├── .codex/AGENTS.md    → ~/.codex/AGENTS.md    (generated, see src/agents/)
└── bin/                → ~/bin/
```

## Other Directories

| Directory        | Purpose                                                        |
| ---------------- | -------------------------------------------------------------- |
| `git/`           | Git config (included via `[include]` in user's `~/.gitconfig`) |
| `zsh/`           | Zsh config (sourced) + theme (symlinked to ~/.oh-my-zsh/)      |
| `shell/`         | Shell modules sourced by `zsh/config.zsh`                      |
| `claude-plugin/` | Claude Code plugin (registered directly, not symlinked)        |
| `scripts/`       | Installation and setup scripts                                 |
| `src/`           | Source for `stow/` files that need a build step (see each subdir's README) |
| `src/agents/`    | Agent instructions: `common.md` plus a `*.tmpl.md` per agent, built by `make agents` |

## Adding New Dotfiles

1. Add files to `stow/` mirroring home structure: `stow/.newconfig` → `~/.newconfig`
2. Run `make install`
