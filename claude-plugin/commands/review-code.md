---
description: Review code for bugs, logic errors, security, and quality issues
argument-hint: [file/PR/changes to review]
---

# Code Review

Review the following: **$ARGUMENTS**

## Approach

1. **Understand scope** - Determine what's being reviewed:
   - Specific file or function
   - Recent changes (git diff)
   - Pull request
   - Broader codebase area
2. **Read with context** - Understand the code's purpose and surrounding context
3. **Identify issues** - Focus on problems that actually matter
4. **Report findings** - Provide specific, actionable feedback

## Review Focus

Prioritize finding:

- **Bugs** - Logic errors, off-by-one, null/undefined handling, race conditions
- **Security** - Input validation, injection risks, auth issues, exposed secrets
- **Correctness** - Does it do what it's supposed to? Edge cases handled?
- **Clarity** - Confusing logic, misleading names, missing context

Avoid nitpicking:

- Style preferences already enforced by linters
- Minor naming quibbles that don't affect understanding
- "I would have done it differently" without clear benefit

## Output Format

For each issue found:

```
**[Severity]** Brief description
`file:line` - What's wrong and why it matters
→ Suggested fix (if not obvious)
```

Severity levels: `Critical` | `High` | `Medium` | `Low`

## Summary

End with:

- Count of issues by severity
- Overall assessment (approve, request changes, or needs discussion)
- Top priorities to address
