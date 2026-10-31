#!/usr/bin/env bash
# Tests super-board-agents-md.py — the deterministic half of onboard's AGENTS.md
# step: detection, backup, the managed block (nothing outside the markers ever
# changes), the CLAUDE.md pointer, rule-unit splitting and the lossless check.
set -euo pipefail
cd "$(dirname "$0")"
AM="$PWD/../scripts/super-board-agents-md.py"
fail() { echo "FAIL: $1" >&2; exit 1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
am() { python3 "$AM" "$@"; }

# 1 — detect: a CLAUDE.md with its own rules is not a pointer → offer the merge.
printf '# Rules\n\n- Use pnpm.\n- NEVER force-push main.\n' > "$T/CLAUDE.md"
am detect --root "$T" | jq -e '.claude.is_pointer == false and .offer_merge == true and .agents == null' >/dev/null \
  || fail "a rules-bearing CLAUDE.md should offer the merge: $(am detect --root "$T")"

# 2 — backup copies every instruction file before anything is rewritten.
B=$(am backup --root "$T"); [ -f "$B/CLAUDE.md" ] || fail "backup should hold CLAUDE.md, got: $B"

# 3 — block --create starts AGENTS.md; a second run is a no-op.
[ "$(am block --root "$T" --create --version 9.9.9)" = created ] || fail "block --create should create"
grep -q '^<!-- super-board:begin v9.9.9' "$T/AGENTS.md" || fail "begin marker with version missing"
grep -q '^<!-- super-board:end -->' "$T/AGENTS.md" || fail "end marker missing"
[ "$(am block --root "$T" --version 9.9.9)" = unchanged ] || fail "re-running the same block must be a no-op"

# 4 — THE CONTRACT: a re-install rewrites only the managed block. Text above and
#     below it, including a user's edit, survives byte for byte.
{ echo "# AGENTS.md"; echo; echo "- user rule above"; sed -n '/super-board:begin/,/super-board:end/p' "$T/AGENTS.md"; echo "- user rule below"; } > "$T/A2"
mv "$T/A2" "$T/AGENTS.md"
sed -i.bak 's/^## Super Board$/## Super Board (hand-edited)/' "$T/AGENTS.md"; rm -f "$T/AGENTS.md.bak"
[ "$(am block --root "$T" --version 10.0.0)" = updated ] || fail "a new version should update the block"
grep -q '^- user rule above$' "$T/AGENTS.md" && grep -q '^- user rule below$' "$T/AGENTS.md" || fail "text outside the markers changed"
grep -q 'hand-edited' "$T/AGENTS.md" && fail "an edit inside the block should be overwritten"
[ "$(grep -c 'super-board:begin' "$T/AGENTS.md")" -eq 1 ] || fail "exactly one block after update"

# 5 — an existing AGENTS.md with no block gets one appended; two blocks or a
#     dangling begin marker are refused rather than guessed at.
printf '# AGENTS.md\n\n- mine\n' > "$T/AGENTS.md"
[ "$(am block --root "$T")" = inserted ] || fail "a block should be appended"
head -3 "$T/AGENTS.md" | grep -q '^- mine$' || fail "the user's text must stay first"
cat "$T/AGENTS.md" "$T/AGENTS.md" > "$T/dup.md"; mv "$T/dup.md" "$T/AGENTS.md"
RC=0; am block --root "$T" >/dev/null 2>&1 || RC=$?; [ "$RC" -eq 2 ] || fail "two blocks should be refused (2), got $RC"
printf '<!-- super-board:begin v1 -->\nx\n' > "$T/AGENTS.md"
RC=0; am block --root "$T" >/dev/null 2>&1 || RC=$?; [ "$RC" -eq 2 ] || fail "a dangling begin should be refused, got $RC"

# 6 — pointer: refuses to replace a rules-bearing CLAUDE.md without --force; with
#     it, CLAUDE.md is @AGENTS.md plus the Claude-only tail; detect then says pointer.
RC=0; am pointer --root "$T" >/dev/null 2>&1 || RC=$?; [ "$RC" -eq 2 ] || fail "pointer without --force should refuse, got $RC"
printf -- '- Use the Workflow tool for waves.\n' > "$T/tail.md"
am pointer --root "$T" --tail "$T/tail.md" --force >/dev/null
[ "$(head -1 "$T/CLAUDE.md")" = "@AGENTS.md" ] || fail "CLAUDE.md must start with @AGENTS.md"
grep -q 'Workflow tool' "$T/CLAUDE.md" || fail "the Claude-only tail must follow the import"
am detect --root "$T" | jq -e '.claude.is_pointer == true and .offer_merge == false' >/dev/null || fail "detect should now see a pointer"
[ "$(am pointer --root "$T" --tail "$T/tail.md")" = unchanged ] || fail "re-writing the same pointer is a no-op"

# 7 — units: one per bullet / table row / paragraph, heading path kept, managed
#     block and table separators skipped.
printf '# R\n\n## Build\n\n- Use pnpm.\n  continued.\n- Run tests.\n\n| a | b |\n|---|---|\n| x | y |\n\nA paragraph.\n\n<!-- super-board:begin v1 -->\n- managed\n<!-- super-board:end -->\n' > "$T/R.md"
U=$(am units --file "$T/R.md")
echo "$U" | jq -e 'length == 5' >/dev/null || fail "expected 5 units, got: $U"
echo "$U" | jq -e '.[0].heading == "R > Build" and (.[0].text | test("continued"))' >/dev/null || fail "bullet + continuation + heading path: $U"
echo "$U" | jq -e 'all(.[]; .text | test("managed") | not)' >/dev/null || fail "managed block must be skipped"

# 8 — coverage: every unit maps to a real line or is dropped on purpose.
printf -- '- Use pnpm only.\n' > "$T/NEW.md"
echo '[{"id":"U1","text":"Use pnpm.","maps_to":"- Use pnpm only."},{"id":"U2","text":"old","dropped":"user: stale"}]' > "$T/u.json"
am coverage --units "$T/u.json" --target "$T/NEW.md" >/dev/null || fail "a fully mapped set should pass"
echo '[{"id":"U1","text":"Use pnpm.","maps_to":"- Use npm."},{"id":"U2","text":"Run tests."}]' > "$T/u.json"
RC=0; OUT=$(am coverage --units "$T/u.json" --target "$T/NEW.md" 2>/dev/null) || RC=$?
[ "$RC" -eq 1 ] || fail "unmapped units should exit 1, got $RC"
echo "$OUT" | grep -q '^U1: maps_to line not found' && echo "$OUT" | grep -q '^U2: no maps_to' || fail "each gap must be named: $OUT"

# 9 — check: ≤ max lines, one marker pair.
seq 1 201 > "$T/big.md"
RC=0; am check --file "$T/big.md" >/dev/null || RC=$?; [ "$RC" -eq 1 ] || fail "201 lines should fail the size check"
am block --root "$T" --file ok.md --create >/dev/null; am check --file "$T/ok.md" >/dev/null || fail "a fresh block file should pass check"

# 10 — the shipped block template fits the budget with room for the user's rules.
N=$(wc -l < ../skills/super-board/references/agents-md-block.md)
[ "$N" -le 40 ] || fail "the managed block is $N lines; keep it ≤ 40 so AGENTS.md stays under 200"

# 11 — skill-map: from the install record, --named writes .claude/super-board/skill-map.json
#     and its own managed block in AGENTS.md; claude is always in the agents line
#     even when the record's hosts omit it.
SM="$T/skill-map-root"; mkdir -p "$SM/.agents"
cat > "$SM/.agents/skill-sets.json" <<'JSON'
{"version": 1, "hosts": ["zcode"], "sets": [
  {"name": "pstack", "title": "pstack (Claude port)", "source": "https://example/pstack",
   "pinned_ref": "190fc9a", "license": "MIT", "installed": ["how", "architect", "recall"],
   "skipped": [], "steps": {"plan": ["how"], "design": ["architect"]},
   "anytime": ["recall"], "maintain_fallback": "pstack has no Maintain skills."}]}
JSON
OUT=$(am skill-map --root "$SM" --named pstack --create) || fail "skill-map --create failed: $OUT"
[ "$OUT" = "created" ] || fail "skill-map should report created, got: $OUT"
M="$SM/.claude/super-board/skill-map.json"
[ -f "$M" ] || fail "skill-map.json was not written"
jq -e '.version == 1 and .mode == "named" and .named == "pstack"' "$M" >/dev/null || fail "skill-map.json header wrong: $(cat "$M")"
jq -e '.agents == ["claude", "zcode"]' "$M" >/dev/null || fail "claude must be forced into agents: $(cat "$M")"
jq -e '.steps.plan == {"set": "pstack", "skills": ["how"]}' "$M" >/dev/null || fail "plan step wrong: $(cat "$M")"
jq -e '.sets.pstack.pinned_ref == "190fc9a"' "$M" >/dev/null || fail "provenance must reach the map: $(cat "$M")"
grep -q '^<!-- super-board:skill-map begin (managed) -->$' "$SM/AGENTS.md" || fail "begin marker missing"
grep -q '^<!-- super-board:skill-map end -->$' "$SM/AGENTS.md" || fail "end marker missing"
grep -q 'Skill set: \*\*pstack\*\*' "$SM/AGENTS.md" || fail "named set line missing"
grep -q 'Machine-readable map: `.claude/super-board/skill-map.json`' "$SM/AGENTS.md" || fail "map pointer line missing"
grep -q '^| Plan | pstack | how |$' "$SM/AGENTS.md" || fail "step table row wrong"
grep -q 'pstack anytime skills: recall' "$SM/AGENTS.md" || fail "anytime line missing"

# 12 — a second identical run is a no-op for AGENTS.md ("unchanged") and keeps
#     exactly one marker pair.
OUT=$(am skill-map --root "$SM" --named pstack) || fail "second skill-map run failed: $OUT"
[ "$OUT" = "unchanged" ] || fail "re-running the same map must be a no-op, got: $OUT"
[ "$(grep -c 'super-board:skill-map begin' "$SM/AGENTS.md")" -eq 1 ] || fail "duplicate marker pairs"

# 13 — a user line above the block survives an update; switching --named rewrites
#     the block and the machine map, nothing else.
python3 - "$SM/AGENTS.md" <<'PY'
import sys
p = sys.argv[1]
t = open(p).read()
open(p, "w").write("- user rule\n\n" + t)
PY
python3 - "$SM/.agents/skill-sets.json" <<'PY'
import json, sys
p = sys.argv[1]
r = json.load(open(p))
r["sets"].append({"name": "mattpocock", "title": "Matt Pocock's skills", "source": "https://example/mp",
                  "pinned_ref": "282a125", "license": "MIT", "installed": ["tdd"], "skipped": [],
                  "steps": {"build": ["tdd"]}, "anytime": [], "maintain_fallback": ""})
json.dump(r, open(p, "w"))
PY
OUT=$(am skill-map --root "$SM" --named mattpocock) || fail "map update failed: $OUT"
[ "$OUT" = "updated" ] || fail "switching sets should update, got: $OUT"
head -1 "$SM/AGENTS.md" | grep -q '^- user rule$' || fail "text above the block changed"
jq -e '.named == "mattpocock"' "$M" >/dev/null || fail "map not switched: $(cat "$M")"
grep -q '^| Build | mattpocock | tdd |$' "$SM/AGENTS.md" || fail "build row missing after switch"
[ "$(grep -c 'super-board:skill-map begin' "$SM/AGENTS.md")" -eq 1 ] || fail "update duplicated the block"

# 14 — custom mode: a per-step file with "" steps falls back to the super-board
#     loop row, and an unknown set in the file is refused.
printf '{"plan": "pstack", "design": "", "build": "", "test": "pstack", "deploy": "", "maintain": ""}' > "$SM/steps.json"
am skill-map --root "$SM" --steps "$SM/steps.json" >/dev/null || fail "custom steps rejected"
jq -e '.mode == "custom" and .steps.design.set == null and .steps.test.set == "pstack"' "$M" >/dev/null \
  || fail "custom map wrong: $(cat "$M")"
grep -q 'Skill sets per step (custom): pstack.' "$SM/AGENTS.md" || fail "custom header line missing"
grep -q 'no skill set chosen' "$SM/AGENTS.md" || fail "the super-board loop fallback row is missing"
printf '{"plan": "nope"}' > "$SM/bad.json"
RC=0; am skill-map --root "$SM" --steps "$SM/bad.json" >/dev/null 2>&1 || RC=$?
[ "$RC" -eq 2 ] || fail "unknown set in a steps file should be refused (2), got $RC"

# 15 — no install record: refused with the fix named, not guessed.
SM2="$T/no-record"; mkdir -p "$SM2"
RC=0; OUT=$(am skill-map --root "$SM2" --named pstack 2>&1 >/dev/null) || RC=$?
[ "$RC" -eq 2 ] || fail "missing record should be refused (2), got $RC"
echo "$OUT" | grep -q "run install.sh with --sets first" || fail "the error should name the fix: $OUT"

echo "PASS: test-agents-md.sh (15 scenarios)"
