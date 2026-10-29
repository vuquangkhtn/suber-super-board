## Problem
Date-only strings (`2026-09-01`) are parsed as UTC midnight and read back with local getters, so for users west of UTC the 1st of a month lands in the previous month. Two merged PRs hit it in 14 days.

## Context
- **Where:** date handling, `src/reports/monthly.ts`, `src/budgets/alerts.ts`
- Each PR fixed its own call site; there is no shared date-only helper, so the next caller repeats it.

## Evidence
- PR #21 · super-review R1 `src/reports/monthly.ts:42` · thread by eric (America/Vancouver)
- PR #24 · super-review R1 `src/budgets/alerts.ts:18` · coderabbitai thread

## Fix
Add `parseDateOnly()` / `monthKey()` in one module and route both call sites through it.

## Acceptance Criteria
- [ ] One helper parses date-only strings; `monthly.ts` and `alerts.ts` use it.
- [ ] A regression test runs the month bucketing under `TZ=America/Vancouver` and puts `2026-09-01` in September.

## Risk
🟡 **Medium** · touches two features' month logic.
