# QA v1 report — issue #10 (docs: end-to-end usage guideline)

PR #15 · branch `issue-10-end-to-end-usage-guideline` · builder head `10aaf96` · verified 2026-11-01 (Tester, workflow backend)

Method: one observable check per AC, run in `.claude/worktrees/issue-10-qa/` on the PR head. Docs-only card — no screenshots (non-visual ACs); commands and file:line are the evidence.

## AC1 — docs/GUIDE.md exists, covers prerequisites → troubleshooting in the ticket's order ✅

- `ls -la docs/GUIDE.md` → 16,659 bytes, 281 lines.
- `grep -n '^## ' docs/GUIDE.md` → 11 headings, exactly the ticket's order:
  `1. Prerequisites` (11) · `2. Install` (26) · `3. Onboard` (59) · `4. Prepare tickets` (95) · `5. Drain the board` (108) · `6. Card lifecycle` (142) · `7. Human gates 🙋` (171) · `8. Halts and recovery` (200) · `9. Skill sets` (227) · `10. Troubleshooting` (253) · `11. Where things live` (265).

## AC2 — every command copy-pasteable and verified against current scripts/flags ✅

Commands executed this session:

| Guide command | Result |
|---|---|
| `git --version` / `python3 --version` / `node --version` / `jq --version` | git 2.47.1 · Python 3.9.6 · v22.14.0 · jq-1.7.1-apple |
| `gh auth status` | logged in, token carries `project` + `repo` scopes (guide's refresh line matches run.md preconditions) |
| `pgrep -f 'claude -p .*super-board run'` | zero matches, as §10 says |
| `gh issue view 10 -R vuquangkhtn/suber-super-board --json number -q .number` | `10` — the §10 `-R` footgun advice works |
| `python3 .claude/bin/super-board-status.py` | renders read-only snapshot; shows #10 in QA — matches §5 description |

Flags verified in the scripts: `install.sh:8` usage `[--no-hooks] [--protect-main] [--sets=...] [--hosts=...] [target]`; `--hosts` values `claude,codex,opencode,copilot,zcode,other` and unknown host → `exit 64` (`install.sh:25,70`); `get.sh:8-14` `--target`, `--ref`, `--no-helper-skills`, pass-through of `--sets`/`--hosts`.

Cited file:line spot-checked against current source:

| Guide cite | Found |
|---|---|
| `get.sh:63-68` — hard requirements curl+tar (or git) + python3 | ✅ die lines for fetch tool and python3 in that range |
| `get.sh:70-81` — grouped ✓/✗ check of `curl tar git python3 gh jq node` | ✅ loop `for t in curl tar git python3 gh jq node` |
| `install.sh:12-13` — installer asks nothing; onboard asks | ✅ "The installer asks nothing: super-board onboard asks the questions" |
| `onboard.md:9-18` — comma-list halt `🛑 onboard takes one skill set…` | ✅ onboard.md:12 + table row :517 |
| `scripts/super-board-merge-gate.sh:68-92` — exit codes 0/2/3/4/5/6/7/8/79 | ✅ comment block :71-92; all nine exits match the guide's plain-words table |
| `scripts/super-board-setup.py:14-19` — `sets <set\|custom> [--steps FILE]` | ✅ usage text in that range |
| onboard.md anchors "Design rules" / "Fix, don't ask" / "Resume" / "Re-run on a finished setup" | ✅ lines 20 / 28 / 92 / 108 |
| `references/rate-limit-etiquette.md` — board read ~101–203 pts, 3 cards ~2,850 of 5,000 | ✅ :11-17 |
| `run-workflow.md` wave loop step 6 — "Never report a card as done that is not on the base branch" | ✅ :246-255; guide's wave-report example is verbatim from step 6 |
| run.md anti-zombie addendum | ✅ "### Anti-zombie addendum (added 2026-05-22 after #381 worker storm)" |
| `.claude/bin/super-board-{status.py,stop.sh}` · `--resume` flag on super-board-github-read.py | ✅ exist (dogfood install; `.claude/bin/` is gitignored — sources tracked in `scripts/`, same scripts) · `--resume` at github-read.py:325 |
| `skill-sets/registry.json` — mattpocock 27 / pstack 66 / agent-skills 25 | ✅ registry descriptions say 27 / 66 / 25 |
| `references/{lint,stop,block-template,rate-limit-etiquette}.md` | ✅ all exist |

## AC3 — onboard `--set` vs install.sh `--sets` consistent with #9 ✅

PR #13 (issue #9) landed the rename. Four surfaces agree:

- `skills/super-board/references/onboard.md:11-16` — onboard's parameter is `--set=<one set>`; `--sets` works only as deprecated alias; comma list at either spelling halts with the `🛑` message.
- `install.sh:12-14` — "Onboard's own parameter is --set=<one set> (deprecated alias --sets) — distinct from this script's comma-list --sets".
- `get.sh:12-14` — same distinction, `--sets` passed through to install.sh.
- `docs/GUIDE.md:55-57` (§2) and `:83-88` (§3) state exactly this, quote the halt message verbatim.

## AC4 — README links the guide in one line, no duplicated content ✅

`git diff origin/main...HEAD --numstat -- README.md` → 2 insertions, 0 deletions: one blank line + one content line ("**New here?** [docs/GUIDE.md](docs/GUIDE.md) is the end-to-end usage guideline: …"). Pointer only — no guide content restated.

## AC5 — core guide stays scannable ✅

281 lines / 11 sections; 8 markdown tables covering 71 rows; sections 12–36 lines each (avg ≈24). Deep contracts pushed to pointers: intro (`docs/GUIDE.md:4-6`) states the policy, per-section cites name `onboard.md`, `lint.md`, `stop.md`, `block-template.md`, `rate-limit-etiquette.md`, `run.md`, and §11's table lists the references dir.

## AC6 — bash tests/run-safety.sh passes ✅

Ran `bash tests/run-safety.sh` in the worktree on the PR head: exit 0, `PASS: 58 safety suites` (incl. 8-test unittest group OK, test_writing_format.py 14/14).

## Test gaps (not written)

- Medium: no automated drift guard that re-verifies GUIDE.md's backticked commands/flags when the scripts change — the guide mitigates by pointing at per-verb references instead of restating contracts.
- Low: §10's quota example numbers (~203/board read) are board-size-dependent; acceptable because the row links rate-limit-etiquette.md for the method.

Verdict: **PASS** — 6/6 AC verified, no High gaps, nothing needs app code changed.
