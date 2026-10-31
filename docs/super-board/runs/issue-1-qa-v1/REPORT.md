# QA v1 — issue #1 · PR #6 · head `e83bc18` + evidence commit

Ran: `bash tests/run-safety.sh` (worktree `.claude/worktrees/issue-1-qa`) → **exit 0 · PASS: 52 safety suites**.
Raw output kept locally as `run-safety.log` (ignored by `.gitignore:35` — this folder carries summaries only).

## AC1 — ≥1 new or extended suite per UPSTREAM.md fork delta ✅

| UPSTREAM.md delta | New/extended suite (all green in the 52-suite run) |
|---|---|
| `get.sh` fork default, npx step gone | `tests/test-get.sh` case 10 (`PASS: test-get.sh (10 cases)`) |
| `install.sh` --sets/--hosts | `tests/test-install.sh` scenarios 13–15 (`PASS: test-install.sh (20 scenarios)`) |
| `super-board-setup.py` fix passthrough + check report | `tests/test-setup.sh` 1c, 1d (`PASS: test-setup.sh (12 scenarios)`) |
| `super-board-agents-md.py` skill-map | `tests/test-agents-md.sh` scenarios 11–15 (`PASS: test-agents-md.sh (15 scenarios)`) |
| onboard.md 10-step wizard + params | `tests/test-fork-wizard.sh` checks 1–3, 6 (`PASS: test-fork-wizard.sh (6 checks)`) — new suite |
| config-schema.json fork keys | `tests/test-fork-wizard.sh` check 5 |
| `skill-sets/` + registry + symlink layout | `tests/test-registry.sh` symlink pass (`PASS: test-registry.sh`) |

## AC2 — no existing suite skipped or weakened ✅

- `git diff origin/main...HEAD` = 6 files, **314 insertions / 3 deletions**; the only deleted lines are the
  three scenario-count PASS echoes (test-agents-md 10→15, test-get 9→10, test-install 17→20).
- `tests/run-safety.sh` auto-discovers via glob `tests/test-*.sh tests/test_*.py` — no suite list to skip from;
  all 52 discovered suites ran, none failed (gate exits 1 on any failure).

## Test gaps (not written)

- **Medium** — nothing asserts the per-suite scenario-count echoes, so a future scenario deletion (with its
  PASS count updated) would not be caught. A count-guard suite would close it.
- **Medium** — onboard.md's wizard documents `fix --sets=… --hosts=…` (prefix form) but `flag()` at
  `scripts/super-board-setup.py:945` only parses the separate-argument form at this base; the suite covers the
  working form (test-setup 1d, with the in-suite comment). Needs app code — fix exists unpushed on local main
  (`94951ba`). Not testable from this branch; not a regression of this PR.
- **Low** — the new `tests/test-registry.sh` symlink pass is vacuous if `skill-sets/` holds zero symlinks;
  the pre-existing iterdir checks (missing set dirs / missing SKILL.md) would fire first in every realistic
  layout loss, and fresh-install layouts stay covered by test-install/test-get.
- **n/a** — delta-7 refinement (physical `.agents/skills` store + `agents-skills-sync.sh` + its guard suite)
  lives only in unpushed local-main commits (`cb2e90f..main`); a branch off origin/main cannot test it.
