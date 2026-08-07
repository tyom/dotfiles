<!--
Everything Claude and Codex share lives in ~/.codex/AGENTS.md, which Codex reads
directly and Claude Code reads through the import below. The path resolves
against this file, and both frames land on the same file: ~/.codex/AGENTS.md
before the symlink is followed, home/.codex/AGENTS.md in the repo after.

Rules for Claude and no other agent go under the import, as a "## Claude Code"
section. Run /context to confirm both files loaded.

Claude Code strips block HTML comments before this file reaches the context
window, so this note costs nothing to keep here.
-->

@../.codex/AGENTS.md
