---
type: llm
focus: last_message
weight: 2
---

This is a super-collect dry-run over three merged PRs:
- #21 and #24 hit the same root cause: date-only strings ("2026-09-01") are parsed as UTC
  midnight and read back with local getters (getMonth), so for users west of UTC the 1st of a
  month lands in the previous month. Each PR fixed only its own call site (monthly report,
  budget alerts); there is no shared date helper.
- #26 had a one-off missing `await` on saveSettings(), fixed within that PR, plus a typo nit.

PASS only if the final report does all of the following:
1. Plans exactly ONE ticket for the shared date-only / UTC-vs-local-month root cause, citing
   both #21 and #24 as evidence.
2. Plans no ticket from #26 (the missing await or the typo).
3. Is a dry-run plan (would-file), not a claim that issues were created.

FAIL if the date problem becomes two tickets (one per PR), if it is missing, or if #26 produces a
ticket.
