# Run manifest — 2026-10-31 · suber-super-board

Config `.claude/super-board/configs/suber-super-board.json` (workflow backend, human merges,
base `main`). Board at start: #1 Done (human merged PR #6 `1180f23` — reconciled this run),
#2 Ready (swept from Blocked — blocker #1 closed), #3/#4/#5 Blocked.
Resume: `/super-board run suber-super-board`.

## Wave 3 (run dwfrun-24d3181b)

| # | Lanes run | Final status | Column | Detail |
|---|---|---|---|---|
| #2 | build:advanced → qa:halted | halted | QA | Build green, PR #8 (draft). QA PASS on all 3 ACs (`tests/test-sets.sh` PASS; `run-safety.sh` 53/53; round trip verified), evidence pushed `9784523`. Exit 79 halt: required read `repos/{owner}/{repo}/pulls/8` — placeholder unexpanded (GH_REPO unset, lane cwd outside checkout) → 404 ×3. Claim/label/worktree `issue-2-qa` preserved. Recovered: marker restored from /private/tmp to repo, `--resume --kind body` with expanded path cleared it (archive `…6586…json`). PR blocks + [qa] report + QA→Review move still owed → wave 4 (QA lane). |

## Wave 4 (run dwfrun-61eddbb9)

| # | Lanes run | Final status | Column | Detail |
|---|---|---|---|---|
| #2 | qa:advanced → review:human-gate | human-gate | Blocked | QA exit protocol completed (PR blocks, [qa] report, QA→Review). Review of PR #8 @ `10fe5e0` clean: `run-safety.sh` 53/53 rerun green, truth 85/100 ≥ 70, 3/3 AC verified, threads clean; R1/R2 should-fix failure-path edges open (non-blocking). Merge gate exit 7 — `merge_policy.default: "human"` + size 412 > 400 → 🙋 Blocked, canonical request on #2, `needs-you` on issue+PR, worktree removed, claim released. To unblock: merge PR #8 yourself or comment `done` on #2. |

**Run end**: board drained for robot work — #2/#3/#4/#5 all Blocked on human decisions.

## Resume ~11:00 (no waves — report and stop)

Planner returned zero dispatchable cards (`cards`, `sweep`, `resume`, `refreshApproval`,
`flag`, `stranded` all empty); done condition "only Blocked/Done remain" applies.

| # | Lanes run | Final status | Column | Detail |
|---|---|---|---|---|
| #2 | — | needs-you (unchanged) | Blocked | Human `done` (08:51:25Z) rejected by design: canonical request comment 6538564900 was edited 08:51:22Z, three seconds before (`super-board-approval.py` holds "approval request was edited; post a fresh request"). PR #8 head still `10fe5e0` — the reviewed sha — and MERGEABLE. Unblock: merge PR #8, or post a fresh pinned request and reply `done` to it. Orchestrator note posted on the issue. |
| #3 | — | unchanged | Blocked | Awaits split decision (453 > 400 changed lines, draft PR #7). |
| #4 | — | unchanged | Blocked | blocked-by 2, 3, 5. |
| #5 | — | unchanged | Blocked | blocked-by 3. |

Notes: tracked tree still dirty (config flip + wave-script port, uncommitted — a
dispatching run must commit or stash first). Usage guard blind in ZCode (no Claude
`rate_limits` signal), proceed per contract. `docs/super-board/pre-flight.md` absent —
treated as vacuously complete. Gh-api footgun sharpened: `gh api` has no `-R` flag at all
(repo goes in the endpoint path); archived halts `…5153…`/`…0333…` were lanes passing
`-R` to `gh api` (unknown flag ×3 → exit 79).
Resume: `/super-board run suber-super-board` — after the human unblocks #2 or splits #3.

## Resume ~16:42 local (reconcile only — no waves)

Planner returned zero dispatchable cards again; #2's human gate was satisfied
off-board (human merged PR #8), #3/#4/#5 remain Blocked. Reconciled per the #1
precedent. No lanes run, no dispatch.

| # | Lanes run | Final status | Column | Detail |
|---|---|---|---|---|
| #2 | — | done (reconciled) | Done | Human merged PR #8 — merge commit `0605e51` verified as ancestor of origin/main, carrying reviewed head `10fe5e0`. Card Blocked → Done, `needs-you` cleared (issue was already auto-closed by the merge), reconciliation comment posted. |
| #3 | — | needs-you (fresh request) | Blocked | Posted the canonical pinned request the card never had (head `246fbb5`, scope `e7185d…d418`, plan `default`-human + size 453>400) and `needs-you` on issue+PR. Approval pre-check returns "waiting for a trusted human to comment done" — machinery verified. Unblock: reply `done` to the request (merge as-is), merge PR #7 yourself, or comment what to split. |
| #4 | — | unchanged | Blocked | blocked-by 2, 3, 5 → effectively 3, 5 now (issue #2 closed by the PR #8 merge). |
| #5 | — | unchanged | Blocked | blocked-by 3. |

Notes: symptoms captured, not patched — `super-board-status.py` is broken (emits
shell permission errors plus a gh help dump; looks heredoc-mangled). `gh api`
takes no `-R` (repo goes in the endpoint path); all reads today used the helper
with correct endpoint paths. Config flip (`human_approves_merge` false → true)
and the ZCode wave-script port remain uncommitted — commit or stash before a
dispatching run. Usage guard blind again (no status-line `rate_limits` signal),
proceeded per contract exit-3.
Resume: `/super-board run suber-super-board` — after the human answers the fresh request on #3.

## Wave 5 (run dwfrun-fe7b0be5 — review of #3 after verified `done`)

| # | Lanes run | Final status | Column | Detail |
|---|---|---|---|---|
| #3 | review:blocked | blocked | Blocked | Review clean (3/3 AC verified; run-safety 52/52 branch, 54/54 merged-tree ×2 in clean env; truth 85/100). Merge gate exit 2 ×2 — ROOT CAUSE is the gate's own env: `super-board-merge-gate.sh:111` exports `SB_GITHUB_READ_STRICT=1`/`SB_REPO_PATH` into the verify loop, `tests/test_github_reads.py` asserts non-strict semantics → 4 failures for EVERY PR. Latent on main since `35e2156` (#33); #6/#8 landed as human merge-button commits, so no gate verify ran. Pinned human approval (head `246fbb5`) still stands. Unblock: sanitize the verify env (or pop the vars in the test's setUp), verify `SB_GITHUB_READ_STRICT=1 python3 tests/test_github_reads.py` → 18/18, drag card to Review. Claim released; needs-you labels on issue+PR; root-cause-hash 3a7a1583eba8. |

**Run end**: planner re-run after the wave returned `resume: [#3]` (the pinned approval
still verifies) — NOT acted on deliberately: the Reviewer reproduced the gate-env
failure on base `cb2e90f` and on `origin/main` with the exact gate recipe, so a second
wave fails identically. Acting on the resume only makes sense after the one-line fix lands.
Resume: `/super-board run suber-super-board` — after the gate-env fix lands (one line) or the human merges PR #7 by hand.

## Run attempt ~18:05 (blocked at pre-flight — no wave launched)

User asked to verify no run was active, then run. Verified idle (no workflows, no
legacy processes, empty inflight/, no halt marker). Ready was empty → moved
#9/#10/#11 Backlog → Ready per user instruction. Planner returned 4 cards
(#3 review · #9 #11 #10 build); sweep/resume/refreshApproval/flag/stranded all empty.
No wave dispatched — pre-flight found:

| Blocker | Evidence | Fix |
|---|---|---|
| 🔀 main diverged from origin/main (ahead 6, behind 8; merge-base cb2e90f) | origin has the PR #6/#8 squash merges; local has 6 unpushed onboard/pack-repo commits (e672f47…0eeff70). super-build cuts branches off LOCAL base_branch (SKILL.md "worktree add -b … <base-branch>") → every build PR would carry the 6 unrelated local commits. | Sync main (rebase local onto origin/main and push, or push as-is) — needs owner decision; not done unilaterally. |
| 🛡 gate-env bug still live (root-cause-hash 3a7a1583eba8, wave 5) | Reproduced: `SB_GITHUB_READ_STRICT=1 python3 tests/test_github_reads.py` → FAILED (failures=4). Gate would exit 2 for #3 again. | One line: `env -u SB_GITHUB_READ_STRICT -u SB_REPO_PATH` around the verify eval, or os.environ.pop in the test setUp. #3 was dragged to Review but the fix has not landed. |
| ⚠ tree dirty | config flip + wave-script port still uncommitted (advisory — waves ran with it all day). | Commit or stash before dispatch. |

No claims made, no lock created, no comments posted. #3's pinned approval (head
`246fbb5`) still stands. Cards #9/#10/#11 left in Ready.
Resume: after main is synced and the gate-env fix lands → `/super-board run suber-super-board`.
