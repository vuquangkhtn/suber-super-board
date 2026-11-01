#!/usr/bin/env bash
# Onboard's single-value flag is --set; --sets survives only as the deprecated
# single-value alias, and install.sh's --sets stays the comma list (issue #9).
# test-fork-wizard.sh pins onboard.md ↔ registry ↔ schema; this suite pins the
# remaining surfaces the rename touched so none of them drifts back to reading
# like install.sh's list: onboard.md's step-2 text and error-recovery table,
# the get.sh + install.sh header comments, the README onboard line, and the
# .agents mirror of onboard.md.
set -uo pipefail
cd "$(dirname "$0")/.."

fail() { echo "FAIL: $*" >&2; exit 1; }
ONBOARD=skills/super-board/references/onboard.md
MIRROR=.agents/skills/super-board/references/onboard.md
GET=get.sh
INSTALL=install.sh
README=README.md

[ -f "$ONBOARD" ] || fail "onboard.md missing"
[ -f "$MIRROR" ] || fail ".agents mirror of onboard.md missing"
[ -f "$GET" ] || fail "get.sh missing"
[ -f "$INSTALL" ] || fail "install.sh missing"
[ -f "$README" ] || fail "README.md missing"

# 1 — AC1: --set pre-answers step 2 in the parameters section, and step 2 reads
#     the parameter under either spelling, so --set=pstack behaves exactly as
#     the old --sets=pstack did.
grep -q -- '--set=<mattpocock|pstack|agent-skills|custom>' "$ONBOARD" \
  || fail "onboard.md must document --set with every set name (plus custom)"
grep -q 'pre-answers steps 2' "$ONBOARD" \
  || fail "onboard.md must say the parameter pre-answers steps 2–3"
grep -q 'parameter if given (either spelling)' "$ONBOARD" \
  || fail "onboard.md step 2 must read the --set parameter under either spelling"

# 2 — AC2: --sets still works, documented as a deprecated alias of --set.
grep -q -- '--sets=<one value>' "$ONBOARD" \
  || fail 'onboard.md must keep --sets=<one value> working as the alias'
grep -q 'deprecated alias of `--set`' "$ONBOARD" \
  || fail 'onboard.md must document --sets as a deprecated alias of --set'

# 3 — AC3: a comma list halts with the message that names install.sh's list
#     semantics — in the parameters section AND the error-recovery table.
grep -q "onboard takes one skill set — install.sh's --sets takes a" "$ONBOARD" \
  || fail 'onboard.md must halt comma lists naming install.sh'"'"'s list semantics'
grep -q -- '| 2 | Comma list at `--set`/`--sets` |' "$ONBOARD" \
  || fail 'onboard.md error-recovery table must carry the comma-list halt row'

# 4 — onboard.md never tells the reader to invoke onboard with --sets=…; the
#     only --sets left are the alias, the rejection, and setup.py fix's list.
grep -q 'onboard --sets=' "$ONBOARD" \
  && fail 'onboard.md must not invoke onboard with --sets='
grep -q 'fix --sets=' "$ONBOARD" \
  || fail "onboard.md must keep setup.py fix's comma-list --sets"

# 5 — get.sh header: onboard's flag is --set, the alias is named, install.sh's
#     list passthrough is kept, and nothing says to run onboard with --sets.
grep -q -- '--set=<one set>' "$GET" \
  || fail 'get.sh header must name onboard'"'"'s --set=<one set>'
grep -q '(deprecated alias: --sets)' "$GET" \
  || fail 'get.sh header must mark --sets the deprecated alias'
grep -q -- '--sets=a,b' "$GET" \
  || fail "get.sh must keep install.sh's --sets=a,b passthrough"
grep -q 'run with --sets' "$GET" \
  && fail 'get.sh must not tell users to run onboard with --sets'

# 6 — install.sh header + parser: onboard's --set named as distinct, the
#     script's comma list documented and still parsed.
grep -q -- '--set=<one set> (deprecated alias --sets)' "$INSTALL" \
  || fail "install.sh header must name onboard's --set (alias --sets) as distinct"
grep -q -- '--sets=<list>' "$INSTALL" \
  || fail 'install.sh usage must keep its comma-list --sets=<list>'
grep -q -- '--sets=\*) SETS=' "$INSTALL" \
  || fail 'install.sh must keep parsing --sets=<list>'
grep -q 'run with --sets' "$INSTALL" \
  && fail "install.sh header must not describe onboard's flag as --sets"

# 7 — README: the onboard line uses --set, the one-set vs list split is
#     explained, and install.sh's own flag list keeps --sets.
grep -q -- '/super-board onboard --set=pstack' "$README" \
  || fail 'README onboard line must use --set'
grep -q 'deprecated alias' "$README" \
  || fail 'README must mark --sets a deprecated alias at onboard'
grep -qF -- '--sets=a,b' "$README" \
  || fail "README must name install.sh's --sets=a,b list semantics"
grep -q 'onboard --sets=' "$README" \
  && fail 'README must not invoke onboard with --sets='
grep -q -- '--sets=mattpocock,pstack,agent-skills' "$README" \
  || fail "README must keep install.sh's --sets flag list"

# 8 — the vendored .agents mirror of onboard.md carries the same text.
cmp -s "$ONBOARD" "$MIRROR" \
  || fail '.agents mirror of onboard.md drifted from skills/'

echo "PASS: test-onboard-set-flag.sh (8 checks)"
