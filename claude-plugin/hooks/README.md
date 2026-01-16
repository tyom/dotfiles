# Hooks

Claude Code hooks that run automatically during various events.

## Available Hooks

### PostToolUse: Lint and Typecheck

**Trigger:** After `Edit`, `MultiEdit`, or `Write` operations on supported files.

**Actions:**

- TypeScript type checking (if tsconfig.json present)
- Prettier formatting (auto-fixes if needed)
- ESLint linting

**Supported file extensions:** `.ts`, `.tsx`, `.js`, `.jsx`, `.mjs`, `.mts`, `.md`, `.mdx`, `.json`, `.yaml`, `.yml`, `.css`, `.scss`, `.html`

### Stop: Run Tests

**Trigger:** Before Claude stops working.

**Actions:**

- Detects test runner (bun, npm, yarn, pnpm, vitest, jest, mocha)
- Runs project tests
- Blocks stopping if tests fail

## Configuration

Both hooks can be disabled per-project using environment variables in `.claude/settings.local.json`:

```json
{
  "env": {
    "LINT_ON_SAVE": "false",
    "RUN_TESTS_ON_STOP": "false"
  }
}
```

| Variable            | Default | Description                                             |
| ------------------- | ------- | ------------------------------------------------------- |
| `LINT_ON_SAVE`      | `true`  | Enable/disable lint, typecheck, and format on file save |
| `RUN_TESTS_ON_STOP` | `true`  | Enable/disable running tests before stopping            |
