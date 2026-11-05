# Walkthrough — AC3 · issue #20 (Phase 4 Design, medium route, end to end)

Builder-lane live walkthrough of `skills/super-plan/SKILL.md` after the phase 4 extension.
The conductor is the Builder agent following SKILL.md literally; **every user turn is
simulated by the same agent and marked `[simulated user]`** — super-plan is strict-HITL, and
no human was present during this run. Purpose: prove the flow mechanics (interview → route
confirmation → design artifacts → card drafts), not that a human approved anything. The
Tester re-exercises this against the merged skill.

## The request (medium, foggy)

> "run reports only show up in my terminal session — send them to our Slack instead"

## Phase 1 — Orient

- Read `.claude/super-board/skill-map.json` (the installed onboard artifact; uncommitted, so
  referenced by absolute path):
  - plan step: `{"set":"pstack","skills":["how","why","figure-it-out","show-me-your-work"]}`
  - design step: `{"set":"pstack","skills":["architect","arena","interrogate"]}`
  - all three routed design skills verified installed under `.agents/skills/<name>/SKILL.md`
    (architect · arena · interrogate — see command transcript below).
- Sharpness: not sharp — "Slack" does not say which surface (webhook vs app), who reads the
  report, or what content it carries. → Phase 2.

## Phase 2 — Clarify (interview via the map's plan step)

Conducted over the open points with the pstack plan skills' methods (why → purpose first,
how → mechanism, figure-it-out → scope):

- Q1 (why) — who consumes the report, you or a team?
  `[simulated user]` "the team channel — I want the wave result visible without asking me."
- Q2 (how) — incoming webhook is the lightest Slack surface; is no-bot-install acceptable?
  `[simulated user]` "yes, webhook only for v1."
- Q3 (figure-it-out) — per-card spam or one per-run summary?
  `[simulated user]` "one per-run summary; block headlines inline."

No self-answered questions; every answer above is a quoted user word.

## Phase 3 — Route (fog test → confirmation before any design)

Fog test: the surface, audience and format now settle inside one session; the work is several
slices (config plumbing + reporter + run-loop wiring) → **medium**.

Route line shown: `medium: clarify → design → cards — ok?`
`[simulated user]` "ok" — confirmed. Phase 3 stops before any design or drafting, as written.

## Phase 4 — Design (the phase this ticket adds)

1. Routing source read at run time (command + real output):
   `jq -c '.steps.design' .claude/super-board/skill-map.json` →
   `{"set":"pstack","skills":["architect","arena","interrogate"]}`
2. Conducted the mapped design skills over the confirmed route:
   - **architect** → structure sketch of the notification surface (the artifact below).
   - **arena** → alternative rejected: a GitHub Actions Slack step can't see a locally-run
     loop's waves — the reporter must live where the runner is, invoked by the loop.
   - **interrogate** → weakest point found: the webhook URL is a secret; it lives in env
     (`super-board-env-check.sh` key names only, never `.env` contents, never committed).
3. The artifact (throwaway structure sketch, shown in-chat — it exists only inside this
   record; no artifact store, no product file written):

   ```
   Slack run-report — structure sketch (throwaway)
   ├─ scripts/super-board-notify.sh      # reporter: reads run state → one Slack Block Kit payload
   ├─ run loop (final report step)       # calls the reporter once per run end + per Block headline
   ├─ config.notifications.slack         # { webhook_env: "SB_SLACK_WEBHOOK" } — name only, no URL in config
   └─ env: SB_SLACK_WEBHOOK              # secret; missing env → report stays in session (fallback)
   ```

   `[simulated user]` reaction: "webhook only, and if the env is missing keep the session
   report as fallback." Design decision accepted; nothing contested.
4. Design settled → Phase 5 with the design feeding the drafts (each card cites the decision
   it implements, below). Product code was never edited during design — the sketch is scratch.

## Phase 5 — Draft cards (design output feeds the drafts)

- Card 1 `✨ [feature] notify: slack webhook reporter for run reports` — Context cites the
  architect sketch (reporter script + `notifications.slack.webhook_env` name-only config);
  Fix = reporter script + Block Kit payload; ACs checkable (payload shape, env-missing →
  session fallback, no secret ever written to config).
- Card 2 `✨ [feature] run: emit slack report at wave end with session fallback` — Blocked by
  card 1; Context cites the interrogate decision (fallback on missing env) and the run-loop
  hook point from the sketch.
- Draft-then-file respected: drafts shown, nothing filed, no `gh issue create` ran.

## Degrade check (empty design step)

Synthetic map written to `/tmp/sb-20-empty-design-map.json` via
`jq -c '.steps.design.skills = []'` → `{"set":"pstack","skills":[]}`.
Phase 4's degrade path says which step has no skills, works the design directly in-chat, and
never invents one set's skill names from memory — e.g. it must NOT propose "architect" from
the pstack memory when the step is empty.

## Never-list compliance during the walkthrough

- No product code edited: the only worktree change at walkthrough end is this evidence file,
  the SKILL.md/README/test edits of this ticket, and the `.agents` sync (see the PR's file
  list; `git status --porcelain` ran before the commit — nothing else).
- The design artifact survives nowhere except this record (no artifact store created).

## Command transcript

```
$ jq -c '.steps.plan'      .claude/super-board/skill-map.json
{"set":"pstack","skills":["how","why","figure-it-out","show-me-your-work"]}
$ jq -c '.steps.design'    .claude/super-board/skill-map.json
{"set":"pstack","skills":["architect","arena","interrogate"]}
$ for s in architect arena interrogate; do test -f .agents/skills/$s/SKILL.md && echo "$s: installed"; done
architect: installed
arena: installed
interrogate: installed
$ jq -c '.steps.design.skills = []' .claude/super-board/skill-map.json > /tmp/sb-20-empty-design-map.json && jq -c '.steps.design' /tmp/sb-20-empty-design-map.json
{"set":"pstack","skills":[]}
```
