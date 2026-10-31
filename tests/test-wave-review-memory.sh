#!/usr/bin/env bash
# Tests the review-memory wiring in workflows/super-board-wave.js. No gh calls:
# the TypeScript wave body is spliced into a generated .mts module with the
# facade stubbed (agent(name).ask, phase/report/artifact no-ops) and run with
# node --experimental-strip-types.
#
# The wave script is a workflow body (top-level await + return), not a module.
# The strip-types run inside each generated wrapper is also its syntax check.
set -euo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

gen() { # gen <cards-json> <review-reply-json> — result in $TMP/out.json
  {
    printf 'const args = { configPath: %s, cards: %s }\n' "'c.json'" "$1"
    printf 'const reviewReply: unknown = %s\n' "$2"
    cat <<'PRE'
const prompts: Record<string, string> = {}
function replyFor(name: string): unknown {
  if (name.startsWith('preflight-')) return { verdicts: [{ number: 7, verdict: 'proceed', detail: 'clean' }] }
  if (name.startsWith('classifier-')) return { kind: 'feature', complexity: 'low' }
  if (name.startsWith('reviewer-')) return reviewReply
  return { status: 'advanced', column: 'next', detail: 'ok' }
}
const agent = (name: string, _persona?: unknown) => ({
  ask: async <T>(prompt: string): Promise<T> => {
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
console.log(JSON.stringify({ prompts, out }));
POST
  } > "$TMP/run.mts"
  node --experimental-strip-types "$TMP/run.mts" > "$TMP/out.json" 2> "$TMP/err.log" \
    || { cat "$TMP/err.log" >&2; exit 1; }
}

assert() { # assert <message> <jq filter>
  jq -e "$2" "$TMP/out.json" >/dev/null || { echo "FAIL: $1"; exit 1; }
}
fail() { echo "FAIL: $1"; exit 1; }

# 1 — the Review lane is told to load prior_report by its marker; other lanes are not.
gen '[{number:7,status:"Ready",title:"t"}]' '{status:"advanced",column:"Done",detail:"ok"}'
RP='.prompts["reviewer-7"]'
assert 'review lane did not run' "$RP | length > 0"
assert 'review prompt must name the report marker' "$RP | contains(\"<!-- super-review:report -->\")"
assert 'review prompt must ask for prior_report' "$RP | contains(\"prior_report\")"
assert 'review prompt must name the three round-1 verdicts' "$RP | test(\"fixed / not fixed / no longer applies\")"
assert 'review prompt must put the independent pass before the builder summary' "$RP | test(\"before the builder's PR summary\")"
assert 'review prompt must name the finding classes' "$RP | test(\"Gap / Bug / Verification miss / Scope drift / Over-engineering\")"
assert 'review prompt must run ponytail-review' "$RP | contains(\"ponytail:ponytail-review\")"
assert 'review prompt must say Over-engineering never blocks alone' "$RP | test(\"never blocks merge alone\")"
assert 'review prompt must use the fixed truth-check brief' "$RP | test(\"fixed brief from super-review\")"
assert 'review prompt must re-apply the Over-engineering rule after the truth-check' "$RP | test(\"reclass any Over-engineering Blocker to Should fix\")"
for LANE in builder-7 tester-7; do
  assert "$LANE must not get the review pass" ".prompts[\"$LANE\"] | contains(\"ponytail-review\") | not"
  assert "$LANE must not get review memory" ".prompts[\"$LANE\"] | contains(\"super-review:report\") | not"
done
# 1b — ui-refine-loop is standalone: no lane prompt mentions it.
for LANE in builder-7 tester-7 reviewer-7; do
  assert "$LANE must not trigger ui-refine-loop" ".prompts[\"$LANE\"] | test(\"ui-refine-loop|qa-hook\") | not"
done

# 2 — a re-review bounce surfaces round-1 counts in the wave summary.
gen '[{number:9,status:"Review",title:"t"}]' \
    '{status:"bounced",column:"Ready",detail:"1 prior finding not fixed",priorFindings:{fixed:2,notFixed:1,noLongerApplies:0}}'
assert 'expected bounced' '.out.cards[0].finalStatus == "bounced"'
assert 'summary must carry priorFindings' '.out.cards[0].priorFindings.notFixed == 1'

# 3 — a first review (no prior report) reports null, not a fabricated count.
gen '[{number:11,status:"Review",title:"t"}]' '{status:"advanced",column:"Done",detail:"merged"}'
assert 'first review must report priorFindings: null' '.out.cards[0].priorFindings == null'

echo "PASS: test-wave-review-memory.sh (3 scenarios)"
