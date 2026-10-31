#!/usr/bin/env bash
# Tests the Builder pre-flight wiring in workflows/super-board-wave.js. No gh
# calls: the TypeScript wave body is spliced into a generated .mts module with
# the facade stubbed (agent(name).ask, phase/report/artifact no-ops), run with
# node --experimental-strip-types, and the pre-flight agent's verdicts are
# scripted per card.
#
# The rule: no Ready card reaches runLane('build') without a pre-flight verdict
# that says go. A hold, a sequence-behind, or a missing verdict ends the card's
# chain for this wave and shows up in the summary — never silently dropped.
set -euo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

gen() { # gen <cards-json> <verdicts-json> — result in $TMP/out.json
  {
    printf 'const args = { configPath: %s, cards: %s }\n' "'c.json'" "$1"
    printf 'const verdicts: Record<string, { verdict: string; column?: string; detail: string }> = %s\n' "$2"
    cat <<'PRE'
const calls: string[] = []
const prompts: Record<string, string> = {}
function replyFor(name: string): unknown {
  if (name.startsWith('preflight-')) {
    const nums = name.slice('preflight-'.length).split('-').map((s) => Number(s))
    return { verdicts: nums.filter((n) => verdicts[String(n)]).map((n) => ({ number: n, ...verdicts[String(n)] })) }
  }
  if (name.startsWith('classifier-')) return { kind: 'feature', complexity: 'low' }
  const lane = name.startsWith('builder-') ? 'build' : name.startsWith('tester-') ? 'qa' : 'review'
  return { status: 'advanced', column: lane === 'review' ? 'Done' : 'next', detail: 'ok' }
}
const agent = (name: string, _persona?: unknown) => ({
  ask: async <T>(prompt: string): Promise<T> => {
    calls.push(name)
    prompts[name] = prompt
    return replyFor(name) as T
  },
})
const log = (_m: string): void => {}
const phase = (_n: string): void => {}
const report = (_i: unknown, _t?: string): void => {}
const artifact = { board: (_i: string, _s: unknown): void => {} }
async function main() {
PRE
    cat ../workflows/super-board-wave.js
    cat <<'POST'
}
const out = await main();
console.log(JSON.stringify({ calls, prompts, out }));
POST
  } > "$TMP/run.mts"
  node --experimental-strip-types "$TMP/run.mts" > "$TMP/out.json" 2> "$TMP/err.log" \
    || { cat "$TMP/err.log" >&2; exit 1; }
}

assert() { # assert <message> <jq filter>
  jq -e "$2" "$TMP/out.json" >/dev/null || { echo "FAIL: $1"; exit 1; }
}
fail() { echo "FAIL: $1"; exit 1; }

CARDS6='[{number:1,status:"Ready",title:"t1"},{number:2,status:"Ready",title:"t2"},{number:3,status:"Ready",title:"t3"},{number:4,status:"Ready",title:"t4"},{number:5,status:"Ready",title:"t5"},{number:6,status:"Review",title:"t6"}]'
VERDICTS6='{"1":{verdict:"proceed",detail:"clean"},"2":{verdict:"hold",column:"Blocked",detail:"duplicate of merged PR #31"},"3":{verdict:"sequence",column:"Blocked",detail:"behind #50 (PR #41 touches login.ts)"},"4":{verdict:"sequence",column:"Ready",detail:"expected conflict with PR #44 — merge gate rebases"}}'

gen "$CARDS6" "$VERDICTS6"
# 1 — proceed builds.
assert '#1 proceed must build' '.calls | index("builder-1") != null'
# 2 — hold never builds, and is reported as a pre-flight block in Blocked.
assert '#2 hold must not build' '.calls | index("builder-2") == null'
assert '#2 must be reported preflight:blocked in Blocked' \
  '[.out.cards[] | select(.number == 2)][0] | .lastLane == "preflight" and .finalStatus == "blocked" and .column == "Blocked"'
assert '#2 detail must name the duplicate' '.out.cards[] | select(.number == 2) | .detail | test("#31")'
# 3 — sequence behind an issue parks the card; 4 — sequence with only a conflict note builds.
assert '#3 sequenced behind #50 must not build this wave' '.calls | index("builder-3") == null'
assert '#4 conflict-note sequence must build' '.calls | index("builder-4") != null'
# 5 — a missing verdict is never built unchecked; it stays Ready for the next wave.
assert '#5 had no verdict and must not build' '.calls | index("builder-5") == null'
assert '#5 must be failed@Ready' \
  '[.out.cards[] | select(.number == 5)][0] | .finalStatus == "failed" and .column == "Ready"'
# 6 — cards already past Ready are not pre-flighted.
assert '5 Ready cards = 1 pre-flight agent' '[.calls[] | select(startswith("preflight-"))] | length == 1'
assert '#6 review must still run' '.calls | index("reviewer-6") != null'

# 7 — batching: a 6th Ready card needs a second pre-flight agent.
gen '[{number:1,status:"Ready",title:"t"},{number:2,status:"Ready",title:"t"},{number:3,status:"Ready",title:"t"},{number:4,status:"Ready",title:"t"},{number:5,status:"Ready",title:"t"},{number:6,status:"Ready",title:"t"},{number:7,status:"Ready",title:"t"}]' \
    '{"1":{verdict:"proceed",detail:"clean"},"2":{verdict:"proceed",detail:"clean"},"3":{verdict:"proceed",detail:"clean"},"4":{verdict:"proceed",detail:"clean"},"5":{verdict:"proceed",detail:"clean"},"6":{verdict:"proceed",detail:"clean"},"7":{verdict:"proceed",detail:"clean"}}'
assert '7 Ready cards = 2 pre-flight agents' '[.calls[] | select(startswith("preflight-"))] | length == 2'

# 8 — a qa-labelled Ready card skips Building: no pre-flight, no Builder, Tester
#     first, told to move the card Ready → QA itself. Lane from the planner or labels.
gen '[{number:1,status:"Ready",title:"t1",lane:"qa",labels:["qa"]},{number:2,status:"Ready",title:"t2",labels:["QA"]}]' '{}'
assert 'qa cards must not pre-flight' '[.calls[] | select(startswith("preflight-"))] | length == 0'
assert 'qa cards must not build' '[.calls[] | select(startswith("builder-"))] | length == 0'
assert 'qa Ready cards go to QA' '(.calls | index("tester-1") != null) and (.calls | index("tester-2") != null)'
assert 'the Tester must be told to move a qa card Ready → QA' '.prompts["tester-1"] | test("Ready → QA")'

# 9 — bug, feature and no label all build; the classifier keeps a label and labels a bare card.
gen '[{number:3,status:"Ready",title:"t3",lane:"build",labels:["bug"]},{number:4,status:"Ready",title:"t4"}]' \
    '{"3":{verdict:"proceed",detail:"ok"},"4":{verdict:"proceed",detail:"ok"}}'
assert 'bug and unlabelled cards build' '(.calls | index("builder-3") != null) and (.calls | index("builder-4") != null)'
assert 'classifier must keep the bug label' '.prompts["classifier-3"] | contains("label says \"bug\"")'
assert 'classifier must label a bare card feature or bug, never qa' \
  '(.prompts["classifier-4"] | contains("--add-label")) and (.prompts["classifier-4"] | contains("never qa"))'

# 10 — a stale caller passing the removed qa-only variant is refused, not guessed.
{
  printf "const args = { configPath: 'c.json', variant: 'qa-only', cards: [{number:1,status:'Ready',title:'t'}] }\n"
  cat <<'PRE'
const agent = (name: string, _persona?: unknown) => ({
  ask: async <T>(_prompt: string): Promise<T> => ({}) as unknown as T,
})
const log = (_m: string): void => {}
const phase = (_n: string): void => {}
const report = (_i: unknown, _t?: string): void => {}
const artifact = { board: (_i: string, _s: unknown): void => {} }
async function main() {
PRE
  cat ../workflows/super-board-wave.js
  cat <<'POST'
}
await main();
console.log("variant must be refused — reached the end instead");
POST
} > "$TMP/variant.mts"
if node --experimental-strip-types "$TMP/variant.mts" > /dev/null 2>&1; then
  fail 'variant qa-only must be refused'
fi

echo "PASS: test-wave-preflight.sh (10 scenarios)"
