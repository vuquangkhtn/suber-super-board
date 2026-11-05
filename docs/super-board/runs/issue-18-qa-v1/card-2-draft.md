## Problem

- **Where:** the HTML page `/visual` generates, top-right header area
  - a. no way to flip theme by hand; readers depend on OS preference only
  - b. choice does not persist across page loads
- **Who:** readers of any generated visual page
- **What happened:** the toggle requested in the design does not exist yet

## Context

Design settled by grilling (2026-11-05). Slice 2 of the dark-mode request: the button
the user asked for, flipping `[data-theme]` on `<html>`, persisting to
`localStorage["visual-theme"]`, defaulting to the slice-1 tokens.

## Fix

1. Add a top-right button (aria-pressed reflects current theme) that toggles
   `data-theme="dark"|"light"` on `<html>`.
2. Persist choice to `localStorage["visual-theme"]` on every flip; apply it before
   first paint via an inline head script (no flash).
3. Absent stored value → follow `prefers-color-scheme` (slice 1 behaviour).

## Acceptance Criteria

- [ ] Clicking the button flips the page between light and dark palettes
- [ ] Reloading after a flip renders the flipped theme (localStorage honoured)
- [ ] With no stored value and OS light, page renders light

## Risk

🟡 **Medium** · inline head script runs on every generated page — a syntax error
there blanks the artifact; covered by the AC reload check.

## Blocked by

- #9001 — needs the slice-1 token block to flip.
