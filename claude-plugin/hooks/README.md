# Hooks

## Stop: lint, type check, format, test

One hook, `stop/stop.ts`, runs before Claude stops. It reads the session
transcript once for the files Claude edited, then works only on those:

| Tool     | Scope                                                                                                                                                                          |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| tsc      | Project-wide, skipped unless TS/JS, a tsconfig or package.json was edited                                                                                                      |
| eslint   | Edited JS/TS files; the whole project if eslint config or package.json changed                                                                                                 |
| prettier | Edited prettier-able files only, never a mass format                                                                                                                           |
| tests    | Related-tests mode (vitest, jest); bun has none, so it takes the edited paths only when all of them are test files; full suite otherwise, or if a build or test config changed |

Nothing runs when the session only touched docs, lockfiles or other files that
cannot change whether the code works. Lint errors block before the tests run — a
project that does not type check has nothing to learn from a two-minute test run.

Each tool is skipped when the project has no config for it or no binary in
`node_modules/.bin`, so the hook is a no-op in a project that does not use it.

## Configuration

Set per-project in `.claude/settings.local.json`:

```json
{
  "env": {
    "LINT_ON_SAVE": "false",
    "RUN_TESTS_ON_STOP": "false"
  }
}
```

| Variable               | Default | Description                                    |
| ---------------------- | ------- | ---------------------------------------------- |
| `LINT_ON_SAVE`         | `true`  | Lint, type check and format                    |
| `LINT_FULL`            | `false` | Ignore the edited-file scope, run project-wide |
| `RUN_TESTS_ON_STOP`    | `true`  | Run tests                                      |
| `RUN_TESTS_FULL_SUITE` | `false` | Ignore related-tests mode, always run the lot  |

## Codex

Codex fires `Stop` too, but it cannot get the hook from this plugin: its plugin
format is separate, so the marketplace entry here is Claude Code's alone. Point
`~/.codex/hooks.json` at the file instead, which also means Codex runs the repo
copy rather than a snapshot.

The directory keeps its Claude Code name even though both agents run the hook,
because `claude plugin install` copies this directory into a cache and a
`hooks.json` command cannot reference anything outside it. The script has to live
here, so Codex reaches in rather than the code moving somewhere neutral.

```json
"Stop": [
  {
    "hooks": [
      {
        "command": "node '/path/to/dotfiles/claude-plugin/hooks/stop/stop.mjs'",
        "timeout": 150,
        "type": "command"
      }
    ]
  }
]
```

Codex asks to trust a new hook before it will run, and records the approval in
`~/.codex/config.toml` under `[hooks.state]`. `[features] hooks = true` must be
set. It is not wired up by `make install`: `~/.codex/hooks.json` is written by
other tools too, so this repo does not own the file.

## Finding the edited files

Claude Code passes a `transcript_path`, and the edits are read from it. Codex
fires `Stop` with no transcript, so there the hook falls back to the git working
tree: what changed since `HEAD`, plus anything untracked that git is not
ignoring, scoped to the project root.

The transcript wins wherever it exists. The fallback is wider by nature — a file
you edited by hand counts as an edit — so a session started in a dirty repo can
put pre-existing changes in scope. Outside a git repo it finds nothing and the
hook does nothing.

## Runtime

`stop.mjs` is plain JavaScript on `node:` builtins, so `node`, `deno` and `bun`
all run it as-is with nothing installed. The plugin has no dependencies, no
lockfile and no build step. `hooks.json` calls `node`; swap that for
`deno run -A` or `bun run` if you would rather.

Types are JSDoc under a `// @ts-check` pragma, so an editor checks them with its
own TypeScript and no dependency is needed. It checks clean under `--strict`. An
editor that does not fetch `@types/node` will flag `process` and `console` as
unknown; nothing else here needs them.

## Tests

`node --test hooks/stop/stop.test.mjs` from `claude-plugin/`. It drives the hook
the way Claude Code does, transcript on stdin and decision on stdout, against a
throwaway project, under whichever runtime is running the tests.
