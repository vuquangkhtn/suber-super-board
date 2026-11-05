---
name: super-plan
description: Conduct a request into super-board tickets — run the mapped plan/design skills (read from .claude/super-board/skill-map.json, never hardcoded) with the user answering every question, then draft board-format cards with checkable acceptance criteria and qa/bug/feature labels and file them to Backlog or Ready only after the user approves the drafts. Strict human-in-the-loop — super-plan picks the skills and asks the questions, never answers its own and never declares "all clear" without the user. Opt-in — /super-board run never requires it. Huge multi-session efforts go to wayfinder instead. Use when the user says "super-plan", "/super-plan", "plan this feature", "plan before run", "turn this into tickets", "break this request into cards", or "design this with me".
---

# super-plan — conduct a request into board cards

One job: conduct the mapped Plan and Design skills over a request and file approved board
cards into Backlog/Ready, so `/super-board run` can drain them. super-plan is a **conductor**:
it picks the skills, asks the questions, and files the tickets — the user answers the
questions, approves the drafts, and owns every decision. It never builds, tests or merges
product code (the cardinal rule): the board's lanes do that.

## Invariants (hold in every phase)

- **Strict HITL.** super-plan picks the skills and asks the questions; it never answers its
  own questions and never declares "all clear" without the user. An unanswered question blocks
  the phase it belongs to — proceed without it only when the user says to.
- **Conductor, not machinery.** super-plan routes to the installed skills; it does not
  reimplement them. A huge multi-session effort — one that will not fit one card per vertical
  slice even after splitting — is handed off to `wayfinder` (when the map's plan step includes
  it): its map of decision tickets stays the tool for that. super-plan then stops at the
  handoff; it does not file the wayfinder map as cards.
- **Skill routing reads the map, never a hardcoded set.** Every routed skill comes from
  `.claude/super-board/skill-map.json` (the per-set lifecycle map onboard wrote). Where the
  set lacks a step (empty list, e.g. pstack → Maintain) or the map is missing, degrade
  gracefully: say which step has no skills, fall back to the board's own loop, and continue —
  never invent one set's skill names from memory.
- **Opt-in, not a run gate.** `/super-board run` never requires super-plan. With an
  already-clear request, skip straight to drafting (Phase 5) — no interviews for their own sake.
- **Draft-then-file.** Card drafts and the decision summary are shown in-chat; cards are filed
  only after the user approves them. The summary lives in the conversation; there is no new
  artifact store — the only surviving state is the filed cards.
- **Never list.** Never build, test or merge product code (cardinal rule). Never edit files
  outside throwaway prototype artifacts (a scratch file the user asked for, then deleted).
  Every acceptance criterion on a drafted card must be checkable by a test.

## Invocation

| Command | Does |
|---|---|
| `/super-plan` | full sharp path: Orient → (skip to) Draft cards → Review + file |
| `/super-plan <request>` | same, with the request text up front |
| `/super-plan --draft-only` | draft and show the cards; never file |

Phases 2–4 (Clarify · Route · Design) arrive in follow-up tickets (#19, #20); until they land,
an unclear request is drafted as far as it goes and the open questions are listed for the user.

## Phase 1 — Orient

1. Read the request. Read `.claude/super-board/skill-map.json` (steps `plan` and `design`:
   `{set, skills}` per step). Map missing → say so, point at `/super-board onboard`, and
   continue on the sharp path with no routed skills.
2. Judge sharpness: does the request already say **what** to build, for **whom**, and
   **what done looks like** — well enough that you could draft checkable ACs without inventing
   product answers?
   - Already sharp → skip to Phase 5 (Draft cards). Opt-in means no ceremony.
   - Not sharp → list the exact open questions and stop; until #19/#20 land, the user answers
     in-chat and you re-judge. Do not guess product answers into a draft.
3. Huge multi-session effort → the wayfinder handoff (invariant above). Otherwise continue.

## Phase 5 — Draft cards

1. Split the request into vertical slices: one card = one PR under 400 changed lines
   (`merge_policy.auto_max_lines`). Slices ship end-to-end value, not layers.
2. Write each card in the board's ticket format (`docs/agents/issue-tracker.md`, which onboard
   writes into the target): `## Problem` · `## Context` (lettered steps under Where, one per
   line, no arrows) · `## Fix` · `## Acceptance Criteria` (2–5 `- [ ]` lines, each checkable) ·
   `## Risk` (🟢/🟡/🔴 + one line) · `## Blocked by` (`- #N — why` or `- None.`).
3. Title each card `<emoji> [<kind>] <scope>: <what>` (≤ 70 chars, no ticket number) and
   suggest a routing label: `feature` (new behaviour), `bug` (a fix), `qa` (tests what exists
   and skips Building). `money`/`auth`/`schema` labels mark merge-gate categories — use them
   only when the slice genuinely touches those.
4. Order the cards: a card that needs another card's output gets `## Blocked by` pointing at
   the lower-numbered card, never the reverse.
5. Show all drafts in-chat (the full card bodies, not summaries) plus the decision summary:
   which skills informed the draft, what stayed open, what the user still owes.

## Phase 6 — Review + file

1. Walk the drafts with the user, card by card. Every edit they ask for is applied before
   filing. Anything they cannot decide is cut from this batch or left open in the summary —
   never resolved by super-plan.
2. On approval, file each approved card:

   ```bash
   source .claude/bin/super-board-gh-guard.sh; sb_gh_guard_check 200
   gh issue create -R <owner>/<repo> --title "<card title>" \
     --body-file <card>.md --label <suggested label>
   gh project item-add <project-number> --owner <owner> --url <issue-url> --format json --jq '.id'
   gh project item-edit --id <item-id> --project-id <project-id> --field-id <status-field> \
     --single-select-option-id <backlog-or-ready>
   ```

   Column: **Backlog** by default; **Ready** only when the user says the card is ready to
   drain. Resolve the project/field ids once (from the config's `project` block or
   `gh project list`) and reuse them for the batch. A filing command that fails midway is
   reconciled from the remote state before any retry — never blindly re-created.
3. End by pointing at the board: print one line per filed card (`#<N> — <title> · <column> ·
   <label>`) and `Next: /super-board run <slug>` (the board drains them; super-plan's work is
   done). The decision summary stays in-chat; no file is written.

## Never

- Build, test, review or merge product code — the lanes own all of that.
- Edit any file outside a throwaway prototype artifact the user explicitly asked for.
- Write an acceptance criterion no test could assert ("works well", "is fast").
- Answer super-plan's own interview questions, or approve its own drafts.
- File a card the user has not approved, or add an artifact store for the summary.
