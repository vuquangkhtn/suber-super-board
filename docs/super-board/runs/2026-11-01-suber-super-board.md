# Run manifest — 2026-11-01 · suber-super-board

Config `.claude/super-board/configs/suber-super-board.json` (workflow backend, human merges,
base `main`). Check-in run: no active wave found (all prior dwfruns completed; no legacy or
codex processes). Preconditions green — wave script loads clean under
`node --experimental-strip-types` (JS-mode `node --check` no longer applies: the body is TS),
worktrees clean, no halt marker, rate guard OK, usage guard exit 3 (blind: no status-line
usage snapshot recorded). Backlog and Ready empty — nothing to promote.

Planner: `cards 0 · sweep 0 · resume 0 · refreshApproval 0 · flag 0 · stranded 0`.

**Run end**: nothing dispatchable — 5 cards sit in Blocked only → report and stop.
#9 (PR #13) and #5 (PR #14) wait on a human merge or `done` on the issue;
#10 (behind 9), #11 (behind 10), #4 (behind 5) free automatically when those close.
The bare `done` on #4 (2026-10-31 08:51Z) is display-only — no pinned 🙋 request there.
