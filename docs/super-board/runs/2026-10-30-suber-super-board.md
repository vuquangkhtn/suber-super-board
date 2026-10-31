# Run manifest — 2026-10-30 · suber-super-board

Wave 1 (workflow backend, run dwfrun-1b6d47de). Wave ended `halted: true` — QA-lane
required read failed; marker resumed with corrected read, claims released, work preserved.

| # | Lanes run | Final status | Column | Detail |
|---|---|---|---|---|
| #1 | build:advanced → qa:halted | halted | QA | QA lane exit 79 — required read issues/1/comments failed 3/3 (`gh api … -R` → unknown flag). Branch issue-1-maintain-and-test-fork-features @ e83bc18 + draft PR #6 preserved. |
| #3 | build:blocked | blocked | Blocked | Built green (run-safety 52/52) but 453 changed lines > auto_max_lines 400 → Block template on issue+PR, two-slice split proposed, draft PR #7. Claim released, worktree cleaned. |

Wave 2 (run dwfrun-d63e711f). Board drained for robot work — both remaining cards Blocked on human decisions.

| # | Lanes run | Final status | Column | Detail |
|---|---|---|---|---|
| #1 | qa:advanced → review:human-gate | human-gate | Blocked | QA + review clean (run-safety 52/52 rerun exit 0, adversarial truth 88 ≥ 70, threads clean, R1–R5 non-blocking); merge gate exit 7 (`merge_policy.default: "human"`) → 🙋 Blocked, canonical request issues/1#issuecomment-6527100072, awaiting human merge of head 85caefe (PR #6). |
