#!/usr/bin/env bash
# QA additions for scripts/super-board-skill-set-sync.py — the gaps the main
# suite (test-skill-set-sync.sh) leaves open:
#   1. --dry-run write-freedom asserted byte-for-byte (the main suite greps the
#      output but never compares the filesystem; its layout-B check computes a
#      checksum it never reads).
#   2. a removal of a skill mapped under a lifecycle STEP (not anytime) is
#      flagged against that step and kept on disk with the mapping intact.
#   3. carried LICENSE/NOTICE files dropped upstream are flagged and kept.
#   4. a pin-only sync (new sha, identical tree) rewrites the pins and copies
#      nothing.
#   5. a bad --ref refuses with exit 2 and touches nothing.
# Runs entirely against a hand-built mini pack in a temp dir — the real
# registry, store and UPSTREAM.md are never touched. Offline.
set -uo pipefail
cd "$(dirname "$0")/.."
PACK=$PWD
fail() { echo "FAIL: $1" >&2; exit 1; }
N=0; ok() { N=$((N + 1)); }

W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT

# ── fixture upstream: flat layout, three commits ────────────────────────────
# w1 = alpha+beta skills, NOTICE carried · w2 = alpha rewritten, beta dropped,
# NOTICE dropped upstream · w3 = empty commit (pin-only target).
SRC=$W/upstream
commit() { git -C "$SRC" add -A && git -C "$SRC" -c user.name=t -c user.email=t@example.com commit -qm "$1"; }
mkdir -p "$SRC/skills/alpha" "$SRC/skills/beta"
cat > "$SRC/skills/alpha/SKILL.md" <<'MD'
---
name: alpha
description: Does the alpha thing.
---
Do alpha, first revision.
MD
cat > "$SRC/skills/beta/SKILL.md" <<'MD'
---
name: beta
description: Does the beta thing.
---
Do beta, first revision.
MD
printf 'Upstream notices v1.\n' > "$SRC/NOTICE.md"
git -C "$SRC" init -q && commit "w1"
W1=$(git -C "$SRC" rev-parse HEAD)

cat > "$SRC/skills/alpha/SKILL.md" <<'MD'
---
name: alpha
description: Does the alpha thing.
---
Do alpha, second revision.
MD
rm -rf "$SRC/skills/beta" "$SRC/NOTICE.md"
commit "w2"
W2=$(git -C "$SRC" rev-parse HEAD)

git -C "$SRC" commit -q --allow-empty -m "w3"
W3=$(git -C "$SRC" rev-parse HEAD)

# ── mini pack: the sync script + a minimal registry/UPSTREAM.md/set dir ─────
# beta is mapped under the build STEP so check 2 exercises the steps branch of
# mapping_of() (the main suite only removes an anytime skill).
MINI=$W/pack
mkdir -p "$MINI/scripts" "$MINI/skill-sets/tiny/skills/alpha" "$MINI/skill-sets/tiny/skills/beta"
cp "$PACK/scripts/super-board-skill-set-sync.py" "$MINI/scripts/"
cat > "$MINI/skill-sets/tiny/skills/alpha/SKILL.md" <<'MD'
---
name: alpha
description: Does the alpha thing.
---
Do alpha, first revision.
MD
cat > "$MINI/skill-sets/tiny/skills/beta/SKILL.md" <<'MD'
---
name: beta
description: Does the beta thing.
---
Do beta, first revision.
MD
printf 'Upstream notices v1.\n' > "$MINI/skill-sets/tiny/NOTICE.md"
python3 - "$MINI" "$SRC" "$W1" <<'PY'
import json, sys
pack, src, w1 = sys.argv[1], sys.argv[2], sys.argv[3]
reg = {"sets": {"tiny": {
    "title": "tiny", "description": "QA fixture set.", "license": "MIT",
    "source": src, "pinned_ref": w1, "dir": "skill-sets/tiny",
    "layout": "nested", "nested_skills_dir": "skills",
    "steps": {s: ([] if s != "build" else ["alpha", "beta"])
              for s in ["plan", "design", "build", "test", "deploy", "maintain"]},
    "anytime": [],
}}}
json.dump(reg, open(f"{pack}/skill-sets/registry.json", "w"), indent=2)
PY
cat > "$MINI/UPSTREAM.md" <<MD
# Upstream provenance

| What | Source | Pinned at | License |
|---|---|---|---|
| tiny | [example/tiny]($SRC) | \`$W1\` | MIT ([skill-sets/tiny](skill-sets/tiny)) |
MD
treehash() { (cd "$1" && find . -type f | sort | xargs shasum 2>/dev/null | shasum); }
SYNC="python3 $MINI/scripts/super-board-skill-set-sync.py tiny"
cd "$MINI" || fail "mini pack missing"

# 1 — dry-run prints the full plan (steps-mapped removal included) and the
#     pack is byte-identical afterwards. This is the assertion the main
#     suite's dry-run checks are missing.
treehash . > "$W/before-dry"
OUT=$($SYNC --ref "$W2" --dry-run) || fail "dry-run failed"
echo "$OUT" | grep -q "→ $W2" || fail "dry-run misses the pin move"
echo "$OUT" | grep -q "updated: alpha" || fail "dry-run misses the update"
echo "$OUT" | grep -q "added: none" || fail "dry-run invents an add"
echo "$OUT" | grep -q "removed — KEPT" || fail "dry-run misses the removal flag"
echo "$OUT" | grep -q "beta — registry: build" \
  || fail "steps-mapped removal not flagged against its step in the dry-run"
echo "$OUT" | grep -q "nothing written" || fail "dry-run does not declare write-freedom"
treehash . > "$W/after-dry"
cmp -s "$W/before-dry" "$W/after-dry" \
  || fail "dry-run wrote to the pack — before/after trees differ"
ok

# 2 — real sync: the steps-mapped removal is flagged, beta is KEPT on disk
#     with its registry mapping untouched, alpha updated, pin moved, exit 3.
$SYNC --ref "$W2" --no-validate > "$W/sync.out"; RC=$?
[ "$RC" -eq 3 ] || fail "sync with removals should exit 3, got $RC"
grep -q "beta — registry: build" "$W/sync.out" \
  || fail "real sync does not flag the steps-mapped removal against build"
grep -q "first revision" skill-sets/tiny/skills/beta/SKILL.md \
  || fail "beta was modified or deleted — removals are kept verbatim"
grep -q "second revision" skill-sets/tiny/skills/alpha/SKILL.md \
  || fail "alpha not updated"
python3 - skill-sets/registry.json "$W2" <<'PY' || exit 1
import json, sys
e = json.load(open(sys.argv[1]))["sets"]["tiny"]
assert e["steps"]["build"] == ["alpha", "beta"], e   # mapping untouched
assert e["pinned_ref"] == sys.argv[2], e             # pin moved
assert e["anytime"] == [], e                         # no fake re-mapping
PY
ok

# 3 — NOTICE.md dropped upstream is flagged as a carried-file removal and
#     kept (the same hold as skills, per the docstring).
grep -q "carried files upstream dropped — KEPT, flagged:" "$W/sync.out" \
  || fail "carried-file removal not flagged"
grep -q -- "- NOTICE.md" "$W/sync.out" || fail "dropped NOTICE.md not named"
[ -f skill-sets/tiny/NOTICE.md ] || fail "carried NOTICE.md was deleted"
ok

# 4 — pin-only sync (w3: new sha, identical tree): pins move, no skill is
#     copied or touched (only registry.json + UPSTREAM.md may change), and
#     the pending flags persist.
treehash . > "$W/before-w3"
$SYNC --ref "$W3" --no-validate > "$W/sync-w3.out"; RC=$?
[ "$RC" -eq 3 ] || fail "pin-only sync with pending flags should exit 3, got $RC"
grep -q "→ $W3" "$W/sync-w3.out" || fail "pin-only sync misses the pin move"
grep -q "updated: none" "$W/sync-w3.out" || fail "pin-only sync copied content"
grep -q "beta — registry: build" "$W/sync-w3.out" || fail "pin-only sync dropped the removal flag"
python3 - skill-sets/registry.json "$W3" <<'PY' || exit 1
import json, sys
assert json.load(open(sys.argv[1]))["sets"]["tiny"]["pinned_ref"] == sys.argv[2]
PY
treehash . > "$W/after-w3"
diff <(sed 's/[0-9a-f]\{40\}/SHA/g' "$W/before-w3") \
     <(sed 's/[0-9a-f]\{40\}/SHA/g' "$W/after-w3") \
  | grep -Ev "registry.json|UPSTREAM.md" | grep -q '^[<>]' \
  && fail "pin-only sync touched files beyond registry.json/UPSTREAM.md"
ok

# 5 — a --ref the upstream does not have refuses with exit 2 and touches
#     nothing (never a partial sync).
treehash . > "$W/before-badref"
RC=0; $SYNC --ref no-such-ref --no-validate 2>"$W/badref.err" || RC=$?
[ "$RC" -eq 2 ] || fail "bad --ref should refuse with exit 2, got $RC"
grep -q "git checkout" "$W/badref.err" || fail "bad-ref refusal does not name the checkout failure"
treehash . > "$W/after-badref"
cmp -s "$W/before-badref" "$W/after-badref" || fail "failed sync wrote to the pack"
ok

echo "PASS: skill-set-sync-qa ($N checks)"
