# Repository Structure

## Home Directory

The `home/` directory mirrors `$HOME`. Everything in it gets symlinked by
`scripts/link.sh`:

```text
home/
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
| `src/`           | Source for `home/` files that need a build step (see each subdir's README) |
| `src/agents/`    | Agent instructions: `common.md` plus a `*.tmpl.md` per agent, built by `make agents` |

## Adding New Dotfiles

1. Add files to `home/` mirroring home structure: `home/.newconfig` → `~/.newconfig`
2. Run `make install`
