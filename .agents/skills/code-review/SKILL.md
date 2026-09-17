---
name: code-review
description: Two-axis code review (Standards vs. Spec). Parallel execution. Enforces YAGNI and systems-level discipline.
disable-model-invocation: true
---

# Code Review

Review the diff between `HEAD` and a target fixed point across two independent axes:
1.  **Standards:** Does it pass repo conventions and the Baseline Smells?
2.  **Spec:** Does it implement the exact requested feature without scope creep?

Run axes as parallel sub-agents to prevent context pollution. 

## 1. Pin the Target
*   Ask the user for the fixed point (`HEAD~5`, `main`, commit SHA) if not provided.
*   Capture the diff: `git diff <fixed-point>...HEAD`.
*   Capture the commits: `git log <fixed-point>..HEAD --oneline`.
*   **Fail Fast:** Verify the ref exists (`git rev-parse`) and the diff is not empty before spawning agents.

## 2. Identify the Spec
Locate the originating requirement in this order:
1.  Issue references in commits (`#123`, `Closes #45`, GitLab `!67`).
2.  User-provided path.
3.  Local spec file (`docs/`, `specs/`, or `.scratch/`).
*   *If missing, ask the user. If none exists, the Spec sub-agent aborts and reports "No spec available."*

## 3. Identify the Standards
Combine repo-specific docs (`AGENTS.md`) with the **Baseline Smells**. 
*Rule of Law:* Documented repo standards override the baseline. Skip anything enforced by automated tooling (e.g., the lua-language-server formatter and `--check` diagnostics).

### Baseline Smells
| Smell | Definition | The Fix |
| :--- | :--- | :--- |
| **Mysterious Name** | Unclear variable, function, or type name. | Rename it. If you cannot name it, the architecture is flawed. |
| **Duplicated Code** | Repeated logic shapes across the diff. | Extract to a `lib/` function or a `components/` widget. |
| **Feature Envy** | A function reading another module's data heavily. | Move the function into the `lib/` module that owns that data. |
| **Data Clumps** | The same 3-4 parameters travel together constantly. | Pass one table with named fields, typed with `---@class`. |
| **Primitive Obsession** | Strings/Ints acting as domain concepts. | Use a named constant table or a `---@alias` string union. |
| **Repeated Switches** | Identical `if`/`elseif` cascades on one value. | Replace with a lookup table keyed by that value (see `lib/compositor.lua`). |
| **Shotgun Surgery** | One logical change scatters edits across 10 files. | Consolidate the logic into a cohesive domain module. |
| **Divergent Change** | One file edits for 5 unrelated reasons. | Split the module. Enforce Single Responsibility. |
| **Speculative Generality** | Interfaces/hooks built for "future needs". | **YAGNI.** Delete it. Inline until a concrete requirement exists. |
| **Message Chains** | `a.b:c().d` navigation. | Hide the walk behind a single function on the root module. |
| **Middle Man** | A module/function that just delegates (Shallow Module). | Delete it. Call the target directly. |
| **Accidental Global** | An assignment missing `local`. | Declare it `local`. |
| **Frozen Signal** | `:get()` stored where a node property should stay live. | Pass the signal itself, or derive with `:map`. |

## 4. Spawn Parallel Sub-Agents

**Agent A: Standards Review**
*   **Input:** Diff, commit list, `CODING_STANDARDS.md`, Baseline Smells.
*   **Task:** Flag standards violations and code smells. Distinguish hard repo violations from baseline judgment calls. Ignore tooling-enforced formatting.
*   **Limit:** < 400 words.

**Agent B: Spec Review**
*   **Input:** Diff, commit list, Spec document.
*   **Task:** Flag missing requirements, incorrect implementations, and **scope creep** (code written that was not requested). Quote the spec directly.
*   **Limit:** < 400 words.

## 5. Aggregate Report
Output both reports verbatim under `## Standards` and `## Spec`. Do not merge them. A feature can flawlessly execute the spec while introducing architectural garbage (or vice versa). 

End with a brutal one-line summary:
> **Total Findings:** [X] Standards, [Y] Spec. **Critical Blockers:** [List the absolute worst offense in each category].
