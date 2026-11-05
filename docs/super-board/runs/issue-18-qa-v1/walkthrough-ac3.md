# AC3 live walkthrough — `/super-plan` with an already-clear request

Issue #18 · PR #21 · head `4aad5f1` · QA v1 · 2026-11-05
Executed in worktree `.claude/worktrees/issue-18-qa` (the branch under test).

**Method.** The Tester acted as the super-plan conductor, following
`skills/super-plan/SKILL.md` phase by phase. Sample request (already-clear, unrelated
to the board):

> "Add a dark-mode toggle to the HTML page the /visual skill generates — a top-right
> button that flips light/dark and remembers the choice in localStorage."

A `gh` shim (`/tmp/super-plan-qa-shim/bin/gh`) intercepted exactly three write
subcommands (`issue create`, `project item-add`, `project item-edit`), recorded their
full argv to `gh-shim-record.txt`, and faked their success; every other call (rate-limit
guard, `project field-list` reads) was delegated to the real `gh`. **No real issue or
project item was created** — the fake ids (#9001, `ITEM-ID-FAKE`) exist nowhere on
GitHub. Real ids used for fidelity, resolved read-only before the walkthrough:

- project `Suber-super-board board` = `PVT_kwHOAVKc0M4BpYT4` (config project block: owner `vuquangkhtn`, number 2)
- Status field = `PVTSSF_lAHOAVKc0M4BpYT4zhn0ONY`; Backlog option = `40ee6325`, Ready option = `81452fd7`

## Phase 1 — Orient (SKILL.md:49-60)

1. Read the request; read `.claude/super-board/skill-map.json` → steps `plan`
   (pstack: how, why, figure-it-out, show-me-your-work) and `design`
   (pstack: architect, arena, interrogate). Map present → routing from the map, nothing
   hardcoded. (The map file is onboard-generated and untracked, so the real copy was
   placed in the worktree for the run; the skill's map-missing degrade path is a
   separate behaviour, not exercised here.)
2. Sharpness: request states **what** (toggle button flipping light/dark), **for whom**
   (readers of generated visual pages), **done** (flip works, choice persists in
   localStorage) → already sharp → **skip to Phase 5**, no interviews. Opt-in honoured:
   no ceremony for a clear request.
3. Two small slices — nowhere near a multi-session effort → no wayfinder handoff.

## Phase 5 — Draft cards (SKILL.md:62-77)

Split into vertical slices, each one PR well under 400 changed lines; board format
(`## Problem` · `## Context` · `## Fix` · `## Acceptance Criteria` (2–5 checkable
`- [ ]`) · `## Risk` 🟢/🟡 · `## Blocked by`); titles ≤ 70 chars; suggested labels
`feature` (both); ordering: slice 2 depends on slice 1's tokens →
`## Blocked by: - #9001 — needs the slice-1 token block to flip.`

Full draft bodies as shown in-chat: `card-1-draft.md`, `card-2-draft.md` (in this
folder). Decision summary shown with them: skills consulted from the map (plan:
figure-it-out; design: architect), nothing stayed open, user owes only the approval.

## Phase 6 — Review + file (SKILL.md:79-101)

**Gate check (the HITL invariant, executed):** drafts + decision summary shown, no
approval given → `sb_gh_guard_check 200` ran (real, exit 0) and the shim record held
**0 lines** — nothing files without approval.

**Approval step:** no human is present in this headless QA run, so the approval
"approve both cards → Backlog" was **simulated** and is flagged as such here. With
approval granted, the filing block SKILL.md:86-93 was executed verbatim
(`source .claude/bin/super-board-gh-guard.sh; sb_gh_guard_check 200` → real, exit 0;
then per card: `gh issue create --label feature` → `gh project item-add` →
`gh project item-edit --single-select-option-id 40ee6325` (Backlog, the default — the
user did not say Ready)). Card bodies were passed via `--body-file` from throwaway
`/tmp` files — the never-list's "no edits outside throwaway prototype artifacts" held;
nothing was written into the repo during filing.

Full recorded argv: `gh-shim-record.txt` — 6 calls, exactly the SKILL.md block, in
order, per card.

**Ending (SKILL.md:99-101):** one line per filed card + the pointer line:

```
#9001 — 🎨 [feature] visual: dark theme tokens for generated page · Backlog · feature
#9002 — 🎨 [feature] visual: dark-mode toggle button with persistence · Backlog · feature
Next: /super-board run suber-super-board
```

## Walkthrough verdict — AC3

| AC3 requirement | Observed |
|---|---|
| already-clear request → drafts board-format cards | ✅ Phase 1 skipped interviews; Phase 5 produced both slices in board format |
| checkable ACs + suggested qa/bug/feature labels | ✅ every AC line is a test-assertable `- [ ]`; labels `feature` suggested per card |
| files to Backlog **only after** approval | ✅ gate held with 0 recorded writes pre-approval; filing ran only after the (simulated) approval |
| ends pointing at `/super-board run` | ✅ `Next: /super-board run suber-super-board` |

Caveat recorded honestly: the approval itself was simulated (HITL by definition needs a
human); the gate, the command sequence, the Backlog default and the ending are real,
executed behaviour. No real card was filed — the board is untouched.
