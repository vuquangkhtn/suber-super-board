#!/usr/bin/env bash
# Tests scripts/super-board-skill-set-add.py against a fixture "public skill
# repo" and a throwaway clone of the pack, so the real registry and store never
# gain a set. Covers the /skill-set-add flow: temp clone → registry entry +
# vendored dir + carried LICENSE/NOTICE + passing tests/test-registry.sh, and
# onboard's 🧩 Skills step reading its options from the registry.
set -uo pipefail
cd "$(dirname "$0")/.."
PACK=$PWD
fail() { echo "FAIL: $1" >&2; exit 1; }
N=0; ok() { N=$((N + 1)); }

W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT

# ── Fixture: a small skill repo (nested layout, MIT, NOTICE, shared refs) ──
SRC=$W/tiny-skills
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
printf 'shared checklist\n' > "$SRC/references/checklist.md"
printf 'MIT License\n\nPermission is hereby granted, free of charge.\n' > "$SRC/LICENSE"
printf 'Third-party notices for tiny-skills.\n' > "$SRC/NOTICE.md"
git -C "$SRC" init -q
git -C "$SRC" add -A
git -C "$SRC" -c user.name=t -c user.email=t@example.com commit -qm "fixture: tiny skill repo"
SHA=$(git -C "$SRC" rev-parse HEAD)

# The flow the skill prescribes: clone the repo to a temp dir, vendor from the
# clone, inside a throwaway copy of the pack (copied, not cloned, so the files
# this test brings are there before the first commit).
git clone -q "$SRC" "$W/clone"
mkdir "$W/pack"
cp -R "$PACK/skills" "$PACK/scripts" "$PACK/tests" "$PACK/skill-sets" "$W/pack/"
cd "$W/pack" || fail "pack copy failed"

TOOL="python3 $PWD/scripts/super-board-skill-set-add.py"

# 1 — vendoring yields the set dir, the registry entry, the licenses, the sha
#     pin, and a registry that still validates.
$TOOL --source "$W/clone" --name tiny \
  --url "https://github.com/example/tiny-skills" --license MIT \
  --description "Fixture set: alpha and beta." || fail "vendor run failed"
[ -f skill-sets/tiny/skills/alpha/SKILL.md ] || fail "alpha not vendored"
[ -f skill-sets/tiny/skills/beta/SKILL.md ] || fail "beta not vendored"
[ -f skill-sets/tiny/references/checklist.md ] || fail "shared references not carried"
[ -f skill-sets/tiny/LICENSE ] || fail "LICENSE not carried into the store"
[ -f skill-sets/tiny/NOTICE.md ] || fail "NOTICE not carried into the store"
[ ! -e skill-sets/tiny/.git ] || fail ".git must not be vendored"
python3 - skill-sets/registry.json <<'PY' || exit 1
import json, sys
e = json.load(open(sys.argv[1]))["sets"]["tiny"]
assert e["source"] == "https://github.com/example/tiny-skills", e
assert e["pinned_ref"], e
assert e["license"] == "MIT", e
assert e["dir"] == "skill-sets/tiny", e
assert e["layout"] == "nested" and e["nested_skills_dir"] == "skills", e
assert e["shared_references_dir"] == "references", e
assert sorted(e["anytime"]) == ["alpha", "beta"], e
assert e["steps"], e
PY
[ "$(python3 -c 'import json;print(json.load(open("skill-sets/registry.json"))["sets"]["tiny"]["pinned_ref"])')" = "$SHA" ] \
  || fail "pinned_ref is not the fixture clone sha"
bash tests/test-registry.sh >/dev/null || fail "test-registry.sh fails after vendoring"
ok

# 2 — a steps draft maps those skills; unmapped ones stay anytime.
STEPS=$W/steps.json
printf '{"build": ["alpha"]}' > "$STEPS"
$TOOL --source "$W/clone" --name tiny --force --no-validate --steps-json "$STEPS" \
  --url "https://github.com/example/tiny-skills" --license MIT \
  --description "Fixture set: alpha and beta." || fail "steps-draft run failed"
python3 - skill-sets/registry.json <<'PY' || exit 1
import json, sys
e = json.load(open(sys.argv[1]))["sets"]["tiny"]
assert e["steps"]["build"] == ["alpha"], e
assert e["anytime"] == ["beta"], e
PY
bash tests/test-registry.sh >/dev/null || fail "registry invalid after steps draft"
ok

# 3 — refusals: existing name, unknown step, unknown skill, bad name.
RC=0; $TOOL --source "$W/clone" --name tiny --no-validate --license MIT 2>/dev/null || RC=$?
[ "$RC" -eq 2 ] || fail "existing name should refuse with exit 2, got $RC"
RC=0; printf '{"sprint": ["alpha"]}' > "$STEPS"
$TOOL --source "$W/clone" --name other --no-validate --steps-json "$STEPS" 2>/dev/null || RC=$?
[ "$RC" -eq 2 ] || fail "unknown step should refuse with exit 2, got $RC"
RC=0; printf '{"build": ["gamma"]}' > "$STEPS"
$TOOL --source "$W/clone" --name other --no-validate --steps-json "$STEPS" 2>/dev/null || RC=$?
[ "$RC" -eq 2 ] || fail "unknown skill should refuse with exit 2, got $RC"
RC=0; $TOOL --source "$W/clone" --name "Bad_Name" --no-validate 2>/dev/null || RC=$?
[ "$RC" -eq 2 ] || fail "invalid name should refuse with exit 2, got $RC"
ok

# 4 — flat layout: skills at the repo top; license auto-detected from LICENSE.
FLAT=$W/flat-skills
mkdir -p "$FLAT/solo"
cat > "$FLAT/solo/SKILL.md" <<'MD'
---
name: solo
description: Does the solo thing.
---
Do solo.
MD
printf 'Permission is hereby granted, free of charge.\n' > "$FLAT/LICENSE"
$TOOL --source "$FLAT" --name flatpack --no-validate \
  --url "https://github.com/example/flat-skills" \
  --description "Fixture flat set." || fail "flat run failed"
[ -f skill-sets/flatpack/solo/SKILL.md ] || fail "flat skill not vendored at the set root"
[ -f skill-sets/flatpack/LICENSE ] || fail "flat LICENSE not carried"
LIC=$(python3 -c 'import json;print(json.load(open("skill-sets/registry.json"))["sets"]["flatpack"]["license"])')
[ "$LIC" = "MIT" ] || fail "license not auto-detected as MIT, got $LIC"
bash tests/test-registry.sh >/dev/null || fail "registry invalid after flat vendoring"
ok

# 5 — onboard's 🧩 Skills step lists sets from the registry, so the new set is
#     offered with no further edits.
grep -q 'skill-sets/registry.json' skills/super-board/references/onboard.md \
  || fail "onboard's Skills step does not read skill-sets/registry.json"
grep -q 'lifecycle_steps\|registry sets\|registry.json.*sets' skills/super-board/references/onboard.md \
  || fail "onboard's Skills step does not say where its options come from"
ok

echo "PASS: skill-set-add ($N checks)"
