# QA v1 — issue #11 install: default --sets to all vendored sets

Tested at PR head `7879663` (`issue-11-install-default-sets-all-vendored`), worktree
`.claude/worktrees/issue-11-qa/`. Non-visual change (installer + shell tests): no screenshots
captured — the observable evidence is the install record JSON and the suite logs in this folder.

## Per-AC results

| AC | Result | Proof |
|---|---|---|
| 1 · no `--sets` installs all three sets, record in order | ✅ | `tests/test-get.sh` case 1 (`tests/test-get.sh:43-52`): default install asserts `tdd`/`grilling` (mattpocock), `how` (pstack), `spec-driven-development` (agent-skills) on disk and record order `['mattpocock','pstack','agent-skills']` |
| 2 · tdd/teach resolve to mattpocock; pstack record shows skips | ✅ | `tests/test-get.sh:49-52`: mattpocock's record `installed` holds both, pstack's record `skipped` holds both; case 4 (`:80-81`) shows the skip output line |
| 3 · `--sets=mattpocock` installs exactly mattpocock | ✅ | `tests/test-get.sh:135-142` (new case 11): record == `['mattpocock']`, no pstack/agent-skills dirs |
| 4 · `--no-helper-skills` installs no sets, no record | ✅ | `tests/test-get.sh:59-63` (case 2): no `.agents/skills/tdd`, no `.agents/skill-sets.json` |
| 5 · README, get.sh, install.sh, onboard.md step 2 describe the new default | ✅ | New `tests/test-install-default-qa.sh` case 2: one load-bearing phrase per surface, both onboard.md mirrors (`skills/` + `.agents/skills/`) |
| 6 · test-get.sh assertions updated; `bash tests/run-safety.sh` passes | ✅ | `run-safety.log` in this folder: `PASS: 59 safety suites` (was 58; the QA file adds one), incl. `test-get.sh (11 cases)` |

## Test-gap check (issue-scoped)

Ledger: AC1 → test-get.sh:43-52 · AC2 → test-get.sh:49-52, :80-81 · AC3 → test-get.sh:135-142 ·
AC4 → test-get.sh:59-63 · AC5 → none (gap, closed below) · AC6 → run-safety.sh run.
Edge cases pinned by the new QA file; the two gaps below were the only High ones found.

High gaps closed by `tests/test-install-default-qa.sh` (red-first verified):

1. **Default vs registry order** (AC1): `install.sh` hardcodes `SETS="mattpocock,pstack,agent-skills"`
   (install.sh:46); the AC's "registry order" was unpinned. Case 1 asserts the default equals
   `skill-sets/registry.json`'s key order. Seen red against origin/main content:
   `install.sh default ['mattpocock'] != registry order ['mattpocock', 'pstack', 'agent-skills']`.
2. **Collision ownership is list-order, not a mattpocock hardcode** (AC2 mechanism): case 3 runs
   `--sets=pstack,mattpocock` end to end and asserts record order `['pstack','mattpocock']`,
   pstack owning `tdd`/`teach`, mattpocock's record showing both as skipped. Killed the
   `sorted()` mutant (forced mattpocock first): red
   `record order must follow the --sets list, got ['mattpocock', 'pstack']`, green after restore.
3. **Docs wording** (AC5): case 2 greps the five surfaces the AC names; seen red on origin/main
   content (the same run as gap 1 — the default assertion fires first).

Test gaps (not written, Medium/Low — non-blocking):
- `--sets=` (empty value) installs no sets silently — pre-existing behavior, unchanged by this PR.
- Record `steps`/`anytime` filtering for a three-set default install is not asserted per set
  (test-sets.sh covers the round-trip switch; test-setup.sh 1c now reads a three-set record).

## Commands run

- `bash tests/test-install-default-qa.sh` → `PASS: test-install-default-qa.sh (3 cases)`
- `bash tests/run-safety.sh` → exit 0, `PASS: 59 safety suites`
- Red A: `git checkout origin/main -- install.sh get.sh README.md skills/super-board/references/onboard.md .agents/skills/super-board/references/onboard.md` + QA test → FAIL (expected), restored
- Red B: `sorted()` mutant in install.sh:258 + QA test → FAIL (expected), restored
