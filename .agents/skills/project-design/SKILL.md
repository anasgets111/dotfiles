---
name: codebase-design
description: Shared vocabulary for designing deep modules. Enforce Systems Thinking, leverage, locality, and YAGNI.
disable-model-invocation: true
---

# Codebase Design

Design **deep modules**: massive implementation hidden behind a minimal interface, placed at a clean seam, fully testable. Optimize for leverage (caller efficiency) and locality (maintainer efficiency).

## Architectural Glossary

Use these exact terms. Do not substitute with "component," "service," "API," or "boundary."

| Term | Strict Definition |
| :--- | :--- |
| **Module** | Anything with an interface and implementation (function, class, package). |
| **Interface** | Everything a caller must know: type signature, invariants, ordering, errors, config. |
| **Implementation** | The internal body of code hiding behind the interface. |
| **Depth** | Leverage at the interface. High depth = minimal interface + massive implementation. |
| **Seam** | The location where a module's interface lives (where behavior can be swapped). |
| **Adapter** | The concrete logic that satisfies an interface at a seam (e.g., the `niri` and `hyprland` rows in `lib/compositor.lua`). |
| **Leverage** | Caller benefit: capabilities gained per unit of interface learned. |
| **Locality** | Maintainer benefit: bugs, logic, and tests concentrate in one place. Fix once. |

## Deep vs. Shallow

**Deep module** = small interface + deep implementation. High leverage.

```text
┌─────────────────────┐
│   Small Interface   │ ← Minimal functions/params (e.g., `compositor.detach(verb)`)
├─────────────────────┤
│                     │
│ Deep Implementation │ ← Per-compositor argv, unhydrated state, logging hidden
│                     │
└─────────────────────┘
```

**Shallow module** = large interface + thin implementation. A useless pass-through. Delete it.

```text
┌─────────────────────────────────┐
│        Large Interface          │ ← Caller passes cmd, args, compositor
├─────────────────────────────────┤
│       Thin Implementation       │ ← Just calls `process.detach`
└─────────────────────────────────┘
```

## Lazy Senior Dev Principles

*   **The Deletion Test (YAGNI):** If you delete a module and complexity vanishes, it was a useless pass-through. If complexity explodes across N callers, it was earning its keep.
*   **Depth belongs to the interface.** A deep module can use small, swappable local functions. Do not expose them.
*   **The interface is the test surface.** If you have to test past the interface (mocking internal state), the module is the wrong shape.
*   **Seam Discipline:** One adapter = a hypothetical seam (YAGNI violation). Two adapters = a real seam (e.g., niri and Hyprland commands). Do not introduce a seam unless it varies.

## Testability via Interface

**1. Accept dependencies, do not reach for them.**
```lua
-- Testable
local function layout_code(keyboard)
    return keyboard and keyboard.active_layout:sub(1, 2):upper() or ""
end

-- Garbage (Hard to test, hidden coupling to the live capability)
local function layout_code()
    local keyboard = mantle.keyboard:get()
    return keyboard and keyboard.active_layout:sub(1, 2):upper() or ""
end
```

**2. Return results, avoid hidden state mutations.**
```lua
-- Testable
local function next_file(files, current)
    for i, file in ipairs(files) do
        if file == current then return files[i % #files + 1] end
    end
    return files[1]
end

-- Garbage (Hidden side effects)
local function advance_wallpaper(files, output)
    local wallpapers = store.wallpapers:get()
    wallpapers[output] = { path = files[1] }
    store:set("wallpapers", wallpapers)
end
```

## Going Deeper
*   **Deepening a module:** Call `deepening`.
*   **Alternative interface architectures:** Call `design-it-twice`.
