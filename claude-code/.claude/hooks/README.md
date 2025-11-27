# Hooks

Hooks are automated responses triggered by specific events during Claude Code sessions.
They can approve, deny, validate, or react to tool executions.

## Configuration

Hooks are configured in `settings.json` (not as separate files):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write", // or "*" to match all tools
        "hooks": [
          {
            "type": "command", // or "llm" to run an LLM prompt
            "command": "${PAI_DIR}/hooks/your-command-here.sh" // $PAI_DIR env is set in settings.json
          }
        ]
      }
    ]
  }
}
```

## Hook Events

| Event              | Trigger                        | Purpose                              |
| ------------------ | ------------------------------ | ------------------------------------ |
| `PreToolUse`       | Before tool execution          | Approve, deny, or request permission |
| `PostToolUse`      | After tool completion          | Validation, formatting, feedback     |
| `UserPromptSubmit` | Before processing user prompts | Validate or add context              |
| `SessionStart`     | Session initialization         | Setup tasks                          |
| `SessionEnd`       | Session cleanup                | Cleanup tasks                        |
| `Notification`     | Permission/auth events         | Respond to system events             |

## Hook Types

- **command** - Execute a bash command
- **llm** - Run an LLM prompt for context-aware decisions

## Environment Variables

| Variable             | Description                 | Available For           |
| -------------------- | --------------------------- | ----------------------- |
| `CLAUDE_TOOL_NAME`   | Tool being executed         | PreToolUse, PostToolUse |
| `CLAUDE_TOOL_INPUT`  | JSON input to the tool      | PreToolUse, PostToolUse |
| `CLAUDE_FILE_PATHS`  | Affected file paths         | Edit, Write, Delete     |
| `CLAUDE_COMMAND`     | Bash command being executed | Bash PreToolUse         |
| `CLAUDE_TOOL_RESULT` | Output from the tool        | PostToolUse             |
| `CLAUDE_USER_PROMPT` | User's submitted prompt     | UserPromptSubmit        |

## Exit Codes

- **0** - Success
- **2** - Block execution (stderr becomes user feedback)
- **Other** - Non-blocking error

## Examples

### Auto-format TypeScript after edits

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "if [[ \"$CLAUDE_FILE_PATHS\" =~ \\.tsx?$ ]]; then npx prettier --write \"$CLAUDE_FILE_PATHS\"; fi"
          }
        ]
      }
    ]
  }
}
```

### Run type checking after edits

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit",
        "hooks": [
          {
            "type": "command",
            "command": "if [[ \"$CLAUDE_FILE_PATHS\" =~ \\.tsx?$ ]]; then npx tsc --noEmit --skipLibCheck; fi"
          }
        ]
      }
    ]
  }
}
```

### LLM-based bash command review

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "llm",
            "prompt": "Review this bash command for security risks. Respond with {\"permissionDecision\": \"allow\"} or {\"permissionDecision\": \"deny\"}"
          }
        ]
      }
    ]
  }
}
```
