---
description: Refactor code with analysis, pattern application, and test verification
argument-hint: [optional: file/function/description]
---

# Refactor Code

Refactor the following: **$ARGUMENTS**

If no arguments were provided, use the currently selected code in the editor. If nothing is selected, use the currently open file.

## Approach

1. **Analyze** - Read the target code and understand its current behavior, dependencies, and test coverage
2. **Clarify** - If the refactoring goal is unclear, ask what specific improvement is desired:
   - Readability/naming improvements
   - Reduce complexity/extract functions
   - Eliminate duplication (DRY)
   - Improve type safety
   - Apply design patterns
   - Performance optimization
3. **Verify safety** - Check for existing tests. If coverage is insufficient, write tests first
4. **Refactor incrementally** - Make small, focused changes. Run tests after each change
5. **Validate** - Ensure behavior is preserved and improvements are achieved

## Principles

- Preserve external behavior while improving internal structure
- Prefer small, reversible changes over large rewrites
- Don't mix refactoring with feature changes or bug fixes

## Common Patterns

Apply when appropriate:

- **Extract Method/Function** - Break down long functions
- **Rename** - Improve clarity of names
- **Extract Class/Module** - Separate concerns
- **Remove Dead Code** - Delete unused code paths
- **Simplify Boolean Expressions** - Reduce nested conditionals
- **Introduce Parameter Object** - Group related parameters
- **Replace Magic Numbers/Strings** - Use named constants
