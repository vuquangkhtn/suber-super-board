# AC3 live walkthrough — `/super-plan` on a foggy request and a deliberately huge request

Issue #19 · PR #22 · head `af1ad6a` · QA v1 · 2026-11-06
Executed in worktree `.claude/worktrees/issue-19-qa` (the branch under test).

**Method.** The Tester acted as the super-plan conductor, following
`skills/super-plan/SKILL.md` phase by phase on the branch head. Two sample requests,
unrelated to the board itself:

- **Scenario A (foggy):** "Make our release notes nicer."
- **Scenario B (deliberately huge):** "Rebuild our CI into a self-healing pipeline with
  environment-aware deploys, per-service canary rollouts, cost dashboards, and automatic
  rollback."

The real onboard map was copied into the worktree (`.claude/super-board/skill-map.json` is
gitignored per `.gitignore:66`) so the skill's run-time map reads hit real data. A `gh` shim
(`/tmp/super-plan-qa-19-shim/bin/gh`) intercepted the write subcommands super-plan can issue
(`issue create`, `project item-add`, `project item-edit`, `issue edit`, `pr create`), recorded
their full argv to `gh-shim-record.txt`, and faked success; every other call was delegated to
the real `gh` (read passthrough verified: `gh api rate_limit` → 4969 remaining). **No real
issue or project item was created** — the fake ids (#9001, `ITEM-ID-FAKE`) exist nowhere on
GitHub.

**Simulation flags (same as #18's walkthrough):** no human is present in this headless QA
run. Every user answer and the route confirmation below are **simulated** and flagged as such.
The skill's rule under test — the conductor asks and never answers — is enforced by the
transcript itself: each answer is attributed to the simulated user, and the shim record
proves nothing was filed.

## Scenario A — foggy request gets interviewed (SKILL.md:65-79)

### Phase 1 — Orient (SKILL.md:50-63)

1. Read the request; read `.claude/super-board/skill-map.json` (M1 in the mechanics log):
   plan step = `{"set":"pstack","skills":["how","why","figure-it-out","show-me-your-work"]}`,
   design step = architect / arena / interrogate. Read at run time, nothing hardcoded.
2. Sharpness: "Make our release notes nicer" says neither **what** (what is "nicer"?), nor
   **for whom**, nor **what done looks like** → **not sharp** → Phase 2 with the exact open
   questions listed (SKILL.md:60-61). Open questions shown in-chat, verbatim:
   - a. Who writes the notes today and where do they live?
   - b. What does "nicer" mean — structure, audience, or tone?
   - c. What is the input — merged PRs, commit log, or handwritten sections?
   - d. What done looks like — a command, a generated file, a template?

### Phase 2 — Clarify (SKILL.md:65-79)

1. Interview source = the map's plan step (`skill-map.json` → `steps.plan.skills`, SKILL.md:67-68):
   conducted **how**, **why**, **figure-it-out**, **show-me-your-work** over the four open
   questions, one unresolved point at a time. Nothing re-asked that the request already answers
   (nothing was answered — all four were open).
2. **Simulated user answers** (the only accepted answers; the conductor never self-answered,
   SKILL.md:74-76):
   - a. "Notes go on the GitHub Release page; I write them by hand today."
   - b. "Nicer = a structured, categorized summary with emoji headers for teammates — not
     changelog-style."
   - c. "Input: merged PR titles since the last `v*` tag."
   - d. "Done: after tagging, I run a command and get a draft release body to paste in."
3. Re-judge sharpness (SKILL.md:77-79): now **what** (generate a categorized release body from
   merged PR titles since the last tag), **for whom** (teammates reading the Release page),
   **done** (a drafted release body per run) → fog cleared → Phase 3.

### Phase 3 — Route (SKILL.md:81-98)

1. Fog test: the decisions settle inside one session, but there is more than one slice and a
   real design choice (where the command wrapper lives) → **medium** (SKILL.md:86).
2. Route shown, one line, then **STOP — no design, no drafting, no filing yet** (SKILL.md:89-92):

   ```
   medium: clarify → design → cards — ok?
   ```

   **Gate evidence at the stop:** shim record held **0 lines** at this point (M5 mechanics);
   no draft files existed; nothing was filed.
3. **Simulated user confirmation:** "ok" (SKILL.md:92). Only now did drafting begin: medium →
   Phase 4 (Design, #20, not landed) → Phase 5 with design choices as open questions
   (SKILL.md:93-94). Drafts: `card-1-draft.md`, `card-2-draft.md` (in this folder) — shown
   in-chat with the decision summary (skills consulted from the map: how, figure-it-out;
   nothing stayed open; user owes the filing approval).
4. Phase 6 gate: no filing approval given → **no filing**; shim record stayed **0 lines**
   through the whole scenario. (The filing path itself was exercised by #18's walkthrough and
   is unchanged here.)

## Scenario B — deliberately huge request ends in the wayfinder handoff (SKILL.md:95-98)

1. Phase 1: map read (same M1 data). One open question (target environments) → **simulated
   user answer:** "all of them — dev, staging, and prod." Still a multi-session effort, so
   Phase 3 runs as specified: every request gets a route, sharp or not (SKILL.md:62-63).
2. Fog test: environment-aware deploys, canary policy, cost tooling and rollback semantics are
   decisions that will **not** settle inside one session even split one card per vertical slice
   → **huge** (SKILL.md:87-88).
3. Route shown, one line, then stop for confirmation: `huge: wayfinder — ok?` —
   **simulated user confirmation:** "ok".
4. Handoff branch with the real pstack map (plan step has **no wayfinder skill**): the conductor
   said so and stopped for the user's call — never planned the huge effort as small or medium
   (SKILL.md:97-98). This is the specified degrade, exercised on the real onboard data.
5. Handoff branch with a temp map whose plan step includes `wayfinder` (map-driven, never
   hardcoded): the conductor pointed the user at the **wayfinder** skill with the request and
   what Clarify surfaced, then **stopped** — super-plan files nothing after a handoff and never
   re-implements the map machinery (SKILL.md:95-96 + the invariant at SKILL.md:19-23). Shim
   record: **0 lines** — no cards, no filing.

## Degrade paths exercised (mechanics log M3–M5)

| Variant | Expected (SKILL.md) | Observed |
|---|---|---|
| map missing | Phase 1 says so, points at `/super-board onboard`, continues on the sharp path with no routed skills (:52-54) | ✅ conductor output matched; guard still ran read-only |
| plan step empty | Phase 2 says which, interviews directly in-chat, still only asks (:69-70) | ✅ conductor output matched |
| plan step without wayfinder | Phase 3 says so, stops for the user's call, never plans huge as small/medium (:97-98) | ✅ scenario B step 4 |

## Walkthrough verdict — AC3

| AC3 requirement | Observed |
|---|---|
| foggy request gets interviewed | ✅ Phase 1 listed 4 open questions; Phase 2 conducted the map's plan skills over them, one point at a time; answers only from the (simulated) user |
| route confirmed before any design/drafting | ✅ route line shown and **stopped** with 0 shim lines and 0 drafts; drafts exist only after the (simulated) confirmation |
| deliberately huge request ends with a wayfinder handoff | ✅ fog test → huge → handoff to wayfinder and stop (on a wayfinder-including map); on the real pstack map the specified no-wayfinder degrade stopped for the user's call |
| strict HITL held throughout | ✅ shim record 0 lines end-to-end; no self-answered questions; no unapproved filing |
