#!/usr/bin/env bash
# Guards the .agents/skills/ discovery layout:
#   1. every entry is a REAL directory (ZCode's picker scans symlinks-disabled)
#   2. the 8 board skills are byte-identical copies of skills/<name>
#   3. skill-sets/<set>/<skill> resolve (relative symlinks into .agents/skills)
set -uo pipefail
cd "$(dirname "$0")/.."

fail() { echo "FAIL: $1" >&2; exit 1; }

BOARD_SKILLS="super-board super-build super-qa super-review super-collect ui-refine-loop visual git-sync"

# 1 — no symlinked (or missing) skill dirs in .agents/skills
for d in .agents/skills/*/; do
  name=$(basename "$d")
  [ "$name" = "references" ] && continue   # shared checklists, not a skill
  [ -d "$d" ] && [ ! -L "${d%/}" ] || fail ".agents/skills/$name must be a real directory (pickers scan symlinks-disabled)"
  [ -f "$d/SKILL.md" ] || fail ".agents/skills/$name has no SKILL.md"
done

# 2 — board copies match their source exactly
for s in $BOARD_SKILLS; do
  diff -rq "skills/$s" ".agents/skills/$s" >/dev/null 2>&1 \
    || fail ".agents/skills/$s drifted from skills/$s — run scripts/agents-skills-sync.sh"
done

# 3 — the vendored-store view resolves
for link in skill-sets/mattpocock/* skill-sets/pstack/* skill-sets/agent-skills/skills/* skill-sets/agent-skills/references; do
  base=$(basename "$link")
  case "$base" in LICENSE*|NOTICE*|README.md) continue ;; esac
  [ -e "$link" ] || fail "broken store link: $link"
done

echo "PASS: test-agents-skills-sync.sh"
