#!/usr/bin/env bash
# The fork's onboard wizard contract, offline. Upstream's wizard was 8 steps;
# this fork inserts 🧩 Skills (step 2) and 🤖 Agents (step 3) and grows the
# command line by --set/--agents (onboard's --sets survives as a deprecated
# single-value alias). Four surfaces carry that contract and must
# not drift apart: onboard.md (the wizard text), config-schema.json (the config
# keys), skill-sets/registry.json (the set names) and install.sh (the hosts).
# Each check below ties one surface to another, so a rename on one side fails
# here instead of failing an onboard run.
set -uo pipefail
cd "$(dirname "$0")/.."

fail() { echo "FAIL: $*" >&2; exit 1; }
ONBOARD=skills/super-board/references/onboard.md
SCHEMA=skills/super-board/references/config-schema.json
REG=skill-sets/registry.json
INSTALL=install.sh

[ -f "$ONBOARD" ] || fail "onboard.md missing"
[ -f "$SCHEMA" ] || fail "config-schema.json missing"
[ -f "$REG" ] || fail "registry.json missing"
[ -f "$INSTALL" ] || fail "install.sh missing"

# 1 — the wizard shows 10 steps and the fork's two sit at 2 and 3.
python3 - "$ONBOARD" <<'PY' || exit 1
import re, sys
from pathlib import Path

text = Path(sys.argv[1]).read_text()
start = text.index("**Start**")
fence = text.index("```", start)
end = text.index("```", fence + 3)
rows = re.findall(r"^  (\d+) (\S+) +(.+)$", text[fence:end], re.M)
assert [int(n) for n, _, _ in rows] == list(range(1, 11)), [n for n, _, _ in rows]
assert rows[1][1] == "🧩" and "Skills" in rows[1][2], rows[1]
assert rows[2][1] == "🤖" and "Agents" in rows[2][2], rows[2]
assert "10 steps" in text[fence:end], "the start screen must say 10 steps"
PY
[ $? -eq 0 ] || fail "wizard is not the fork's 10-step shape (2 🧩 Skills, 3 🤖 Agents)"

# 2 — the --set/--agents parameters are documented with the full choice lists.
grep -q -- '--set=<mattpocock|pstack|agent-skills|custom>' "$ONBOARD" \
  || fail "onboard.md must document --set with every set name (plus custom)"
grep -q -- '--agents=<claude,codex,opencode,copilot,zcode,other>' "$ONBOARD" \
  || fail "onboard.md must document --agents with every host"
# 2b — --sets exists at onboard only as the deprecated single-value alias, and a
#      comma list is rejected by name (it is install.sh's list, not onboard's).
grep -q 'deprecated alias' "$ONBOARD" \
  || fail "onboard.md must document --sets as a deprecated alias of --set"
grep -q "onboard takes one skill set" "$ONBOARD" \
  || fail "onboard.md must reject comma lists naming install.sh's list semantics"

# 3 — the sets onboard offers are exactly the vendored ones: onboard.md's
#     --set list ↔ registry.json's sets keys (+ the custom escape hatch).
python3 - "$ONBOARD" "$REG" <<'PY' || exit 1
import json, re, sys
from pathlib import Path

onboard = Path(sys.argv[1]).read_text()
reg = json.loads(Path(sys.argv[2]).read_text())
listed = set(re.search(r"--set=<([^>]+)>", onboard).group(1).split("|"))
assert listed == set(reg["sets"]) | {"custom"}, (listed, set(reg["sets"]))
PY
[ $? -eq 0 ] || fail "onboard's --set choices and registry.json sets disagree"

# 4 — the hosts onboard offers are exactly the ones install.sh accepts.
python3 - "$ONBOARD" "$INSTALL" <<'PY' || exit 1
import re, sys
from pathlib import Path

onboard = Path(sys.argv[1]).read_text()
installer = Path(sys.argv[2]).read_text()
listed = re.search(r"--agents=<([^>]+)>", onboard).group(1).split(",")
known = re.search(r'KNOWN_HOSTS="([^"]+)"', installer).group(1).split()
assert listed == known, (listed, known)
PY
[ $? -eq 0 ] || fail "onboard's --agents choices and install.sh KNOWN_HOSTS disagree"

# 5 — the config schema carries the fork's three keys with the documented types.
#     The schema is a reference doc with // comments (full-line and trailing) —
#     strip them outside strings, then parse. URLs inside values must survive.
python3 - "$SCHEMA" <<'PY' || exit 1
import json, sys
from pathlib import Path

def strip_comments(text):
    out, i, in_str = [], 0, False
    while i < len(text):
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\":
                out.append(text[i + 1]); i += 2; continue
            if c == '"':
                in_str = False
            i += 1; continue
        if c == '"':
            in_str = True; out.append(c); i += 1; continue
        if c == "/" and i + 1 < len(text) and text[i + 1] == "/":
            while i < len(text) and text[i] != "\n":
                i += 1
            continue
        out.append(c); i += 1
    return "".join(out)

schema = json.loads(strip_comments(Path(sys.argv[1]).read_text()))
for key in ("skill_sets", "agents", "other_agents"):
    assert key in schema, f"config-schema.json is missing the fork key {key}"
ss = schema["skill_sets"]
assert set(ss) == {"mode", "named", "steps"}, ss
assert ss["mode"] in ("named", "custom"), ss["mode"]
assert ss["steps"] is None or isinstance(ss["steps"], dict), ss["steps"]
assert isinstance(schema["agents"], list) and "claude" in schema["agents"], schema["agents"]
assert isinstance(schema["other_agents"], str), schema["other_agents"]
# The example set named in the schema must be a real vendored set.
reg = json.loads(Path("skill-sets/registry.json").read_text())
assert ss["named"] in reg["sets"], f"schema names set {ss['named']!r}, registry has {sorted(reg['sets'])}"
PY
[ $? -eq 0 ] || fail "config-schema.json fork keys are missing or malformed"

# 6 — onboard.md's fix invocations use the flags setup.py actually documents:
#     the wizard drives the install through `fix --sets=… --hosts=…`.
grep -q 'super-board-setup.py fix --sets=… --hosts=…' "$ONBOARD" \
  || fail "onboard.md must drive installs through fix --sets/--hosts"
grep -q -- '--sets=a,b' scripts/super-board-setup.py && grep -q -- '--hosts=a,b' scripts/super-board-setup.py \
  || fail "setup.py must document (and parse) fix --sets/--hosts"

echo "PASS: test-fork-wizard.sh (6 checks)"
