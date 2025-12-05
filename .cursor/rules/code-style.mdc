---
description: Code style conventions and best practices
globs: ["**/*"]
alwaysApply: true
---

# Code Style Conventions

## General Principles

- **Prefer concise code** - Always use the least amount of code possible
- **Avoid over-engineering** - Only make changes that are directly requested or clearly necessary
- **Keep solutions simple and focused** - Don't add features, refactor code, or make "improvements" beyond what was asked

## QML/JavaScript Style

- Use arrow functions, ternary operators, and property bindings over imperative code
- **Always** use proper `const` and `let` declarations in JavaScript blocks
- Proper local and function naming, no single-letter names
- Avoid verbose patterns when simpler alternatives exist

## Error Handling

- Don't add error handling, fallbacks, or validation for scenarios that can't happen
- Trust internal code and framework guarantees
- Only validate at system boundaries (user input, external APIs)
- Don't use backwards-compatibility shims when you can just change the code

## Abstraction Rules

- Don't create helpers, utilities, or abstractions for one-time operations
- Don't design for hypothetical future requirements
- The right amount of complexity is the minimum needed for the current task
- Reuse existing abstractions where possible and follow the DRY principle

## Quality Checks

- **No unit tests** - Ensure no lint/error problems exist before committing
- Use `get_errors` tool to check for QML syntax/type errors
- Quickshell auto-fills `.qmlls.ini` with proper paths on launch (no `qmldir` needed)

## Secrets Management

Secrets stored in `.local_secrets/` (gitignored). Reference in configs:

```qml
readonly property string apiKey: Quickshell.env("SECRET_API_KEY") || ""
```
