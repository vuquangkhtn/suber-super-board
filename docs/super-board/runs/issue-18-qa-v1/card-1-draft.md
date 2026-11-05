## Problem

- **Where:** the HTML page `/visual` generates, `<body>` theme styles
  - a. page renders light theme only; no dark palette exists
  - b. users reading the page in a dark room get a blinding white canvas
- **Who:** anyone opening a branch-recap / codebase-map page the visual skill emits
- **What happened:** no dark theme tokens, so dark mode has nothing to build on

## Context

Design settled by grilling (2026-11-05). Request: "Add a dark-mode toggle to the HTML
page the /visual skill generates — a top-right button that flips light/dark and
remembers the choice in localStorage." Slice 1 lays the token foundation the toggle
(slice 2) flips; system-preference default ships value before any JS exists.

## Fix

1. Define `--bg`, `--fg`, `--accent`, `--code-bg` CSS custom properties on `:root`
   (light values) and `@media (prefers-color-scheme: dark)` overrides.
2. Swap every hard-coded color in the generated page's inline `<style>` for the tokens.
3. `[data-theme="dark"]` selector mirrors the dark token values (slice 2 toggles it).

## Acceptance Criteria

- [ ] Generated page contains `:root` token block and a dark override for each token
- [ ] With OS set to dark, the page renders the dark palette with zero JS
- [ ] `grep` of the emitted HTML finds no hard-coded `#f`/`#fff` background left

## Risk

🟢 **Low** · generated artifact only; visual skill output, no runtime code.

## Blocked by

- None.
