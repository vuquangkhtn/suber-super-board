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

echo "PASS: super-plan skill wiring (issue #18 ACs 1/2/4 + sync)"
