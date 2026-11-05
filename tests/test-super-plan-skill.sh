#!/usr/bin/env bash
# AC wiring checks for the super-plan skill (issue #18). Offline; mirrors the
# acceptance criteria a walkthrough can't re-check cheaply. AC3 (live
# walkthrough) is exercised by the Tester, not here.
set -uo pipefail
cd "$(dirname "$0")/.."

fail() { echo "FAIL: $1" >&2; exit 1; }

# AC1 — skill exists with frontmatter name, HITL rule, never-list, README
[ -f skills/super-plan/SKILL.md ] || fail "skills/super-plan/SKILL.md missing"
head -5 skills/super-plan/SKILL.md | grep -q '^name: super-plan$' \
  || fail "SKILL.md frontmatter lacks 'name: super-plan'"
grep -q 'Strict HITL' skills/super-plan/SKILL.md || fail "HITL rule missing"
grep -q 'never answers its' skills/super-plan/SKILL.md \
  || fail "HITL 'never answers its own questions' missing"
grep -q '^## Never' skills/super-plan/SKILL.md || fail "never-list section missing"
grep -q 'cardinal rule' skills/super-plan/SKILL.md || fail "cardinal-rule never item missing"
[ -f skills/super-plan/README.md ] || fail "skills/super-plan/README.md missing"

# AC2 — families.json lists super-plan under you_type; README table in sync
command -v jq >/dev/null || fail "jq missing"
[ "$(jq -r '.you_type.skills["super-plan"] // empty' skills/families.json)" ] \
  || fail "families.json: super-plan not under you_type"
[ "$(jq -r '.you_type.title' skills/families.json)" = "You type — 8 skills" ] \
  || fail "families.json you_type title is not 'You type — 8 skills'"
python3 scripts/super-board-readme-sync.py --check || fail "readme-sync --check failed"
grep -q 'You type — 8 skills' README.md || fail "README.md table not 'You type — 8 skills'"
grep -q 'skills/super-plan/README.md' README.md || fail "README.md table lacks super-plan row"

# AC4 — routing references: run.md lanes section + GUIDE.md
grep -q 'planning or design before run → `/super-plan`' skills/super-board/references/run.md \
  || fail "run.md routing line missing"
grep -q '/super-plan' docs/GUIDE.md || fail "GUIDE.md lacks /super-plan reference"

# AC5 (first half) — .agents/skills/super-plan is a real, byte-identical copy
[ -d .agents/skills/super-plan ] || fail ".agents/skills/super-plan missing"
[ -L .agents/skills/super-plan ] && fail ".agents/skills/super-plan must be a real dir, not a symlink"
diff -r skills/super-plan .agents/skills/super-plan || fail ".agents/skills/super-plan differs from skills/super-plan"
grep -q 'planning or design before run → `/super-plan`' .agents/skills/super-board/references/run.md \
  || fail ".agents copy of run.md missing the routing line"

# AC3 static contract — filing is approval-gated, drafts never auto-file
grep -q 'On approval, file each approved card' skills/super-plan/SKILL.md \
  || fail "filing step is not gated on approval"
grep -q -- '--draft-only' skills/super-plan/SKILL.md || fail "--draft-only (never file) mode missing"
grep -q 'Column: \*\*Backlog\*\* by default' skills/super-plan/SKILL.md \
  || fail "Backlog-default column rule missing"

# ---- issue #19 (phase 2 Clarify + phase 3 Route wiring) ----
phase2() { awk '/^## Phase 2/,/^## Phase 3/' skills/super-plan/SKILL.md; }
phase3() { awk '/^## Phase 3/,/^## Phase 5/' skills/super-plan/SKILL.md; }

# AC1 — phase 2: interview source is the map's plan step, read at run time; never self-answer
phase2 | grep -q 'skill-map.json` → `steps.plan.skills`' \
  || fail "#19 AC1: phase 2 does not name the map's plan step (steps.plan.skills) as interview source"
phase2 | grep -q 'read at run time, never hardcoded' \
  || fail "#19 AC1: interview source is not read at run time"
phase2 | grep -q 'Never self-answer (strict HITL)' \
  || fail "#19 AC1: phase 2 lacks the never-self-answer rule"
phase2 | grep -q 'interview directly in-chat' \
  || fail "#19 AC1: degrade path (map/plan step missing or empty → in-chat interview) missing"
grep -q 'Answer super-plan.s own interview questions' skills/super-plan/SKILL.md \
  || fail "#19 AC1: never-list self-answer item missing"
# the named source exists and is non-empty where the map is installed (onboard artifact, optional)
if [ -f .claude/super-board/skill-map.json ]; then
  jq -e '.steps.plan.skills | length > 0' .claude/super-board/skill-map.json >/dev/null \
    || fail "#19 AC1: installed skill-map.json plan step has no skills"
fi

# AC2 — phase 3: small/medium/huge via fog test; route confirmed before design/drafting;
#       huge → wayfinder handoff and stop
phase3 | grep -q 'fog test' || fail "#19 AC2: phase 3 does not use wayfinder's fog test"
for tier in small medium huge; do
  phase3 | grep -q "\*\*$tier\*\*" || fail "#19 AC2: phase 3 lacks the **$tier** classification"
done
phase3 | grep -q 'wait for confirmation' \
  || fail "#19 AC2: phase 3 does not wait for the user's confirmation of the route"
phase3 | grep -q 'stop before any design or drafting' \
  || fail "#19 AC2: phase 3 does not stop before design/drafting"
phase3 | grep -q 'hand off to `wayfinder` and stop' \
  || fail "#19 AC2: huge route lacks the wayfinder handoff-and-stop"
phase3 | grep -q 'files nothing after a handoff' \
  || fail "#19 AC2: huge route does not stop filing after the handoff"
phase3 | grep -q 'never plan a huge effort as small or medium' \
  || fail "#19 AC2: misroute guard (huge never planned as small/medium) missing"
grep -q 'Proceed past Route (Phase 3) without the user.s confirmed classification' \
  skills/super-plan/SKILL.md \
  || fail "#19 AC2: never-list route-confirmation item missing"
grep -q 'Every request gets a route' skills/super-plan/SKILL.md \
  || fail "#19: phase 1 does not route every request (sharp or not) through phase 3"

echo "PASS: super-plan skill wiring (issue #18 ACs 1/2/4 + sync · issue #19 AC1/AC2 wiring)"
