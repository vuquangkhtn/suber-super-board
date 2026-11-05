#!/usr/bin/env bash
# QA additions for the install-default change (issue #11) — the gaps the main
# suites (test-get.sh, test-install.sh, test-setup.sh) leave open:
#   1. install.sh's hardcoded default equals skill-sets/registry.json's set
#      order — the AC says "registry order", but nothing pinned the two
#      together, so reordering the registry would silently drift the default.
#   2. collision ownership follows --sets list order, not a mattpocock
#      hardcode: --sets=pstack,mattpocock gives pstack tdd/teach and
#      mattpocock's record the skips.
#   3. the docs the AC names actually carry the new-default wording: README
#      (flags line + collision paragraph), get.sh (header + summary comment),
#      install.sh (header), onboard.md step-2 prose in both mirrors
#      (skills/ and .agents/skills/ — the pair that drifted once before).
# Offline: get.sh installs from a local file:// tarball, same harness as
# test-get.sh. Everything lands in temp dirs.
set -euo pipefail
cd "$(dirname "$0")/.."
PACK="$PWD"
GET="$PACK/get.sh"

fail() { echo "FAIL: $1" >&2; exit 1; }
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# 1 — the default SETS list in install.sh is exactly registry.json's set order.
DEFAULT_SETS=$(sed -n 's/^SETS="\(.*\)"$/\1/p' "$PACK/install.sh")
[ -n "$DEFAULT_SETS" ] || fail "could not read the default SETS line from install.sh"
python3 - "$DEFAULT_SETS" <<'PY' || fail "install.sh default SETS must equal registry.json's set order"
import json, sys
default = sys.argv[1].split(",")
registry = list(json.load(open("skill-sets/registry.json"))["sets"].keys())
assert default == registry, f"install.sh default {default} != registry order {registry}"
PY

# 2 — the docs the AC names describe the new default (one load-bearing phrase
#     per surface, both onboard.md mirrors).
grep -q 'pass a shorter list for a lean picker' "$PACK/README.md" \
  || fail "README flags line does not describe the widened default"
grep -q 'the default order is registry order' "$PACK/README.md" \
  || fail "README collision paragraph does not name the registry-order default"
grep -q 'default: all vendored sets' "$PACK/get.sh" \
  || fail "get.sh header does not describe the widened default"
grep -q 'all of them by default' "$PACK/get.sh" \
  || fail "get.sh summary comment does not describe the widened default"
grep -q 'all vendored sets in registry order' "$PACK/install.sh" \
  || fail "install.sh header does not describe the widened default"
for m in skills/super-board/references/onboard.md .agents/skills/super-board/references/onboard.md; do
  grep -q 'defaults to all sets in registry order' "$PACK/$m" \
    || fail "$m: step-2 prose does not describe the new default"
done

# 3 — reversed list flips collision ownership end to end: pstack first owns
#     tdd/teach, mattpocock's record shows the skips, record order = list order.
mkdir -p "$WORK/bin"
printf '#!/bin/sh\nexit 0\n' > "$WORK/bin/gh"
printf '#!/bin/sh\nexit 0\n' > "$WORK/bin/jq"
chmod +x "$WORK/bin/"*
export PATH="$WORK/bin:$PATH"
export HOME="$WORK/home"; mkdir -p "$HOME"

mkdir -p "$WORK/src/super-board-test"
tar -cf - --exclude ./.git --exclude ./evals --exclude ./docs . | tar -xf - -C "$WORK/src/super-board-test"
tar -czf "$WORK/pack.tgz" -C "$WORK/src" super-board-test
export SUPER_BOARD_TARBALL="file://$WORK/pack.tgz"

T="$WORK/t-reversed"; mkdir -p "$T"
bash "$GET" --sets=pstack,mattpocock --target "$T" >/dev/null 2>&1 \
  || fail "reversed --sets install failed"
python3 - "$T" <<'PY' || fail "reversed --sets must flip collision ownership (pstack first wins tdd/teach)"
import json, sys
r = json.load(open(sys.argv[1] + "/.agents/skill-sets.json"))
ns = [s["name"] for s in r["sets"]]
assert ns == ["pstack", "mattpocock"], f"record order must follow the --sets list, got {ns}"
pstack = next(s for s in r["sets"] if s["name"] == "pstack")
matto = next(s for s in r["sets"] if s["name"] == "mattpocock")
assert "tdd" in pstack["installed"] and "teach" in pstack["installed"], pstack["installed"]
assert "tdd" in matto["skipped"] and "teach" in matto["skipped"], matto["skipped"]
PY

echo "PASS: test-install-default-qa.sh (3 cases)"
