---
name: pr-preflight
description: Checklist to run before pushing a branch for a PR, opening a PR, or pushing review fixes, in any repo and language. Catches missed ticket requirements, untested entrypoints, silent failures and fixes landed in the wrong PR. Use before every `git push` of PR work and every `gh pr create`.
---

# PR preflight

Run this before pushing PR work or opening a PR. Go through every section. Write the results in a short table, one row per section (ok / fixed / gap, plus one line). Fix gaps before pushing, or name them in the PR body.

## 1. Ticket coverage
- Read the ticket or issue, plus any reviewer comments on the PR.
- List every requirement, acceptance point and **named example**. Find each one in the diff.
- A named example that the diff doesn't cover is a gap, even when the general rule seems to cover it.

## 2. Every way the code runs
List every way the changed code is started or loaded, then check each one:
- each process or entrypoint (API, workers, cron or queue consumers, CLIs, migrations, scripts);
- each runtime (container, host or bare-metal, serverless, CI, local dev, tests);
- each environment (local, test, staging, production);
- each copy of the boot sequence: test harnesses and integration helpers that replay `main.ts`. Put a guard inside the shared setup function so no path can skip it.

For each one, ask: does it still get the same config, env, files, permissions and startup order? Look hardest at anything the change moves or removes, such as a side effect, an implicit load or a default.

## 3. Silent failures
For each input, setting or dependency the change touches, list what happens when it is:
- missing;
- empty;
- whitespace only;
- malformed;
- a different type than expected (env values are strings: `'false'`, `'0'`, `'[]'`).

Run each case through the real parser or validator (a test or REPL). Never trust its name: `z.url()` accepts `javascript:`, and `get<boolean>()` converts nothing. Validation and runtime must read the same value: if you validate a cleaned copy, the runtime still reads the raw one.

"It throws" is fine. "It falls back to empty, a default or localhost and breaks later" is a gap: make it fail loudly or document it.

## 3b. Fail closed
For every auth guard, flag, path match or URL check: unset or empty means the secure default. Use allowlists and prefix matches, not blocklists or exact paths. Restrict URL schemes to http(s).

## 4. Behaviour parity
For a refactor, or any change to a check, guard or parser, compare every default, fallback, type and error message at each call site with the base branch. Run the §3 inputs on both. A check that gets weaker is a regression, even when a test asserts it.

## 5. Which PR does each fix belong to?
- For every fix made while building this branch, ask whether this PR caused the bug, or an earlier open PR or main did.
- If an earlier open PR caused it, land the fix there, or in both. A follow-up can be closed, and the original would then stay broken.

## 6. What the tests don't cover
- Name what the changed behaviour depends on that no test runs, for example a host-run process, prod-only config, a real provider, concurrency, or migrations on real data.
- Check each one by hand and show proof (a command and its output), or list it as untested in the PR body.
- Revert check: every new assertion must fail with the fix reverted. A test that passes only because of an existing bug, or that asserts worse behaviour than main, is a gap.
- Re-read the repo's test rules (e.g. `.agent/rules/coding-style.md`: one layer per behaviour) against the diff.

## 7. Checks
- Run the repo's own type-check, lint, format and tests for the touched areas.
- Use the repo's commands (scripts in package.json, Makefile, CI workflow), not generic ones.
- Rebase onto the latest `origin/main` just before pushing, then rerun. Don't stack on an unmerged PR when the repo squash-merges.
- Record the pass counts. Never push red.

## 8. Reviewer briefs
When delegating a review, give the reviewer the ticket text, the list from section 2 and the base branch, not just the diff.
