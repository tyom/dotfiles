# Claude Code Dotfiles Plugin

Personal development workflow automation - hooks, tools, and configurations.

## Status Line

A custom status bar showing model name and context usage with a visual progress bar.

### Enable

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/Code/dotfiles/claude-plugin/statusline/statusline.sh",
    "padding": 0
  }
}
```

### Output

```
Opus 4.5 | ctx ■■■■■□□□□□□□□□□□□□□□ 25%
```

Colors change based on usage:

- Grey: < 60%
- Orange: 60-80%
- Red: > 80%
