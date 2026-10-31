#!/usr/bin/env bash
# Tests scripts/super-board-setup.py `sets` — the post-onboard skill-set switch:
# the mattpocock → pstack → mattpocock round trip (AC: record, config, skill-map
# JSON and the AGENTS.md block update every time), the added/removed/skipped diff,
# the nested set's shared references, custom steps, --dry-run, and the refusals.
# Offline: install.sh comes from this checkout, helper skills are skipped.
#
#   bash tests/test-sets.sh
set -euo pipefail
cd "$(dirname "$0")/.."
PACK="$PWD"
SETUP="$PACK/scripts/super-board-setup.py"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }
export HOME="$WORK/home"; mkdir -p "$HOME"
export SUPER_BOARD_PACK="$PACK"
q() { jq -e "$@" >/dev/null; }

# 1 — seed a target: mattpocock, one config (the sole one → active by that rule),
#     and an AGENTS.md for the skill-map block to update.
T="$WORK/t"; mkdir -p "$T"
python3 "$SETUP" fix --root "$T" --no-helpers --sets mattpocock --hosts claude,zcode >/dev/null \
  || fail "seed fix failed"
mkdir -p "$T/.claude/super-board/configs"
printf '{"project": {"owner": "o", "number": 1}, "skill_sets": {"mode": "named", "named": "mattpocock"}}' \
  > "$T/.claude/super-board/configs/demo.json"
printf '# AGENTS.md\n\ndemo rules\n' > "$T/AGENTS.md"

# 2 — mattpocock → pstack: the record keeps only pstack, shared skills (tdd, teach)
#     are re-owned by pstack, mattpocock-only skills are gone from disk and from
#     .claude/skills, config + skill map + AGENTS.md block all switched.
OUT=$(python3 "$SETUP" sets pstack --root "$T") || fail "switch to pstack failed: $OUT"
echo "$OUT" | q '.mode == "named" and .sets == ["pstack"] and .dropped == ["mattpocock"]' \
  || fail "switch report header wrong: $OUT"
echo "$OUT" | q '.config == ".claude/super-board/configs/demo.json"' || fail "config not resolved: $OUT"
echo "$OUT" | q '.added | index("how") and index("architect")' || fail "added list wrong: $OUT"
echo "$OUT" | q '.removed | index("grilling") and index("research")' || fail "removed list wrong: $OUT"
echo "$OUT" | q '(.added | index("tdd")) == null and (.removed | index("tdd")) == null' \
  || fail "shared skill tdd must be re-owned, not diffed: $OUT"
echo "$OUT" | q '.skipped == [] and .skill_map != ""' || fail "clean switch should skip nothing: $OUT"
python3 - "$T/.agents/skill-sets.json" <<'PY' || fail "record after switch 1 wrong" >&2
import json, sys
r = json.load(open(sys.argv[1]))
ns = [s["name"] for s in r["sets"]]
assert ns == ["pstack"], ns
p = r["sets"][0]
assert "tdd" in p["installed"] and "teach" in p["installed"], p["installed"]
assert "grilling" not in p["installed"]
assert r["hosts"] == ["claude", "zcode"], r["hosts"]
PY
[ -f "$T/.agents/skills/how/SKILL.md" ] || fail "pstack how missing from .agents/skills"
[ ! -e "$T/.agents/skills/grilling" ] || fail "mattpocock grilling still on disk"
[ -f "$T/.agents/skills/tdd/SKILL.md" ] || fail "shared skill tdd must be reinstalled by pstack"
[ -L "$T/.claude/skills/how" ] || fail "claude link for how missing"
[ ! -e "$T/.claude/skills/grilling" ] || fail "claude link for dropped grilling still present"
jq -e '.mode == "named" and .named == "pstack"' "$T/.claude/super-board/skill-map.json" >/dev/null \
  || fail "skill-map.json not switched"
jq -e '.skill_sets == {"mode": "named", "named": "pstack"}' "$T/.claude/super-board/configs/demo.json" >/dev/null \
  || fail "config skill_sets not switched"
grep -q 'Skill set: \*\*pstack\*\*' "$T/AGENTS.md" || fail "AGENTS.md block not switched"
[ "$(grep -c 'super-board:skill-map begin' "$T/AGENTS.md")" -eq 1 ] || fail "switch duplicated the map block"

# 3 — pstack → mattpocock: the round trip restores the other side the same way.
OUT=$(python3 "$SETUP" sets mattpocock --root "$T") || fail "switch back failed: $OUT"
echo "$OUT" | q '.sets == ["mattpocock"] and .dropped == ["pstack"]' || fail "switch-back header wrong: $OUT"
echo "$OUT" | q '.added | index("grilling")' || fail "switch-back added wrong: $OUT"
echo "$OUT" | q '.removed | index("architect")' || fail "switch-back removed wrong: $OUT"
python3 - "$T" <<'PY' || fail "record after round trip wrong" >&2
import json, os, sys
T = sys.argv[1]
r = json.load(open(f"{T}/.agents/skill-sets.json"))
assert [s["name"] for s in r["sets"]] == ["mattpocock"], r
assert "tdd" in r["sets"][0]["installed"] and "teach" in r["sets"][0]["installed"]
assert os.path.exists(f"{T}/.agents/skills/grilling/SKILL.md")
assert not os.path.exists(f"{T}/.agents/skills/how")
PY
jq -e '.named == "mattpocock"' "$T/.claude/super-board/skill-map.json" >/dev/null \
  || fail "skill-map.json not switched back"
grep -q 'Skill set: \*\*mattpocock\*\*' "$T/AGENTS.md" || fail "AGENTS.md block not switched back"

# 4 — --dry-run prints the plan and touches nothing.
BEFORE_REC=$(cat "$T/.agents/skill-sets.json")
BEFORE_CFG=$(cat "$T/.claude/super-board/configs/demo.json")
BEFORE_MD=$(cat "$T/AGENTS.md")
OUT=$(python3 "$SETUP" sets agent-skills --root "$T" --dry-run) || fail "dry run failed: $OUT"
echo "$OUT" | q '.dry_run == true and .sets == ["agent-skills"] and .dropped == ["mattpocock"]' \
  || fail "dry plan header wrong: $OUT"
echo "$OUT" | q '.added | index("interview-me")' || fail "dry added wrong: $OUT"
echo "$OUT" | q '.removed | index("grilling")' || fail "dry removed wrong: $OUT"
[ "$(cat "$T/.agents/skill-sets.json")" = "$BEFORE_REC" ] || fail "dry run mutated the install record"
[ "$(cat "$T/.claude/super-board/configs/demo.json")" = "$BEFORE_CFG" ] || fail "dry run mutated the config"
[ "$(cat "$T/AGENTS.md")" = "$BEFORE_MD" ] || fail "dry run mutated AGENTS.md"

# 5 — the nested set for real: shared references/ land with it and are dropped
#     again when the choice moves on (agent-skills flattens skills + references/).
OUT=$(python3 "$SETUP" sets agent-skills --root "$T") || fail "switch to agent-skills failed: $OUT"
[ -d "$T/.agents/skills/references" ] || fail "agent-skills shared references missing"
python3 - "$T" <<'PY' || fail "agent-skills record wrong" >&2
import json, sys
r = json.load(open(sys.argv[1] + "/.agents/skill-sets.json"))
assert [s["name"] for s in r["sets"]] == ["agent-skills"], r
PY
OUT=$(python3 "$SETUP" sets mattpocock --root "$T") || fail "switch from nested set failed: $OUT"
[ ! -e "$T/.agents/skills/references" ] || fail "stale shared references left behind"
[ -f "$T/.agents/skills/grilling/SKILL.md" ] || fail "grilling missing after nested round trip"

# 6 — custom steps: install the union, write the per-step config and map, report
#     the overlaps as skipped (pstack wants teach; mattpocock owns it and stays).
cat > "$T/steps.json" <<'JSON'
{"plan": "pstack", "design": "pstack", "build": "mattpocock", "test": "pstack", "deploy": "mattpocock", "maintain": "pstack"}
JSON
OUT=$(python3 "$SETUP" sets custom --steps "$T/steps.json" --root "$T") || fail "custom switch failed: $OUT"
echo "$OUT" | q '.mode == "custom" and (.sets | sort) == (["mattpocock", "pstack"]) and .dropped == []' \
  || fail "custom header wrong: $OUT"
echo "$OUT" | q '.removed == [] and (.added | index("how"))' || fail "custom diff wrong: $OUT"
echo "$OUT" | q '.skipped | index("teach")' || fail "kept-set overlaps must be reported as skipped: $OUT"
jq -e '.skill_sets == {"mode": "custom", "steps": {"plan": "pstack", "design": "pstack", "build": "mattpocock", "test": "pstack", "deploy": "mattpocock", "maintain": "pstack"}}' \
  "$T/.claude/super-board/configs/demo.json" >/dev/null || fail "custom config wrong"
jq -e '.mode == "custom"' "$T/.claude/super-board/skill-map.json" >/dev/null || fail "custom map wrong"
grep -q 'Skill sets per step (custom): mattpocock, pstack' "$T/AGENTS.md" || fail "custom AGENTS.md block wrong"

# 7 — refusals: unknown set, custom without --steps, no name, bad --steps keys,
#     unknown --steps set → 64; no install record → 2. Nothing is written.
RC=0; OUT=$(python3 "$SETUP" sets nope --root "$T" 2>&1) || RC=$?
[ "$RC" -eq 64 ] || fail "unknown set must exit 64, got $RC: $OUT"
echo "$OUT" | q '.error' >/dev/null || fail "unknown set error not JSON: $OUT"
RC=0; OUT=$(python3 "$SETUP" sets custom --root "$T" 2>&1) || RC=$?
[ "$RC" -eq 64 ] || fail "custom without --steps must exit 64, got $RC: $OUT"
RC=0; OUT=$(python3 "$SETUP" sets --root "$T" 2>&1) || RC=$?
[ "$RC" -eq 64 ] || fail "missing name must exit 64, got $RC: $OUT"
printf '{"plan": "nope"}' > "$T/bad.json"
RC=0; OUT=$(python3 "$SETUP" sets custom --steps "$T/bad.json" --root "$T" 2>&1) || RC=$?
[ "$RC" -eq 64 ] || fail "unknown --steps set must exit 64, got $RC: $OUT"
printf '{"step": "pstack"}' > "$T/bad2.json"
RC=0; OUT=$(python3 "$SETUP" sets custom --steps "$T/bad2.json" --root "$T" 2>&1) || RC=$?
[ "$RC" -eq 64 ] || fail "unknown --steps key must exit 64, got $RC: $OUT"
mkdir -p "$T/empty"
RC=0; OUT=$(python3 "$SETUP" sets pstack --root "$T/empty" 2>&1) || RC=$?
[ "$RC" -eq 2 ] || fail "missing install record must exit 2, got $RC: $OUT"
grep -q 'Skill set: \*\*pstack\*\*\|Skill sets per step' "$T/AGENTS.md" \
  || fail "a refusal must not touch AGENTS.md"

# 8 — ambiguous config: two configs, no active marker → skill_sets stays
#     unwritten and the report says so; --config resolves it explicitly.
mkdir -p "$T/two/.claude/super-board/configs"
printf '{"skill_sets": {"mode": "named", "named": "mattpocock"}}' > "$T/two/.claude/super-board/configs/a.json"
printf '{}' > "$T/two/.claude/super-board/configs/b.json"
mkdir -p "$T/two/.agents"
printf '{"version": 1, "hosts": ["claude"], "sets": [{"name": "mattpocock", "installed": ["grilling"], "skipped": [], "steps": {}, "anytime": []}]}' \
  > "$T/two/.agents/skill-sets.json"
OUT=$(python3 "$SETUP" sets pstack --root "$T/two" --dry-run) || fail "ambiguous dry run failed: $OUT"
echo "$OUT" | q '.config == null' || fail "ambiguous config must resolve to null: $OUT"
jq -e '.skill_sets.named == "mattpocock"' "$T/two/.claude/super-board/configs/a.json" >/dev/null \
  || fail "ambiguous run must not write configs"
OUT=$(python3 "$SETUP" sets pstack --root "$T/two" --dry-run --config a.json) || fail "--config dry run failed: $OUT"
echo "$OUT" | q '.config == ".claude/super-board/configs/a.json"' || fail "--config not honored: $OUT"

echo "PASS: sets switch (round trip, diff, nested, custom, dry-run, refusals, config resolution)"
