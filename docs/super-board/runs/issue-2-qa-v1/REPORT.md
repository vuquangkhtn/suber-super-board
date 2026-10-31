# QA report — issue #2 · v1 · `b3d6e17`

Tester pass for PR #8 (`issue-2-switch-skill-set-after-onboard`), card `qa` (skips Building).
Target: repo CLI feature — non-visual, so no screenshots are captured (stated omission;
evidence is command logs in this folder).

## AC ledger

| AC | Observable test | Result |
|---|---|---|
| 1 — round trip updates record, skill-map.json, AGENTS.md block each time | `bash tests/test-sets.sh` (asserts all three artifacts after each leg) + QA's own independent round trip on a fresh temp target | ✅ PASS |
| 2 — added/removed lists reported | same run: `added`/`removed` asserted both directions; QA's independent run captured the real lists | ✅ PASS |
| 3 — `bash tests/run-safety.sh` stays green | `bash tests/run-safety.sh` | ✅ PASS — 53 safety suites, exit 0 |

## Commands run (in `.claude/worktrees/issue-2-qa` at `b3d6e17789a1f578a66095006e27da7f0219f5c9`)

1. `bash tests/test-sets.sh` → `PASS: sets switch (round trip, diff, nested, custom, dry-run, refusals, config resolution)`, exit 0 — `test-sets.log`
2. `bash tests/run-safety.sh` → `PASS: 53 safety suites`, exit 0, `tests/test-sets.sh` included via the `tests/test-*.sh` glob — `run-safety.log`
3. Independent round trip (QA's own pass, not the Builder's harness): seed mattpocock on a temp target → `sets pstack` → `sets mattpocock`, inspecting the raw artifacts after each leg — `independent-roundtrip.log`
   - after leg 1: record sets `["pstack"]` · skill-map `.named == "pstack"` · AGENTS.md `Skill set: **pstack**` · `grilling` gone from disk · `how` present · added 63 / removed 25, shared `tdd`/`teach` in neither list (re-owned)
   - after leg 2: perfect mirror — record `["mattpocock"]` · map + AGENTS.md back to mattpocock · `grilling` back · `how` gone

## Test-gap check

- AC ledger: every AC maps to an asserting shell test at e2e-ish rung (real temp target, real install.sh). No AC without a test.
- Edge cases hunted: switch-to-same-set idempotency (kept=chosen, dropped=[] path), two-installed-sets partial drop, install.sh failure after the record prune (partial state, recoverable by re-running the switch) — all **Medium**, none in auth/money/security/data-loss.
- Test the tests: assertions run under `set -euo pipefail` with explicit `fail` on each check; no test asserts on its own mock (install.sh and setup.py are the real scripts from the checkout).

### Test gaps (not written — Medium, never block)

1. `sets <same-set>` idempotent re-switch has no dedicated test.
2. Dropping one of two installed sets (`removed_now` minus kept-set skills) is not exercised with a two-set record outside custom mode.
3. install.sh failing mid-switch (after the record prune) leaves the record pruned with the new set uninstalled — accepted, re-running the switch repairs it; no test pins it.

## Verdict

PASS — all 3 ACs verified. Card moves QA → Review.
