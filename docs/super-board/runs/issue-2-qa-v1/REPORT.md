# QA report — issue #2 · v1 · branch tip `9784523` (feature `b3d6e17`)

Tester pass for PR #8 (`issue-2-switch-skill-set-after-onboard`), label `feature`.
Target: repo CLI feature — non-visual, so no screenshots are captured (stated omission;
evidence is the command logs in this folder).

All commands below were run in this QA pass, in `.claude/worktrees/issue-2-qa`.

## AC ledger

| AC | Observable test | Result |
|---|---|---|
| 1 — round trip updates record, skill-map.json, AGENTS.md block each time | `bash tests/test-sets.sh` (asserts all three artifacts after each leg) + QA's own independent round trip on a fresh temp target | ✅ PASS |
| 2 — added/removed lists reported | same run: `added`/`removed` asserted both directions; QA's independent run captured the real lists | ✅ PASS |
| 3 — `bash tests/run-safety.sh` stays green | `bash tests/run-safety.sh` | ✅ PASS — 53 safety suites, gate line `PASS: 53 safety suites` (printed only on the zero-failure path, run-safety.sh:28-32) |

## Commands run and outputs

1. `bash tests/test-sets.sh` → `PASS: sets switch (round trip, diff, nested, custom, dry-run, refusals, config resolution)`, exit 0 — `test-sets.log`
2. `bash tests/run-safety.sh` → `PASS: 53 safety suites`, no `::error::` / `Failed suite` lines — `run-safety.log` (`tests/test-sets.sh` included via the `tests/test-*.sh` glob)
3. Independent round trip (QA's own pass, not the Builder's harness), seed `fix --no-helpers --sets mattpocock --hosts claude,zcode` on a temp target, raw artifacts inspected after every leg — `independent-roundtrip.log`:
   - leg 1 `sets pstack`: record `["pstack"]` · skill-map `.named == "pstack"` · config `{"mode":"named","named":"pstack"}` · AGENTS.md `Skill set: **pstack**` · `how` on disk · `grilling` gone · shared `tdd` kept · added 64 / removed 25
   - leg 2 `sets mattpocock`: mirror — record `["mattpocock"]` · map + config + AGENTS.md back to mattpocock · `grilling` back · `how` gone · added 25 / removed 64
   - note: bare `fix` does not write `skill-map.json` (the map writer runs from `sets`, super-board-setup.py:636-637) — map absence at seed is expected, not a defect; both legs wrote it.

## Test-gap check

- AC ledger: every AC maps to an asserting shell test at the integration rung (real temp target, real install.sh + setup.py from the checkout). No AC without a test.
- Edge cases hunted in `switch_sets` (super-board-setup.py:513-652): switch-to-same-set idempotency (kept-set path), two-installed-sets partial drop, install.sh failure after the record prune (partial state, recoverable by re-running the switch) — all **Medium**; nothing here touches auth/money/security/data-loss. Dry-run no-touch, nested `references/`, custom steps + skipped overlaps, refusals/exit codes and ambiguous-config resolution are already pinned by `tests/test-sets.sh:82-157`.
- Test the tests: suite runs under `set -euo pipefail` with explicit `fail` per check and `jq -e` assertions; no test asserts on its own mock.

### Test gaps (not written — Medium, never block)

1. `sets <same-set>` idempotent re-switch has no dedicated test.
2. Dropping one of two installed sets (not via custom mode) is not exercised.
3. install.sh failing mid-switch (after the record prune) leaves the record pruned with the new set uninstalled — accepted, re-running the switch repairs it; no test pins it.

## Verdict

PASS — all 3 ACs verified. Card moves QA → Review.
