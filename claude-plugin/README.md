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

```text
Opus 4.5 | ctx ■■■■■□□□□□□□□□□▨▨▨▨▨ 33%
```

The bar shows 15 usable squares plus 5 reserved squares (▨) representing the 22.5% auto-compact buffer. The percentage shown is the **effective usage** against the usable 77.5% of context (e.g., 25% total context = 32% effective).

Colors change based on effective usage:

- Grey: < 75% (~58% total)
- Orange: 75–93% (~58–72% total)
- Red: ≥ 94% (~73%+ total)
