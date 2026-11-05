# QA report — issue #9 · onboard: rename single-value `--sets` to `--set`

PR #13 · branch `issue-9-onboard-rename-single-value-sets-to-set` · head `620e9586` (+ QA commit)
Evidence: `docs/super-board/runs/issue-9-qa-v1/`

## Test plan (one observable test per AC)

Onboard's parameters are agent-parsed from `skills/super-board/references/onboard.md` (no
`.py`/`.sh` logic parses them), so AC 1–3 are observable as the documented contract those
surfaces carry; AC 4 is the surface sweep; AC 5 is the offline suite.

| AC | Observable test | Result |
|---|---|---|
| 1 — `--set=pstack` pre-answers step 2 as `--sets=pstack` did | `tests/test-onboard-set-flag.sh` check 1: parameters section documents `--set=<mattpocock\|pstack\|agent-skills\|custom>` pre-answering steps 2–3 and step 2 reads "the `--set` parameter if given (either spelling)"; `tests/test-fork-wizard.sh` checks 2–3 tie the `--set` list to registry.json sets | ✅ |
| 2 — `--sets=pstack` still works as documented deprecated alias | check 2: `--sets=<one value>` present + "deprecated alias of `--set`"; fork-wizard 2b greps `deprecated alias` | ✅ |
| 3 — `--sets=pstack,mattpocock` halts naming install.sh's list semantics | check 3: rejection line "onboard takes one skill set — install.sh's --sets takes a comma list. Re-run with one set, e.g. --set=pstack." + error-recovery table row `| 2 \| Comma list at --set/--sets \|` | ✅ |
| 4 — all docs surfaces use `--set` for onboard, `--sets` only for the installer list | checks 4–8: no `onboard --sets=` invocation in onboard.md/README; setup.py `fix --sets=` kept; get.sh header (`--set=<one set>` + `(deprecated alias: --sets)` + `--sets=a,b` passthrough); install.sh header (`--set=<one set> (deprecated alias --sets)`) with `--sets=<list>` usage + `--sets=*) SETS=` parsing kept; README onboard line `--set=pstack` + split explanation + install.sh flag list; `.agents` mirror byte-identical to `skills/` | ✅ |
| 5 — `bash tests/run-safety.sh` passes | full suite run on the branch: exit 0, `PASS: 56 safety suites` (55 at build + this QA suite) | ✅ |

## Commands run

- `bash tests/test-onboard-set-flag.sh` → `PASS: test-onboard-set-flag.sh (8 checks)`, exit 0
  (`test-onboard-set-flag.log`)
- `bash tests/run-safety.sh` → exit 0, `PASS: 56 safety suites` (`run-safety.log`)
- Red-first: the new suite run against `main` (`d6d682c`) fails at check 1
  ("onboard.md must document --set with every set name") — it bites on the pre-fix state.

## Test-gap check (run.md → 4b)

- **High** — AC 4's get.sh header, install.sh header and README onboard line were pinned by no
  suite (`test-fork-wizard.sh` covers onboard.md/registry/schema/setup.py only). Exactly the drift
  this ticket fixes could revert silently. → closed by `tests/test-onboard-set-flag.sh` (red-first
  verified against `main`).
- **Medium** — AC 3's error-recovery table row and AC 1's "(either spelling)" equivalence were
  unpinned. → closed by the same suite (checks 1, 3).
- **Medium** — `.agents/skills/super-board/references/onboard.md` mirror agreement not asserted for
  this file. → closed by check 8 (`cmp`). Global sync stays with `test-agents-skills-sync.sh`.

## Not done

- No screenshots: all ACs are docs/CLI-level, no UI surface.
- AC 1–3 semantics are exercised as the documented agent contract; the wizard itself is an
  interactive session and cannot be driven end-to-end offline.
