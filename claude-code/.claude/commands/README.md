# Custom Slash Commands

Custom slash commands are Markdown files that contain prompts Claude Code executes
when you type `/command-name`.

## Location

- **Personal commands**: `~/.claude/commands/` - available in all projects
- **Project commands**: `.claude/commands/` - shared with team via git

## File Format

Commands are Markdown files with optional frontmatter:

```markdown
---
description: Brief description shown in /help
allowed-tools: Edit,Read,Grep
argument-hint: "<file-path>"
---

Your prompt here. Use $ARGUMENTS for user input.
```

### Frontmatter Fields (all optional)

| Field           | Purpose                                            |
| --------------- | -------------------------------------------------- |
| `description`   | Shown in `/help` listings                          |
| `allowed-tools` | Comma-separated list of permitted tools            |
| `model`         | Specific Claude model to use                       |
| `argument-hint` | Placeholder shown in help (e.g., `<issue-number>`) |

## Arguments

- `$ARGUMENTS` - all text after the command name
- `$1`, `$2`, etc. - positional arguments

Example:

```markdown
Fix issue #$ARGUMENTS in the codebase.
```

Usage: `/fix-issue 123`

## Special Prefixes

- `!` - Execute bash command and include output
- `@` - Include file contents

Example:

```markdown
Review the git history:
! git log --oneline -10

And this file:
@src/index.ts
```

## Organization

Use subdirectories to organize commands:

```
commands/
├── dev/
│   ├── review.md
│   └── refactor.md
└── docs/
    └── generate.md
```

Invoke as `/dev:review` or `/docs:generate`.
