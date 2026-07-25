# Agent instructions

Claude Code and Codex read the same rules from different paths, so the shared
part is written once here and assembled into both files.

```
common.md  ──┬─→  claude.tmpl.md  ──→  stow/.claude/CLAUDE.md  →  ~/.claude/CLAUDE.md
             └─→  codex.tmpl.md   ──→  stow/.codex/AGENTS.md   →  ~/.codex/AGENTS.md
```

Each template is copied with its lone `@common` line replaced by the contents of
`common.md`. Anything an agent should be told regardless of which one it is goes
in `common.md`. Anything true of one agent only goes in that agent's template,
above or below the `@common` line depending on where it should land.

Build with `make agents`. `scripts/stow.sh` also runs it before linking, so an
install cannot ship a stale file.

Two things to keep in mind:

- The files under `stow/` are generated. Editing them, or editing the symlinks
  in your home directory, loses the change on the next build. They carry no
  "generated" banner because that banner would sit in every agent's context
  window for no benefit.
- The templates are named `*.tmpl.md`, not `claude.md`, because macOS ignores
  filename case. A file here called `claude.md` is a `CLAUDE.md`, and Claude
  Code picks it up as real instructions for this repo.
