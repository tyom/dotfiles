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
  without, and checks the first-run Homebrew paths on Linux and macOS.
- Third-party bootstrap inputs are pinned. The Bun, Volta and Homebrew installers
  are checksum-verified before execution, and Oh My Zsh is checked out at a
  reviewed commit.

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
- **[Scripts on your PATH](#scripts-on-your-path)**: `gl`, `gb`, `gw` and
  `git who` for logs, branches, worktrees and line ownership,
  [`agent-ctx`](#agent-ctx) for what an agent loads in a repo, plus
  `color-test` and two of my tools from Homebrew:
  [`ungit`](https://github.com/tyom/ungit) reads a GitHub repo or subdirectory
  as text, and [`repo-intel`](https://github.com/tyom/repo-intel) builds a
  contributor dashboard for any git repo
- **Claude Code plugin**: one `Stop` hook that lints, type checks, formats and
  tests what the agent edited before it stops. Codex runs the same file

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
│   ├── .claude/       # Claude Code instructions (imports the Codex file) + status line
│   ├── .codex/        # Agent instructions, shared by both
│   └── bin/           # Shell scripts
├── git/               # Git config (included via ~/.gitconfig)
├── zsh/               # Zsh config + theme (sourced/symlinked)
├── shell/             # Shell modules
├── claude-plugin/     # Claude Code hook plugin
├── scripts/           # Installation scripts
└── test/              # Fast installer, shell and PATH-script tests
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

## Scripts on your PATH

Five scripts, installed with the rest of `home/`. The first four are about the
repository you are in, the last about the agent reading it. `git who`, `gb`,
`gw` and `agent-ctx` explain themselves with `-h`.

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
The current branch is a block and merged local branches carry a tick. Takes the
usual `git log` options.

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

### `agent-ctx`

What a coding agent loads when it opens a repo, and where that comes from. Run
it in any directory:

```text
this repo                              always  on trigger     on read  items
  nothing: no CLAUDE.md, .claude/ or .mcp.json

inherited                              always  on trigger     on read  items
  plugin vercel skills                  2,725     126,199     296,152     30
  user skills                           1,999      68,901   1,100,203     34
  plugin figma skills                   1,974      65,292     440,308     12
  ~/.codex/AGENTS.md                      973           -           -      -
  ...
  ──────────────────────────────────────────────────────────────────────────
  total  ▌           2% of 200k         4,334     392,922   1,932,435    141
  ∟ 9,802 in skill and command descriptions, capped at 2,000 by the listing budget
```

Three columns, because a skill costs its context in three stages. **always** is
what is resident before you type: memory files, and the `description` of every
skill, command and agent. A memory file counts for what survives its load, which
under Claude means without its frontmatter or any HTML comment standing on its
own, and under Codex means every byte. A skill the model cannot invoke is left
out, because its description never reaches the listing. **on trigger** is the
rest of that entry file, what one skill costs when it actually fires. **on read**
is everything below it, the references the agent only pays for if it opens them.
All three are estimates at three bytes a token.

The gap between the last two is the point: most trees are mostly **on read**, so
a large group is far cheaper in practice than one number would suggest.

Skills and commands share one budget, and it is small: Claude reserves one
percent of the window for the whole listing and shortens descriptions once they
run over. The line under the total says how much of the listing survives that,
which is why 141 items adding up to 9,802 tokens of description cost 2,000 on a
200k model. Codex enforces a budget of its own but does not publish its size, so
its listing is shown in full.

Three bytes a token, not the four usually quoted: description prose is denser
than that. Measured against `/context` over seventeen skills whose descriptions
ship whole, 5,420 bytes for 1,790 real tokens. Individual rows land within a few
percent — `fallow` reads 336 against a real 340.

The totals row draws **always** as the [status line](#status-line) does, ten
cells over the window and the same colours by absolute count, so the two read
the same way. `-w` sets the window, `200k` by default: `-w 1m` for a long
context model, or any token count. Only **always** gets a bar, because the other
two are ceilings nobody reaches.

Below the table it names the hooks that fire per event and the MCP servers in
play. Server tool schemas ship on every request and are usually the largest
single cost, but nothing on disk records their size, so only a live session can
add them up.

Pass part of a group name to open it up, biggest first:

```text
$ agent-ctx 'user skills'
user skills                             always  on trigger     on read
  fallow                                   336      12,247      56,836
  improve                                  174       4,856       9,717
  explainer                                  0       4,361         981
```

The table covers what your files put in context, never what an agent writes for
itself. Codex will render the prompt it would send, which is the one place those
blocks can be counted, so `--prompt` asks it:

```text
$ agent-ctx --prompt
block                                       chars      tokens
  skills_instructions                       14,636       4,878
  permissions instructions                   6,101       2,033
  AGENTS.md instructions                     2,970         990
  You are `/root`, the primary agent i       2,264         754
  recommended_plugins                        1,896         632
  ...
  ────────────────────────────────────────────────────────────
  total                                     30,640      10,213
```

Two of those come from disk and match the table: the skills block against the
skill descriptions plus the `(file: …)` line under each, and `AGENTS.md`
instructions against the memory row. The rest is Codex describing itself, and
about half of that grows with the plugins you install. Claude Code has no
equivalent outside a session, where `/context` breaks down the same thing.

`-a` picks the agent, Claude Code by default:

- `-a claude` reads `~/.claude` and the repo's `.claude` and `.mcp.json`, with
  plugins from `installed_plugins.json` minus the ones turned off in
  `settings.json`. `CLAUDE.md`, `CLAUDE.local.md` and `AGENTS.md` are found in
  every directory from the cwd up to just below `/`, and one above the repo
  counts as inherited, because it loads in every project under it
- `-a codex` reads `$CODEX_HOME` or `~/.codex` and the repo's `.codex`, with
  servers and plugins from `config.toml` minus anything marked `enabled = false`.
  Codex reads an `AGENTS.md` from the repo root down to the directory it started
  in, so every one of those counts, and `AGENTS.override.md` takes the place of
  `AGENTS.md` in its own directory. Its listing names the file each skill came
  from, so that line is counted with the description; a plugin whose marketplace
  is no longer registered is not counted at all, because Codex does not load it

Symlinked skills are followed, so a skill kept in another repo counts where it
is used. Nothing is started and nothing is written. Requires `jq`, which the
Homebrew step installs.

## Development

Run the fast tests, or install into a container instead of your machine:

```bash
# Fast installer, shell, PATH-script and Stop-hook tests
make check

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

### Repinning Bootstrap Dependencies

`scripts/versions.sh` records the reviewed Bun and Volta releases, the Oh My Zsh
commit, and the Homebrew installer commit, with SHA-256 checksums for downloaded
scripts. Refresh all of them explicitly:

```bash
make repin
git diff -- scripts/versions.sh
make check
```

Review the diff before committing it. Installation never changes these pins.

## Makefile Commands

Run `make` to see all available commands:

| Command                         | Description                               |
| ------------------------------- | ----------------------------------------- |
| `make install`                  | Install dotfiles on local machine         |
| `make uninstall`                | Remove dotfiles symlinks                  |
| `make check`                    | Run the fast local tests                  |
| `make repin`                    | Refresh bootstrap versions and checksums  |
| `make brew`                     | Install Homebrew packages                 |
| `make docker-build`             | Build Docker test image                   |
| `make docker-test`              | Run setup and validation in Docker        |
| `make docker-setup`             | Run setup and drop into shell             |
| `make docker-shell`             | Start persistent shell in Docker          |
| `make docker-clean`             | Remove persistent Docker containers       |
| `make docker-test-remote`       | Smoke test remote install (deployed URL)  |
| `make docker-test-remote-local` | Test remote install via local HTTP server |

Docker commands support `VARIANT=minimal` for testing without Homebrew/Bun (e.g., `make docker-test VARIANT=minimal`).

## Claude Code

### Plugin

The `claude-plugin/` directory is a [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
plugin holding one thing: a `Stop` hook that lints, type checks, formats and
tests the files Claude edited. See [`claude-plugin/hooks/README.md`](claude-plugin/hooks/README.md)
for what it runs and how to switch parts of it off.

It is a plugin because that is how a hook gets registered. `make install` runs
`claude plugin install` for you when the item is ticked. There is nothing to
build or install: the hook is plain JavaScript on `node:` builtins, so `node`,
`deno` and `bun` all run it as-is.

Prompts and agents are not here. Reusable skills live in
[tyom/skills](https://github.com/tyom/skills) so Codex gets them too, and
anything Claude Code ships built in (`/code-review`, `/simplify`) is not worth
reimplementing.

### Status line

`home/.claude/statusline.sh` shows the model, context usage and branch. It is
symlinked with the rest of `home/`, so point `~/.claude/settings.json` at the
link, not at this repo:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"$HOME/.claude/statusline.sh\"",
    "padding": 0
  }
}
```

```text
Opus 5 | 14.52k ████████▌ 89% | ⎇ master
```

Model, tokens used, a 10-cell bar over the context window, the percentage, and
the workspace branch. Each cell is 10%, with a half block (▌) from 5%. The token
count and bar are coloured by absolute usage, not by the percentage, so the
reading does not change meaning between a 200k and a 1M window:

| Tokens    | Colour |
| --------- | ------ |
| ≤ 100k    | green  |
| 100k–600k | yellow |
| > 600k    | red    |

Before the first response there is nothing to measure, so only the model and
branch are drawn. Requires `jq`, which the Homebrew step installs.
