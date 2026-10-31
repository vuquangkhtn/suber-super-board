#!/usr/bin/env bash
# Tests get.sh, the one-line installer, offline: the pack is served as a local
# file:// tarball (SUPER_BOARD_TARBALL). Each case installs into a fresh temp
# target and checks what landed. This fork: helper skills come from the vendored
# skill-sets/ store (no npx, no network).
set -euo pipefail
cd "$(dirname "$0")/.."
PACK="$PWD"
GET="$PACK/get.sh"

fail() { echo "FAIL: $1" >&2; exit 1; }
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# A tarball shaped like GitHub's: one top-level folder holding the pack.
mkdir -p "$WORK/src/super-board-test"
tar -cf - --exclude ./.git --exclude ./evals --exclude ./docs . | tar -xf - -C "$WORK/src/super-board-test"
tar -czf "$WORK/pack.tgz" -C "$WORK/src" super-board-test
export SUPER_BOARD_TARBALL="file://$WORK/pack.tgz"

# Stubs: gh and jq exist so no warnings fire.
mkdir -p "$WORK/bin"
printf '#!/bin/sh\nexit 0\n' > "$WORK/bin/gh"
printf '#!/bin/sh\nexit 0\n' > "$WORK/bin/jq"
chmod +x "$WORK/bin/"*
export PATH="$WORK/bin:$PATH"
export HOME="$WORK/home"; mkdir -p "$HOME"

bash -n "$GET" || fail "get.sh has a syntax error"

# 1 — default install into --target: pack lands, hooks wired, the default
#     vendored skill set (mattpocock) lands in .agents/skills with its record.
T="$WORK/t1"; mkdir -p "$T"
out=$(bash "$GET" --target "$T" 2>&1) || fail "default install exited non-zero: $out"
for s in super-board super-build super-qa super-review super-collect visual git-sync ui-refine-loop; do
  [ -f "$T/.claude/skills/$s/SKILL.md" ] || fail "skill $s not installed"
done
[ -x "$T/.claude/bin/super-board-run.sh" ] || fail "dispatcher script not installed"
[ -f "$T/.claude/workflows/super-board-wave.js" ] || fail "workflow not installed"
[ -f "$T/.claude/settings.json" ] || fail "hooks were not merged into settings.json"
[ -f "$T/.agents/skills/tdd/SKILL.md" ] || fail "default skill set (mattpocock) not installed"
[ -f "$T/.agents/skills/grilling/SKILL.md" ] || fail "mattpocock grilling not installed"
[ -L "$T/.claude/skills/tdd" ] || fail "mattpocock tdd should get a .claude/skills symlink"
[ -f "$T/.agents/skill-sets.json" ] || fail "skill-sets record missing"
python3 -c "import json,sys; r=json.load(open('$T/.agents/skill-sets.json')); assert [s['name'] for s in r['sets']] == ['mattpocock'], r" || fail "record should list exactly mattpocock"
grep -q 'pstack' "$T/.agents/skill-sets.json" && fail "pstack should not install by default"
echo "$out" | grep -q '/super-board onboard' || fail "summary is missing the next step"
n=$(printf '%s\n' "$out" | grep -c '/super-board onboard' || true)
[ "$n" -eq 1 ] || fail "the next step should be printed once, got $n times: $out"

# 2 — flags pass through to install.sh, positional target works from piped stdin.
#     --no-helper-skills installs no skill sets at all.
T="$WORK/t2"; mkdir -p "$T"
bash -s -- --protect-main --no-helper-skills "$T" < "$GET" >/dev/null 2>&1 || fail "piped install with --protect-main failed"
grep -q 'guard-protected-push' "$T/.claude/settings.json" || fail "--protect-main was not passed through to install.sh"
[ ! -e "$T/.agents/skills/tdd" ] || fail "--no-helper-skills still installed skill sets"
[ ! -e "$T/.agents/skill-sets.json" ] || fail "--no-helper-skills still wrote the record"

# 3 — --no-hooks passes through: no settings.json, no hooks dir.
T="$WORK/t3"; mkdir -p "$T"
bash "$GET" --no-hooks --no-helper-skills --target "$T" >/dev/null 2>&1 || fail "--no-hooks install failed"
[ ! -e "$T/.claude/settings.json" ] || fail "--no-hooks still wrote settings.json"
[ -f "$T/.claude/skills/super-board/SKILL.md" ] || fail "--no-hooks install skipped the skills"

# 4 — --sets chooses sets; a foreign skill in .agents/skills is never clobbered;
#     re-installing keeps the record's earlier sets.
T="$WORK/t4"; mkdir -p "$T/.agents/skills/custom-thing"
printf -- '---\nname: custom-thing\ndescription: mine\n---\n' > "$T/.agents/skills/custom-thing/SKILL.md"
out=$(bash "$GET" --sets=mattpocock,pstack --hosts=claude,zcode --target "$T" 2>&1) || fail "--sets install failed: $out"
[ -f "$T/.agents/skills/how/SKILL.md" ] || fail "pstack not installed"
[ -f "$T/.agents/skills/tdd/SKILL.md" ] || fail "mattpocock not installed"
grep -q 'name: custom-thing' "$T/.agents/skills/custom-thing/SKILL.md" || fail "a foreign skill was clobbered"
python3 -c "import json; r=json.load(open('$T/.agents/skill-sets.json')); ns=[s['name'] for s in r['sets']]; assert ns == ['mattpocock','pstack'], ns; assert r['hosts'] == ['claude','zcode'], r" || fail "record wrong after --sets"
grep -q 'tdd' <(python3 -c "import json; r=json.load(open('$T/.agents/skill-sets.json')); print(' '.join(r['sets'][1]['skipped']))") || fail "pstack tdd should be recorded as skipped (mattpocock owns it)"
echo "$out" | grep -q 'skipped: tdd' || fail "output should name the skipped skill: $out"

# 5 — a target that isn't a directory is refused, and nothing is written.
: > "$WORK/a-file"
if bash "$GET" --target "$WORK/a-file" >/dev/null 2>&1; then fail "a file as target was accepted"; fi
if bash "$GET" --target "$WORK/missing" >/dev/null 2>&1; then fail "a missing target was accepted"; fi
[ ! -e "$WORK/missing" ] || fail "a refused target was created"

# 6 — an unknown flag reaches install.sh, which rejects it; get.sh fails.
T="$WORK/t6"; mkdir -p "$T"
if bash "$GET" --bogus --no-helper-skills --target "$T" >/dev/null 2>&1; then fail "unknown flag was swallowed"; fi

# 7 — a bad tarball URL fails cleanly and leaves no temp folder behind.
T="$WORK/t7"; mkdir -p "$T"
mkdir -p "$WORK/tmp7"
if TMPDIR="$WORK/tmp7" SUPER_BOARD_TARBALL="file://$WORK/nope.tgz" bash "$GET" --no-helper-skills --target "$T" >/dev/null 2>&1; then
  fail "missing tarball was accepted"
fi
[ -z "$(ls -A "$WORK/tmp7")" ] || fail "temp folder was left behind after a failed download"

# 8 — grouped output, in the spec's order: header · checks · download · installing ·
#     skill sets · 🎉 · 👉. One line per group of files, no per-file list.
T="$WORK/t8"; mkdir -p "$T"; printf '# Rules\n- pnpm\n' > "$T/CLAUDE.md"
out=$(bash "$GET" --target "$T" 2>&1) || fail "grouped-output install failed: $out"
order=$(printf '%s\n' "$out" | grep -oE '^(🧩|🔍|📦|🔧|🧠|🎉|👉)' | tr -d '\n')
[ "$order" = "🧩🔍📦🔧🧠🎉👉" ] || fail "groups out of order ($order): $out"
printf '%s\n' "$out" | grep -q '^   ✓ curl · tar · python3 · gh · jq · node$' || fail "checks line wrong: $out"
printf '%s\n' "$out" | grep -q '^   🛡️  6 guard hooks → .claude/settings.json (new file)$' || fail "guard line wrong: $out"
printf '%s\n' "$out" | grep -q '^   ! CLAUDE.md holds its own rules — onboard offers a merge$' || fail "CLAUDE.md hint missing: $out"
printf '%s\n' "$out" | grep -q '^🧠 skill sets: installed → .agents/skills (record: .agents/skill-sets.json)$' || fail "skill sets line wrong: $out"
# This fork adds one grouped line (the skill-sets summary from install.sh),
# so the ceiling is upstream's 12 + 1.
[ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" -le 13 ] || fail "output should stay ≤ 13 lines: $out"

# 9 — Node missing: the checks line still marks it ✗ (the board's workflows need
#     it), but the vendored skill sets install anyway — no npx, no network.
T="$WORK/t9"; mkdir -p "$T"
NOBIN="$WORK/bin-nonode"; mkdir -p "$NOBIN"
for t in bash id curl tar gzip python3 mktemp mkdir rm dirname tr cp chmod grep basename sed gh jq; do
  ln -s "$(command -v "$t")" "$NOBIN/$t"
done
out=$(PATH="$NOBIN" bash "$GET" --target "$T" 2>&1) || fail "install without node failed: $out"
printf '%s\n' "$out" | grep -q '✗ node' || fail "missing node should be marked ✗: $out"
printf '%s\n' "$out" | grep -q '^🧠 skill sets: installed' || fail "skill sets should install without node: $out"
[ -f "$T/.agents/skills/tdd/SKILL.md" ] || fail "skill sets missing without node"

# 10 — this fork's defaults: the one-liner installs from THIS fork's repo, and
#     upstream's npx step stays gone (the vendored copies ship in the tarball —
#     cases 1 and 9 prove the network-free install end to end).
grep -q 'SUPER_BOARD_REPO:-vuquangkhtn/suber-super-board' "$GET" \
  || fail "the default repo must be this fork, not upstream"
grep -q 'npx skills add' "$GET" && fail "the npx helper step must stay deleted (no network, no Node)"
grep -q 'SUPER_BOARD_TARBALL' "$GET" || fail "the tarball override (used by every case above) is missing"

echo "PASS: test-get.sh (10 cases)"
