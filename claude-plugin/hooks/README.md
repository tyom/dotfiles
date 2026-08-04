# Hooks

## Stop: lint, type check, format, test

One hook, `stop/stop.ts`, runs before Claude stops. It reads the session
transcript once for the files Claude edited, then works only on those:

| Tool     | Scope                                                                                               |
| -------- | --------------------------------------------------------------------------------------------------- |
| tsc      | Project-wide, skipped unless TS/JS or a tsconfig was edited                                         |
| eslint   | Edited JS/TS files; the whole project if eslint config or package.json changed                      |
| prettier | Edited prettier-able files only, never a mass format                                                |
| tests    | The framework's related-tests mode (vitest, jest); the full suite if a build or test config changed |

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

## Tests

`bun test` from `claude-plugin/`. It drives the hook the way Claude Code does,
transcript on stdin and decision on stdout, against a throwaway project.
