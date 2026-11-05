# Walkthrough — AC3 · issue #20 · QA v1 (Phase 4 Design, medium route, end to end)

Tester-lane live walkthrough of `skills/super-plan/SKILL.md` @ `49d7de5`, re-exercising the
six-phase recipe on a **new medium request** (different from the builder's Slack walkthrough in
`docs/super-board/runs/issue-20-build-v1/walkthrough-ac3.md`). The conductor is the Tester
agent following SKILL.md literally; **every user turn is simulated by the same agent and marked
`[simulated user]`** — super-plan is strict-HITL and no human was present. Purpose: prove the
flow mechanics (interview → route confirmation → design artifacts → card drafts), not that a
human approved anything.

Map provenance: `.claude/super-board/skill-map.json` is an uncommitted onboard artifact of the
main checkout (the QA worktree has only `.claude/super-board/configs/` — see transcript §6),
so reads went to the main checkout's installed map by absolute path, as in the builder's
walkthrough. `--draft-only` semantics: filing commands are never run — the AC's end-to-end
path ends at card drafts, and filing walkthrough cards would pollute the board.

## The request (medium, foggy)

> "the board status command dumps everything and takes forever — give me a one-glance
> summary: counts per column, which lanes are busy, and any blocked cards with their reason tags"

## Phase 1 — Orient (SKILL.md lines 50–63)

- Read the map (transcript §1, §2):
  - plan step: `{"set":"pstack","skills":["how","why","figure-it-out","show-me-your-work"]}`
  - design step: `{"set":"pstack","skills":["architect","arena","interrogate"]}`
- Sharpness: not sharp — "one-glance summary" does not say what `status` does today vs the
  summary's shape (one command? a flag?), nor what done looks like (output format). → Phase 2.
- Route queued before any design or drafting (line 62–63).

## Phase 2 — Clarify (SKILL.md 65–79; interview via the map's plan step)

Open points worked one at a time with the pstack plan skills' methods:

- Q1 (why) — who reads this summary and when?
  `[simulated user]` "me, at the top of every wave — I want to decide whether to let the loop
  continue or stop it."
- Q2 (how) — one new command or a compact default for `status`?
  `[simulated user]` "a flag on the existing command, `--compact` — keep the full mode."
- Q3 (figure-it-out) — where do blocked reason tags come from?
  `[simulated user]` "parse them off the card's latest blocker comment, first tag emoji only."
- Q4 (show-me-your-work) — what must the summary show for you to act?
  `[simulated user]` "counts per column, lanes busy/idle, then one line per blocked card:
  number, tag, one-word reason."

No self-answered questions; every answer above is a quoted user word. Fog cleared → Phase 3.

## Phase 3 — Route (SKILL.md 81–98; fog test → confirmation before any design)

Fog test: surface, data source and output shape settle inside one session; the work is several
slices (board read + reason-tag parsing + output formatting) with real design choices →
**medium**.

Route line shown: `medium: clarify → design → cards — ok?`
`[simulated user]` "ok" — confirmed. Phase 3 stopped before any design or drafting (line 92).
After confirmation: medium → Phase 4 (line 93).

## Phase 4 — Design (SKILL.md 100–117; the phase this ticket adds)

1. Routing source read at run time — transcript §2:
   `jq -c '.steps.design' .claude/super-board/skill-map.json` →
   `{"set":"pstack","skills":["architect","arena","interrogate"]}` — never hardcoded.
2. Conducted the mapped design skills over the confirmed route:
   - **architect** → structure sketch of the summary (artifact below).
   - **arena** → alternative rejected: a separate always-on watcher can't share the guard's
     quota state; the summary must render from the same one `status` call already makes.
   - **interrogate** → weakest point found: "lanes busy" reads live PIDs/assignees that can be
     stale mid-wave; the summary must label the snapshot time instead of claiming liveness.
3. The artifact (throwaway structure sketch, shown in-chat — it survives only inside this
   record; no artifact store, no product file written):

   ```
   status --compact — structure sketch (throwaway)
   ├─ one gh api board read        # same call the full mode uses; nothing new, no watcher
   ├─ column counts                # ordered per config.columns
   ├─ lane busy/idle               # assignee + inflight lock presence, stamped "as of <time>"
   └─ blocked lines                # latest blocker comment per Blocked card → first reason-tag
                                   #   emoji + one-word reason; none → "no blocked cards"
   ```

   `[simulated user]` reaction: "the snapshot stamp matters — if lanes can go stale mid-wave,
   print the time and never say 'idle' without it." Design decision accepted with that edit;
   the affected point (lane line) went back through this phase once (line 113–114) and settled.
4. Design settled → Phase 5 with the design feeding the drafts (each card cites the decision
   it implements, below). Product code was never edited during design — the sketch is scratch.

## Phase 5 — Draft cards (SKILL.md 119–134; design output feeds the drafts)

- Card 1 `✨ [feature] status: compact board summary with column counts and lanes`
  — Context cites the architect sketch (single board read, column order from `config.columns`);
  Fix = `--compact` flag rendering counts + stamped lane lines; ACs checkable (exit 0 with
  counts for a known fixture board; lane line contains a timestamp; full mode unchanged).
- Card 2 `✨ [feature] status: blocked-card reason tags in compact mode`
  — `## Blocked by` card 1; Context cites the interrogate decision (parse the latest blocker
  comment, first reason-tag emoji only) and the sketch's blocked-lines block; ACs checkable
  (fixture comment with 🛡 renders one tag line; card with no blocker comment renders "unknown").
- Draft-then-file respected: full card bodies shown in-chat with the decision summary; nothing
  filed; no `gh issue create` ran (`--draft-only` semantics, see header).

## Phase 6 — Review + file (SKILL.md 136–158)

Walked the drafts card by card. `[simulated user]` approved both with one edit ("say
'as of <time>' on the lane lines, not just 'stale possible'"). Per the AC's end-to-end path
the walkthrough stops at card drafts — filing is deliberately not exercised (no real issues
created from a QA walkthrough); the filing commands themselves are the same ones #18's
walkthrough already exercised.

## Degrade checks (graceful degradation, AC1)

1. **Map absent entirely** (the QA worktree's actual state — transcript §3: only `configs/`
   there): Phase 1 (line 52–54) says the map is missing, points at `/super-board onboard`, and
   continues on the sharp path with no routed skills; Phase 4 (line 106–107) says which and
   works the design directly in-chat. The recipe never blocks on the artifact.
2. **Design step present but empty** — synthetic map, transcript §4:
   `jq -c '.steps.design.skills = []' …` → `{"set":"pstack","skills":[]}`. Phase 4's degrade
   path (line 106–107) applies: say which step has no skills, work the design directly
   in-chat, and never invent one set's skill names from memory — e.g. it must NOT propose
   "architect" from pstack memory when the step is empty.

## Never-list compliance during the walkthrough

- No product code edited: the only QA-worktree change at walkthrough end is this evidence
  file (`git status --porcelain` below); no artifact store created.
- Design artifacts survive nowhere except this record (throwaway-only, AC2 restated).
- No real issues filed; no `gh issue create` ran.

## Command transcript

```
$ jq -c '.steps.plan' /Users/gauwan/Codespaces/suber-super-board/.claude/super-board/skill-map.json
{"set":"pstack","skills":["how","why","figure-it-out","show-me-your-work"]}
$ jq -c '.steps.design' /Users/gauwan/Codespaces/suber-super-board/.claude/super-board/skill-map.json
{"set":"pstack","skills":["architect","arena","interrogate"]}
$ ls /Users/gauwan/Codespaces/suber-super-board/.claude/worktrees/issue-20-qa/.claude/super-board/
configs
$ jq -c '.steps.design.skills = []' /Users/gauwan/Codespaces/suber-super-board/.claude/super-board/skill-map.json > /tmp/sb-20-qa-empty-design.json && jq -c '.steps.design' /tmp/sb-20-qa-empty-design.json
{"set":"pstack","skills":[]}
```
