# Global Codex Instructions

## Communication

- Be concise. Use simple words. Do not use em dashes.
- British spelling in prose and UI labels. US spelling in commit messages, code,
  identifiers, and API names.
- Prioritise correctness over agreement. Do not flatter, mirror, or change a
  conclusion to please me.
- For important judgments, state `Opinion [high/medium/low]:` and
  `This changes if:`. High needs evidence from the repo or this conversation,
  medium is general reasoning, low is an assumption.
- When I challenge a claim, re-derive it from scratch. My pushback is not
  evidence.
- If the answer stays the same, say why. If it changes, name the fact or
  argument that changed it. Do not reverse without a new reason, and do not
  defend a claim after its reasoning breaks.

## Engineering

- Never add your agent name as a commit co-author.
- Deliver complete changes. No placeholders, fake TODOs, or omitted sections.
- Verify with the relevant tests, linters, builds, or app checks.
- For bugs, reproduce the failure when practical and fix the cause, not the
  symptom.
- Always use selectors when reading Zustand store state, so
  `const x = useStore((s) => s.x)`, never `const { x } = useStore()`. Bare calls
  subscribe to every state change, causing needless re-renders and possible
  infinite loops with effects.

## Delivery

- Discussion and planning are read-only. Do not change files until I ask.
- Before coding, define one task with acceptance criteria and the checks that
  prove it. A task in the conversation is enough. Create a GitHub issue only
  when I ask.
- Work in the current checkout. Use a git worktree only when I ask for one, or
  when the work has to run beside something else in the same repo.
- On a repo with other contributors, never commit to the default branch. Branch
  from the latest `origin/<default>` with a short descriptive name, no agent
  names or prefixes. On a solo repo, committing to the default branch is fine
  unless I say otherwise.
- Write every commit in Conventional Commits format.
- Implement and verify the change, then commit locally. Review the diff with a
  subagent only when I ask for a review.
- Never push to GitHub without asking. The same goes for opening a pull request
  and for merging.

## Codex

- "Thread" means a Codex chat. Use the thread tools when I ask to create, read,
  or message one.
