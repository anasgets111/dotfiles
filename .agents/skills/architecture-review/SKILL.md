---
name: architecture-review
description: Scan codebase for shallow modules. Present deep refactoring targets in a visual HTML report. YAGNI-first.
disable-model-invocation: true
---

# Architecture Review

Surface architectural friction. Propose **deepening opportunities** (converting shallow modules into deep ones). Optimize for testability and locality.

**Strict Vocabulary Definition:** 
Always use: **module**, **interface**, **depth**, **seam**, **adapter**, **leverage**, **locality**. 
Never use: component, service, API, boundary. Use the engine's `CONTEXT.md` for domain terminology and respect its ADRs (`docs/decisions.md` in `/mnt/Work/0Coding/1Rust/mantle`).

## Process

### 1. Explore (YAGNI)

Do not review stable code. Deepening only pays off if the code changes. 

- **Target Hotspots:** Run `git log --oneline` to locate frequently touched files.
- **Read Context:** Parse `AGENTS.md`, plus the engine's `CONTEXT.md`.
- **Audit for Friction (Spawn Sub-Agent):**
  - Locate **shallow modules** (interface complexity ≈ implementation complexity).
  - Locate leaked abstractions (e.g., capability payload parsing or `process.run` calls bleeding into `components/` widgets).
  - Identify pure functions lacking **locality** (extracted for tests, but real bugs hide in the untested callers).
- **The Deletion Test:** Would deleting this module concentrate complexity, or just move it? If it concentrates, it is shallow. Target it.

### 2. Generate HTML Report

Write a self-contained HTML file to the OS temp directory. Do not pollute the repo.

- **Path:** `/tmp/architecture-review-<timestamp>.html` (Fallback: `$TMPDIR`).
- **Open:** Execute `xdg-open <path>`.
- **Format:** Refer to `HTML-REPORT.md` for the strict Tailwind/Mermaid visual spec.
- **Candidate Data:** Files, Problem, Solution, Benefits (using strict vocabulary), Recommendation Strength (`Strong`, `Worth exploring`, `Speculative`), Before/After Diagram.
- **ADR Conflicts:** Only surface a conflicting candidate if the friction justifies reopening the ADR. Mark it explicitly.

*Do not propose new interfaces yet. Output the file, open it, and ask: "Which of these do we explore?"*

### 3. The Grilling Loop

Once the user selects a candidate, execute `grill` to stress-test the architectural decision tree.

**Inline Side Effects:**
- **Missing Domain Term?** Tell the user; `CONTEXT.md` lives in the engine repo.
- **User Rejects Candidate?** Ask to record the reason as a comment at the module to prevent future re-suggestions. (Skip if the reason is ephemeral).
- **Alternative Interfaces?** Spawn parallel sub-agents to design it twice using the codebase-design principles.