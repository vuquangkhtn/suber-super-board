#!/usr/bin/env bash
# Offline workflow boundary: a read halt ends queued lane chains and the wave.
#
# The wave script is TypeScript (ZCode dynamic-workflow facade: agent(name).ask,
# no injected pipeline). Each scenario splices the body into a generated .mts
# module — facade stubbed at module scope, body inside async main() — and runs
# it with node --experimental-strip-types. Halting a lane stops that card's own
# chain and everything queued after it; lanes already in flight may still return.
set -euo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

gen() { # gen <failAt> — one scenario, result in $TMP/out.json
  {
    printf 'const failAt = "%s"\n' "$1"
    cat <<'PRE'
const calls: string[] = []
const args = { configPath: 'fixture.json', cards: [1, 2].map((n) => ({ number: n, title: 'Task', status: 'Ready' })) }
function replyFor(name: string): unknown {
  if (name.startsWith('preflight-')) {
    const nums = name.slice('preflight-'.length).split('-').map((s) => Number(s))
    return { verdicts: nums.map((n) => ({ number: n, verdict: failAt === 'preflight' ? 'halted' : 'proceed', detail: 'required GitHub read failed' })) }
  }
  if (name.startsWith('classifier-')) return { kind: 'feature', complexity: 'low', status: failAt === 'classify' ? 'halted' : 'ok' }
  const lane = name.startsWith('builder-') ? 'build' : name.startsWith('tester-') ? 'qa' : 'review'
  return { status: lane === failAt ? 'halted' : 'advanced', column: 'QA', detail: 'result' }
}
const agent = (name: string, _persona?: unknown) => ({
  ask: async <T>(_prompt: string): Promise<T> => {
    calls.push(name)
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
console.log(JSON.stringify({ calls, out }));
POST
  } > "$TMP/run.mts"
  node --experimental-strip-types "$TMP/run.mts" > "$TMP/out.json" 2> "$TMP/err.log" \
    || { cat "$TMP/err.log" >&2; exit 1; }
}

assert() { # assert <message> <jq filter>
  jq -e "$2" "$TMP/out.json" >/dev/null || { echo "FAIL: $1"; exit 1; }
}

for failed in preflight classify build qa; do
  gen "$failed"
  assert "$failed must halt the wave" '.out.halted == true'
  assert "$failed: every card must preserve its halt status" '[.out.cards[].finalStatus] | all(. == "halted")'
  case $failed in
    preflight|classify)
      assert "$failed: no lane agent dispatched" '[.calls[] | select(startswith("builder-") or startswith("tester-") or startswith("reviewer-"))] | length == 0' ;;
    build)
      assert "build halt: no downstream lane dispatched" '[.calls[] | select(startswith("tester-") or startswith("reviewer-"))] | length == 0' ;;
    qa)
      assert "qa halt: no review dispatched" '[.calls[] | select(startswith("reviewer-"))] | length == 0' ;;
  esac
done

gen never
assert "healthy wave must not halt" '.out.halted == false and ([.out.cards[].finalStatus] | all(. == "advanced"))'
assert "healthy wave ran all three lanes for both cards" \
  '([.calls[] | select(startswith("builder-"))] | length) == 2 and ([.calls[] | select(startswith("tester-"))] | length) == 2 and ([.calls[] | select(startswith("reviewer-"))] | length) == 2'

echo "PASS: workflow halt propagation (5 scenarios)"
