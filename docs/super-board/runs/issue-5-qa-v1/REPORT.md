# QA report — issue #5 · PR #14 · v1

Card: `feat: sync a vendored skill-set from its original GitHub` · head `b4a987b`
Tester: super-board workflow Tester lane · date 2026-10-31 · verdict **PASS (3/3 AC)**

## Test plan (one observable test per AC)

| AC | Test | Result |
|---|---|---|
| 1 — `--dry-run` prints changes, writes nothing | Real shipped set: dry-run of `pstack` `190fc9a0… → 5851c89…` in a temp clone at `b4a987b`; plan printed (pin move + 9 updated skills); whole-clone `git status` byte-identical before/after. Plus `tests/test-skill-set-sync-qa.sh` check 1 (fixture, byte-compare) and fixed main-suite check 6 | ✅ |
| 2 — real sync in a temp clone updates store/registry/UPSTREAM.md and passes test-registry + run-safety | Real upstream (`https://github.com/michael-denyer/pstack-claude`), temp clone, **no `--no-validate`**: exit 0, registry `pinned_ref` → `5851c89…`, UPSTREAM.md row 16 rewritten, 9 skills refreshed in `.agents/skills/` through unchanged set symlinks, 1 new upstream file carried in; post-sync `bash tests/run-safety.sh` → exit 0, `PASS: 56 safety suites`, `PASS: test-registry.sh` | ✅ |
| 3 — removed upstream skills flagged against registry mappings, never silently deleted | Builder suite checks 1/3/4/6/7 (anytime-mapped removal: flagged, kept, exit 3, flag persists on re-sync). New QA checks 2–3: **steps**-mapped removal (`beta — registry: build`) flagged + kept + mapping untouched; carried `NOTICE.md` dropped upstream flagged + kept | ✅ |

## Commands run (on head `b4a987b`)

```
bash tests/test-skill-set-sync.sh                 → PASS: skill-set-sync (8 checks), exit 0
bash tests/run-safety.sh                          → PASS: 56 safety suites, exit 0   (before QA additions)
bash tests/run-safety.sh                          → PASS: 57 safety suites, exit 0   (after QA additions)
real pstack dry-run + sync in /tmp/qa-pack-5b     → dry-run exit 0, write-free; sync exit 0; post-sync suite PASS
```

## Test-gap ledger (super-qa → "Test-gap check")

| AC | Builder coverage | Gap found | Acted |
|---|---|---|---|
| 1 | plan lines asserted (main checks 1, 6); **"without writing" never asserted** — check 6 computed a checksum (`test-skill-set-sync.sh:243` old) and never compared it | High | new QA check 1 (byte-compare, layout A) + fixed main check 6 (before/compare, layout B); red-proofed (M1b) |
| 2 | fixture syncs assert store/registry/UPSTREAM effects (checks 3, 5, 7); run-safety via a **test double** in a fixture pack (check 5) | Medium | closed manually: real pstack sync with real full validation in a temp clone (`real-sync-pstack-*.txt`) |
| 3 | anytime-mapped removal flagged/kept (checks 1, 3, 4, 6, 7) | High-ish: steps-mapped removal untested; `carried_gone` path (`super-board-skill-set-sync.py:271,296-299`) never exercised | new QA checks 2–3; red-proofed (M2) |

Edge cases checked: pin-only sync (new sha, identical tree — QA check 4: pins move, nothing copied), bad `--ref` (exit 2, nothing written — QA check 5), unmapped removal (n/a — `test-registry.sh:47-49` forbids unmapped on-disk skills in a valid registry), volume (67-skill real set), real clone from https upstream. Noted, not blocking: `rewrite_upstream_row` rewrites *every* 7–40-hex run in a pin row (`super-board-skill-set-sync.py:183`), so a row embedding a second sha would be mangled — no current row has one.

## Files added/changed by QA (test-only, no app-code change)

- `tests/test-skill-set-sync-qa.sh` (new, 5 checks, auto-discovered by `tests/run-safety.sh:12`)
- `tests/test-skill-set-sync.sh` — check 6: the checksum is now captured before the dry-run and compared after (was computed and discarded)

## Evidence files

- `run-safety.log` — full 57-suite run on the branch
- `real-sync-pstack-dryrun.txt` / `real-sync-pstack-run.txt` / `real-sync-pstack-post-suite.txt` — the real-upstream end-to-end run
- `red-proof.txt` — mutation transcript for the new assertions

Non-visual ACs (CLI/shell) → no screenshots captured, per run.md "Screenshot embed format".
