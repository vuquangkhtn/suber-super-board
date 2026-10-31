#!/usr/bin/env bash
# Tests scripts/super-board-skill-set-sync.py against a fixture "public skill
# repo" (three commits: v1 → v2 updates/adds/removals → v3 clean update) and
# throwaway snapshots of the working pack, so the real registry and store never
# change. Covers both store layouts the pack ships — skills physically under
# skill-sets/<set>/ (the /skill-set-add layout) and physically under
# .agents/skills/ with skill-sets/<set>/ symlinks (the shipped sets) — plus
# --dry-run, refusals, removal flags, and the script's own validation run.
set -uo pipefail
cd "$(dirname "$0")/.."
PACK=$PWD
fail() { echo "FAIL: $1" >&2; exit 1; }
N=0; ok() { N=$((N + 1)); }

W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT

# Snapshot the working pack into a throwaway dir: everything except git state,
# worktrees and runtime locks, so uncommitted changes are tested exactly like
# they will run. .agents must come along — the shipped sets' skill-sets/<set>/
# symlinks point into it, and a snapshot without it leaves every vendored
# skill dangling (the bug that broke test-skill-set-add.sh after #7).
snapshot() { # snapshot <dest>
  local dest=$1
  mkdir "$dest"
  (cd "$PACK" && tar -cf - \
    --exclude .git --exclude .zcode --exclude node_modules --exclude .DS_Store \
    --exclude .claude/worktrees --exclude .claude/super-board/inflight \
    .) | (cd "$dest" && tar -xf -)
}

# Fixture upstream: nested layout (skills/ + shared references/), MIT, NOTICE.
# v1 = alpha+beta · v2 = alpha rewritten, beta dropped, gamma added, refs and
# LICENSE touched · v3 = alpha rewritten again (clean sync, no removals).
SRC=$W/tiny-skills
commit() { git -C "$SRC" add -A && git -C "$SRC" -c user.name=t -c user.email=t@example.com commit -qm "$1"; }
mkdir -p "$SRC/skills/alpha" "$SRC/skills/beta" "$SRC/references"
for s in alpha beta; do
  cat > "$SRC/skills/$s/SKILL.md" <<MD
---
name: $s
description: Does the $s thing.
---
Do $s.
MD
done
printf 'shared checklist v1\n' > "$SRC/references/checklist.md"
printf 'MIT License v1\n\nPermission is hereby granted, free of charge.\n' > "$SRC/LICENSE"
printf 'Third-party notices for tiny-skills.\n' > "$SRC/NOTICE.md"
git -C "$SRC" init -q && commit "v1"
SHA1=$(git -C "$SRC" rev-parse HEAD)

cat > "$SRC/skills/alpha/SKILL.md" <<'MD'
---
name: alpha
description: Does the alpha thing, v2.
---
Do alpha, second revision. See ../../../references/checklist.md.
MD
rm -rf "$SRC/skills/beta"
mkdir -p "$SRC/skills/gamma"
printf -- '---\nname: gamma\ndescription: New in v2.\n---\nDo gamma.\n' > "$SRC/skills/gamma/SKILL.md"
printf 'shared checklist v2\n' > "$SRC/references/checklist.md"
printf 'MIT License v2\n\nPermission is hereby granted, free of charge.\n' > "$SRC/LICENSE"
commit "v2"
SHA2=$(git -C "$SRC" rev-parse HEAD)

printf -- '---\nname: alpha\ndescription: Does the alpha thing, v3.\n---\nDo alpha, third revision.\n' > "$SRC/skills/alpha/SKILL.md"
commit "v3"
SHA3=$(git -C "$SRC" rev-parse HEAD)

# Second fixture: flat layout (skills at the repo top), two commits, content
# update only — for the clean exit-0 sync path, where no removal is pending.
FLAT=$W/flat-skills
mkdir -p "$FLAT/solo"
printf -- '---\nname: solo\ndescription: Does the solo thing.\n---\nDo solo, first revision.\n' > "$FLAT/solo/SKILL.md"
git -C "$FLAT" init -q && git -C "$FLAT" add -A \
  && git -C "$FLAT" -c user.name=t -c user.email=t@example.com commit -qm "w1"
WSHA1=$(git -C "$FLAT" rev-parse HEAD)
printf -- '---\nname: solo\ndescription: Does the solo thing.\n---\nDo solo, second revision.\n' > "$FLAT/solo/SKILL.md"
git -C "$FLAT" add -A && git -C "$FLAT" -c user.name=t -c user.email=t@example.com commit -qm "w2"
WSHA2=$(git -C "$FLAT" rev-parse HEAD)

# A minimal UPSTREAM.md for the snapshots: one provenance row carrying the pin.
upstream_md() { # upstream_md <dest> <pin>
  local dest=$1 pin=$2
  cat > "$dest/UPSTREAM.md" <<MD
# Upstream provenance

| What | Source | Pinned at | License |
|---|---|---|---|
| tiny-skills | [example/tiny-skills](https://github.com/example/tiny-skills) | \`$pin\` | MIT ([skill-sets/tiny](skill-sets/tiny)) |
MD
}

# ── Layout A: set vendored in place under skill-sets/<set>/ ────────────────
A=$W/pack-a
snapshot "$A"
upstream_md "$A" "$SHA1"
cd "$A" || fail "pack-a snapshot failed"
git -C "$SRC" checkout -q "$SHA1"  # vendor the v1 state, pin = SHA1
printf '{"build": ["alpha"]}' > "$A/steps.json"
python3 scripts/super-board-skill-set-add.py --source "$SRC" --name tiny --no-validate \
  --url "$SRC" --license MIT --steps-json "$A/steps.json" \
  --description "Fixture set: alpha and beta." || fail "vendor run failed"
bash tests/test-registry.sh >/dev/null || fail "registry invalid before any sync"
SYNC_A="python3 $PWD/scripts/super-board-skill-set-sync.py tiny"

# 1 — dry-run prints the plan (pin move, update, add, removal) and writes nothing.
OUT=$($SYNC_A --ref "$SHA2" --dry-run) || fail "dry-run failed"
echo "$OUT" | grep -q "→ $SHA2" || fail "dry-run does not show the pin move"
echo "$OUT" | grep -q "updated: alpha" || fail "dry-run does not list the update"
echo "$OUT" | grep -q "added: gamma" || fail "dry-run does not list the add"
echo "$OUT" | grep -q "removed — KEPT" || fail "dry-run does not flag the removal"
echo "$OUT" | grep -q "beta — registry:" || fail "removal not flagged against its registry mapping"
echo "$OUT" | grep -q "nothing written" || fail "dry-run does not say it wrote nothing"
ok

# 2 — a sha-less pin refuses with the fix in the message (offline, no clone).
python3 - skill-sets/registry.json <<'PY'
import json, sys
p = sys.argv[1]
reg = json.load(open(p))
reg["sets"]["tiny"]["pinned_ref"] = "vendored recently (repo commit c0ffee)"
json.dump(reg, open(p, "w"), indent=2)
PY
RC=0; $SYNC_A 2>"$W/no-sha.err" || RC=$?
[ "$RC" -eq 2 ] || fail "sha-less pin without --ref should refuse with exit 2, got $RC"
grep -q "no commit sha" "$W/no-sha.err" || fail "refusal does not say how to fix the pin"
ok

# 3 — real sync to v2: store updated in place, add lands + anytime, removal
#     kept and flagged, pins rewritten, carried LICENSE refreshed.
$SYNC_A --ref "$SHA2" --no-validate > "$W/sync-a.out"; RC=$?
[ "$RC" -eq 3 ] || fail "sync with a removal should exit 3, got $RC"
grep -q "beta — registry:" "$W/sync-a.out" || fail "removal not flagged in the real sync"
grep -q "MIT License v2" skill-sets/tiny/LICENSE || fail "carried LICENSE not refreshed"
grep -q "second revision" skill-sets/tiny/skills/alpha/SKILL.md || fail "alpha not updated"
[ -f skill-sets/tiny/skills/gamma/SKILL.md ] || fail "gamma not added to the set dir"
[ -f skill-sets/tiny/skills/beta/SKILL.md ] || fail "beta was deleted — removals are kept"
grep -q "shared checklist v2" skill-sets/tiny/references/checklist.md \
  || fail "shared references not refreshed"
python3 - skill-sets/registry.json <<'PY' || exit 1
import json, sys
e = json.load(open(sys.argv[1]))["sets"]["tiny"]
assert e["steps"]["build"] == ["alpha"], e          # mapping untouched
assert e["anytime"] == ["beta", "gamma"], e          # beta kept, gamma parked
assert e["pinned_ref"], e
PY
grep -q "\`$SHA2\`" UPSTREAM.md || fail "UPSTREAM.md pin not rewritten"
grep -q "MIT (\[skill-sets/tiny\](skill-sets/tiny))" UPSTREAM.md \
  || fail "UPSTREAM.md row mangled beyond the pin"
bash tests/test-registry.sh >/dev/null || fail "registry invalid after sync-with-flags"
ok

# 4 — idempotence: the same sync again writes nothing and still flags the
#     kept removal (the flag stays visible until a human remaps it).
find . -type f | sort | xargs shasum 2>/dev/null | shasum > "$W/before-resync"
$SYNC_A --ref "$SHA2" --no-validate > "$W/resync.out"; RC=$?
[ "$RC" -eq 3 ] || fail "re-sync should still flag the kept removal (exit 3), got $RC"
grep -q "beta — registry:" "$W/resync.out" || fail "re-sync dropped the removal flag"
find . -type f | sort | xargs shasum 2>/dev/null | shasum > "$W/after-resync"
cmp -s "$W/before-resync" "$W/after-resync" || fail "re-sync wrote something"
ok

# 5 — clean sync (no removal pending) exits 0 and runs its own validation:
#     the script executes tests/test-registry.sh then tests/run-safety.sh and
#     fails the sync when either fails. run-safety.sh here is a test double
#     that records the invocation and delegates to the real test-registry.sh:
#     the full suite cannot run in a fixture pack (fork-wizard pins onboard's
#     --sets list to the stock registry, which a fixture set necessarily
#     breaks); the real repo's run-safety.sh pass is proven on the branch and
#     by the merge gate. The clean sync uses the flat-layout fixture, whose
#     only pending change is the w1 → w2 content update.
printf '{"build": ["solo"]}' > "$A/steps-solo.json"
git -C "$FLAT" checkout -q "$WSHA1"  # vendor the w1 state, pin = WSHA1
python3 scripts/super-board-skill-set-add.py --source "$FLAT" --name solo --no-validate \
  --layout flat --url "$FLAT" --license MIT --steps-json "$A/steps-solo.json" \
  --description "Fixture flat set." || fail "flat vendor run failed"
bash tests/test-registry.sh >/dev/null || fail "registry invalid after flat vendoring"
cat > tests/run-safety.sh <<'STUB'
#!/usr/bin/env bash
# test double for tests/run-safety.sh (see check 5): log the invocation, then
# run the real registry test so "passes" still means something here.
echo "stub-run-safety ran" >> .sync-validation-log
exec bash tests/test-registry.sh
STUB
python3 scripts/super-board-skill-set-sync.py solo --ref "$WSHA2" > "$W/sync-solo.out"; RC=$?
[ "$RC" -eq 0 ] || fail "clean sync without --no-validate should exit 0, got $RC"
grep -q "stub-run-safety ran" .sync-validation-log \
  || fail "clean sync did not run tests/run-safety.sh"
grep -q "PASS: test-registry.sh" "$W/sync-solo.out" \
  || fail "clean sync did not run tests/test-registry.sh"
grep -q "second revision" skill-sets/solo/solo/SKILL.md || fail "solo not updated to w2"
cat > tests/run-safety.sh <<'STUB'
#!/usr/bin/env bash
# test double, failing variant: the sync must route a red suite to exit 1.
exit 1
STUB
python3 scripts/super-board-skill-set-sync.py solo --ref "$WSHA1" > "$W/sync-back.out" 2>/dev/null; RC=$?
[ "$RC" -eq 1 ] || fail "sync must fail with exit 1 when its validation fails, got $RC"
grep -q "first revision" skill-sets/solo/solo/SKILL.md || fail "sync-back to w1 did not apply"
ok

# ── Layout B: physical store in .agents/skills/, set dir holds symlinks ────
B=$W/pack-b
snapshot "$B"
upstream_md "$B" "$SHA1"
cd "$B" || fail "pack-b snapshot failed"
git -C "$SRC" checkout -q "$SHA1"  # back to v1 content for the pre-sync store
mkdir -p .agents/skills/references skill-sets/tiny/skills
for s in alpha beta; do
  cp -R "$SRC/skills/$s" ".agents/skills/$s"
  ln -s "../../../.agents/skills/$s" "skill-sets/tiny/skills/$s"
done
cp "$SRC/references/checklist.md" .agents/skills/references/checklist.md
ln -s "../../.agents/skills/references" skill-sets/tiny/references
cp "$SRC/LICENSE" skill-sets/tiny/LICENSE
python3 - skill-sets/registry.json "$SHA1" "$SRC" <<'PY' || exit 1
import json, sys
p, sha, source = sys.argv[1], sys.argv[2], sys.argv[3]
reg = json.load(open(p))
reg["sets"]["tiny"] = {
    "title": "tiny", "description": "Fixture set.", "license": "MIT",
    "source": source,
    "pinned_ref": sha,
    "dir": "skill-sets/tiny", "layout": "nested",
    "nested_skills_dir": "skills", "shared_references_dir": "references",
    "steps": {s: ([] if s != "build" else ["alpha"])
              for s in reg["lifecycle_steps"]},
    "anytime": ["beta"],
}
json.dump(reg, open(p, "w"), indent=2)
PY
bash tests/test-registry.sh >/dev/null || fail "layout-b registry invalid before sync"
LINK_BEFORE=$(readlink skill-sets/tiny/skills/alpha)
SYNC_B="python3 $PWD/scripts/super-board-skill-set-sync.py tiny"

# 6 — dry-run on the symlink layout writes nothing.
OUT=$($SYNC_B --ref "$SHA2" --dry-run) || fail "layout-b dry-run failed"
echo "$OUT" | grep -q "→ $SHA2" || fail "layout-b dry-run misses the pin move"
echo "$OUT" | grep -q "removed — KEPT" || fail "layout-b dry-run misses the removal"
find . -type f | sort | xargs shasum 2>/dev/null | shasum > "$W/b-after"
ok

# 7 — real sync: physical store updated, symlinks untouched, gamma added to
#     .agents/skills + linked, deep references link normalized, pins rewritten.
$SYNC_B --ref "$SHA2" --no-validate > "$W/sync-b.out"; RC=$?
[ "$RC" -eq 3 ] || fail "layout-b sync should exit 3, got $RC"
grep -q "second revision" .agents/skills/alpha/SKILL.md || fail ".agents store alpha not updated"
[ "$(readlink skill-sets/tiny/skills/alpha)" = "$LINK_BEFORE" ] \
  || fail "set symlink changed — store symlinks must stay"
[ -f skill-sets/tiny/skills/alpha/SKILL.md ] || fail "alpha unreachable through the set link"
[ -f .agents/skills/beta/SKILL.md ] || fail "beta deleted from the store — removals are kept"
[ "$(readlink skill-sets/tiny/skills/beta)" = "../../../.agents/skills/beta" ] \
  || fail "kept beta's symlink changed"
[ -f .agents/skills/gamma/SKILL.md ] || fail "gamma not added to .agents/skills"
[ "$(readlink skill-sets/tiny/skills/gamma)" = "../../../.agents/skills/gamma" ] \
  || fail "gamma's set symlink missing or wrong"
grep -q "\.\./\.\./references/checklist.md" .agents/skills/alpha/SKILL.md \
  || fail "deep ../../../references link not normalized to ../../"
grep -q "shared checklist v2" .agents/skills/references/checklist.md \
  || fail "shared references copy not refreshed"
grep -q "MIT License v2" skill-sets/tiny/LICENSE || fail "carried LICENSE not refreshed"
python3 - skill-sets/registry.json <<'PY' || exit 1
import json, sys
e = json.load(open(sys.argv[1]))["sets"]["tiny"]
assert e["steps"]["build"] == ["alpha"], e
assert e["anytime"] == ["beta", "gamma"], e
PY
grep -q "\`$SHA2\`" UPSTREAM.md || fail "layout-b UPSTREAM.md pin not rewritten"
bash tests/test-registry.sh >/dev/null || fail "layout-b registry invalid after sync"
ok

# 8 — refusals that must never touch disk, all offline: a source that is
#     neither an http(s) URL nor a local checkout, an unreachable clone
#     target, and a dangling set link.
python3 - skill-sets/registry.json "$W/nowhere" <<'PY'
import json, sys
p = sys.argv[1]
reg = json.load(open(p))
reg["sets"]["tiny"]["source"] = sys.argv[2]
json.dump(reg, open(p, "w"), indent=2)
PY
RC=0; $SYNC_B --ref "$SHA1" --no-validate 2>"$W/url.err" || RC=$?
[ "$RC" -eq 2 ] || fail "non-url non-checkout source should refuse with exit 2, got $RC"
grep -q "local checkout" "$W/url.err" || fail "source refusal lacks guidance"
python3 - skill-sets/registry.json <<PY
import json
p = "skill-sets/registry.json"
reg = json.load(open(p))
reg["sets"]["tiny"]["source"] = "https://127.0.0.1:1/example/tiny-skills.git"
json.dump(reg, open(p, "w"), indent=2)
PY
RC=0; $SYNC_B --ref "$SHA1" --no-validate 2>"$W/clone.err" || RC=$?
[ "$RC" -eq 2 ] || fail "unclonable source should refuse with exit 2, got $RC"
grep -q "never sync from a partial checkout" "$W/clone.err" || fail "clone refusal lacks guidance"
python3 - "$SRC" <<PY
import json, sys
p, source = "skill-sets/registry.json", sys.argv[1]
reg = json.load(open(p))
reg["sets"]["tiny"]["source"] = source
json.dump(reg, open(p, "w"), indent=2)
PY
rm -rf .agents/skills/gamma
RC=0; $SYNC_B --ref "$SHA1" --no-validate 2>"$W/dangling.err" || RC=$?
[ "$RC" -eq 2 ] || fail "dangling store link should refuse with exit 2, got $RC"
grep -q "repair by hand" "$W/dangling.err" || fail "dangling-link refusal lacks guidance"
ok

echo "PASS: skill-set-sync ($N checks)"
