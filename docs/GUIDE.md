# super-board — end-to-end usage guideline

One path from empty project to drained board: install → onboard → tickets → run → human
gates → recovery. Every command here is copy-pasteable. The per-verb contracts live in
`skills/super-board/references/` (`onboard.md`, `lint.md`, `run.md`, `run-workflow.md`,
`status.md`, `stop.md`) — this guide points at them instead of restating them.

Audiences: someone **adopting the pack** in their own project (§1–§7), and a **contributor
working on this repo itself** (§8–§11, including its dogfood quirks).

## 1. Prerequisites

| Need | Why | Check / install |
|---|---|---|
| git | worktrees, branches | `git --version` |
| gh CLI, authed | boards, issues, PRs | `gh auth status`; scopes via `gh auth refresh -s project,read:project,repo` |
| python3 | installer + every helper script | `python3 --version` |
| Node.js + npx | workflow backend (`node --check` on the wave script) and helper skills | `node --version`; onboard's 🔍 Checks offers `brew install node` |
| curl + tar (or git) | fetching the pack | `curl --version` |
| jq | GH guard + tests | `jq --version` |

The one-line installer prints a grouped ✓/✗ check of `curl tar git python3 gh jq node` and
says which missing tools onboard's 🔍 Checks installs later (`get.sh:70-81`). Only
curl+tar (or git) and python3 are hard requirements at install time (`get.sh:63-68`).

## 2. Install

One command, in your project folder:

```bash
curl -fsSL https://raw.githubusercontent.com/vuquangkhtn/suber-super-board/main/get.sh | bash
```

| Flag | Meaning |
|---|---|
| `--sets=mattpocock,pstack,agent-skills` | comma list of vendored skill sets (default `mattpocock`) |
| `--hosts=claude,codex,opencode,copilot,zcode,other` | agent CLIs to wire; `claude` is always on; unknown value exits 64 |
| `--no-hooks` | skip the six guard hooks, leave `settings.json` untouched |
| `--protect-main` | also wire the push guard that blocks direct/force pushes to main |
| `--no-helper-skills` | install no skill sets at all |
| `--target <dir>` · `--ref <tag\|branch>` | get.sh only: install elsewhere / pin a version |

`get.sh` downloads the pack, runs `install.sh`, and prints the summary. From a checkout,
skip the download and run the installer directly:

```bash
./install.sh [--no-hooks] [--protect-main] [--sets=...] [--hosts=...] [target]
```

What lands: the board pack in `.claude/{skills,bin,workflows,hooks}`; vendored set skills in
the agent-neutral `.agents/skills/` with the record `.agents/skill-sets.json`; an older
install recorded in `.claude/super-board/upgrade.json` (onboard finishes upgrades). The
installer asks nothing — onboard asks the questions (`install.sh:12-13`).

**`--sets` vs `--set`:** `install.sh`/`get.sh` take the comma list `--sets=a,b`. Onboard's
own parameter is the single value `--set=<one set>` (`--sets` works there only as a
deprecated alias). See §3 and §9.

## 3. Onboard

`/super-board onboard` runs the 10-step wizard in the current Claude Code session. Enter
takes the recommended answer.

| # | Step | Asks about |
|---|---|---|
| 1 | 🔍 Checks | system tools and sign-ins only (through Claude Code's own permission prompt) |
| 2 | 🧩 Skills | which vendored set guides the six lifecycle steps (§9) |
| 3 | 🤖 Agents | which agent CLIs the skills must reach |
| 4 | 🔑 GitHub | sign-in, scopes, optional second (bot) account |
| 5 | 🗂️ Board | reuse + repair, or create the project board |
| 6 | 🌿 Branch | merge target (create `staging`, or `main`) |
| 7 | 📜 AGENTS.md | merge CLAUDE.md rules into one AGENTS.md; CLAUDE.md becomes `@AGENTS.md` |
| 8 | 🛡️ Policies | who merges, push guard, which databases the robot may migrate |
| 9 | 📥 Bug sources | Sentry / PostHog / GitHub issues / past PRs / architecture / custom |
| 10 | ✅ Review | confirm, then write everything once |

**Fixed silently vs asked.** Must-haves (skills, scripts, workflows, hooks, settings
entries, old folders, config keys, labels, columns) are repaired with **no question** and
listed under "Fixed for you", backed up to `.claude/super-board/backup/<ts>/` first. Only
system tools and sign-ins are asked (`onboard.md` → "Design rules", "Fix, don't ask").
Repo files change only at step 10, after "Write everything".

**Parameters.** `/super-board onboard --set=pstack --agents=claude,codex` pre-answers
steps 2–3; their steps still run their silent halves (detect, install, wiring).
`--set=custom` still asks the six per-step questions. A comma list at either spelling
(`--set=a,b`, `--sets=a,b`) halts with
`🛑 onboard takes one skill set — install.sh's --sets takes a comma list. Re-run with one
set, e.g. --set=pstack.` (`onboard.md:9-18`).

**Resume.** Every answer is saved to `.claude/super-board/onboard-answers.json` as you go;
a halt never loses work. Stop any time — re-running offers "Continue where you left off?".
Re-running on a finished setup offers Keep all (check and repair) / Edit an earlier answer /
Start over (`onboard.md` → "Resume", "Re-run on a finished setup").

## 4. Prepare tickets

```
/super-board lint
```

Lint walks the issues in Ready · Building · QA · Review, flags vague or missing
acceptance criteria, and writes `docs/super-board/pre-flight.md`. **Why ACs matter:** run
dispatches headless workers that cannot ask you questions — a vague issue gets
hallucinated, not clarified (the loop even refuses to start with AC-less tickets in the
active columns). Lint is also where you answer the flagged issues, while you are still in
the loop. Full contract: `references/lint.md`.

## 5. Drain the board

```
/super-board run <slug>          # slug printed by onboard; bare `run` uses the active config
```

The orchestrator loops: plan a wave (`super-board-wave-plan.sh`) → act on the wave-start
sweep → claim cards (assignee mutex) → launch the `super-board-wave` workflow → reconcile →
report. One short block per wave, outcome first:

```
Wave 3 · 5 cards → 2 merged · 1 bounced · 1 blocked · 1 failed · usage 5h 62%
  🛡 #15 Blocked 🔐 missing STRIPE_TEST_KEY — owner: Eric
  ❌ #18 failed: build lane returned no result — retried next wave
Next: wave 4 (3 cards)   |   ⏸ paused until 14:05   |   ✅ board drained
```

Every `blocked` card gets a line with its owner — that is the human's queue. Merged and
bounced cards are counts only. Never a "done" that is not on the base branch
(`run-workflow.md` → wave loop step 6).

Model ladder: `--low` (cheap cards cheap), default medium, `--high` (opus for every card);
`--codex [--low|--high]` or `--codex=<model>` runs every lane on headless Codex instead.

Watch it live and stop it:

```
python3 .claude/bin/super-board-status.py    # /super-board status — read-only snapshot: config, column counts, in-flight workers
/super-board stop                            # graceful shutdown: "stopped here" comments, claim release, workers killed
```

Stop is deliberately tolerant; branches, PRs and the board are untouched. **Resume = run
again** — there is no resume verb, the board is the state (`references/stop.md`).

## 6. Card lifecycle

Columns are always `Backlog · Ready · Building · QA · Review · Blocked · Done`. A card's
label picks its path:

| Label | Path |
|---|---|
| `feature` / `bug` / none | Ready → Building → QA → Review → Done |
| `qa` | Ready → QA → Review → Done (skips Building: tests what exists) |

One branch and one draft PR per issue (`issue-<N>-<kebab-title>`): the Builder builds in
`.claude/worktrees/issue-<N>-build/`, the Tester adds tests + evidence, the Reviewer —
the only lane that merges — squash-merges through the merge gate. **Done means merged** (or
closed as not planned on purpose): nothing reads the board correctly otherwise.

Merge gate exit codes, in plain words (`scripts/super-board-merge-gate.sh:68-92`):

| Exit | Plain words | Where the card goes |
|---|---|---|
| 0 | merged | Done |
| 2 | branch no longer builds against the current base | Review → **Ready**, `loop:rebase` (a rebase pass, not a human decision) |
| 3 | PR closed without a merge | per review flow |
| 4 | another merge held the lock too long | stays in Review, next wave retries |
| 5 | base does not merge in cleanly (real conflict) | Review → **Ready**, `loop:rebase` |
| 6 | PR head changed after review — evidence void | stays in Review for a fresh review |
| 7 | policy says a human merges (money, auth, destructive schema, PR > 400 lines, or `merge_policy.default: "human"`) | **Blocked** 🙋 (§7) |
| 8 | needs-you: a migration on a DB the robot may not touch, a failed migrate command, or a declared human step | **Blocked** 🙋 with exact commands (§7) |
| 79 | required GitHub evidence unavailable | halt (§8) |

## 7. Human gates (🙋)

A card reaches Blocked 🙋 when the next step is a command or decision the robot must not
make for you. Two shapes (`references/block-template.md`):

- **Merge policy hold (exit 7)** — the card is Blocked with a checklist:
  review and merge PR #<P> yourself, **or comment `done`** on its pinned approval request to
  approve; the next wave re-runs the gate and merges.
- **Needs-you commands (exit 8)** — the Block comment carries the exact commands, copied
  verbatim from the gate's `needs-you:` lines (a placeholder means the config has no command
  for that env — fill `migrations.commands.<env>` first).

**The approval-request / done flow.** The gate prints one `approval-request:` JSON line
that pins the PR head and the exact policy/human steps being confirmed. It is copied
verbatim into the canonical **issue** comment; the PR links to it without duplicating it.
Never edit a request after posting — post a new one when the code or question changes.
A human with current **write, maintain or admin** permission comments `done` after the
newest request, in the same thread. The planner verifies identity, permission, linked PR and
the current head, moves the card to `resume` → Review, and the Reviewer re-runs the gate —
which independently re-verifies everything before merging. Trust boundary: GitHub cannot
distinguish a person from an agent using their token; agents never write the `done` reply,
and bot accounts never count as human approval. If the PR head changed while Blocked, the
planner's `refreshApproval` sends it to Review for a fresh request — the new code is not
approved by the old `done`.

Every human block ends with `blocked-by: -` (nothing on the board clears it — only a person
does), while cards waiting on other cards carry `blocked-by: <issue numbers>` and are swept
back to Ready automatically when those close.

## 8. Halts and recovery

**What halts.** A required GitHub read failing three attempts (the read helper exits 79 —
invalid queries, auth and permission errors stop immediately), no card progressing for 3
ticks/waves, expired auth, a dirty tree or missing precondition on re-validation, a
production-merge guard hit, a destructive action, the user's time/budget window, or
`/super-board stop`.

**What is preserved.** Worktrees, branches, PRs, claims, card statuses, approval evidence —
everything. The halt marker (`.claude/super-board/github-halt.json`) records the failed
read, the attempt count and the reason; every archived record with its timestamp and
operation sits next to it as `github-halt-<id>.json` in `.claude/super-board/`.

**How recovery works.**

```
python3 .claude/bin/super-board-github-read.py --resume        # re-check the failed read, clear the marker, archive the reason
```

Fix access or the query first; a corrected read is supplied as `--resume --kind <shape> --
<gh args>`. Never retry a mutation blindly — confirm its remote outcome once service is
back, then archive explicitly. Then `resume` = run again (`/super-board run <slug>`, keep
any `--codex`/tier flags): the wave-start sweep returns Blocked-whose-blockers-closed and
stranded Building cards to Ready by themselves, and the planner re-picks from the board.
Cards are never moved to Done/Blocked through an unavailable API, and no automatic retries
are scheduled.

## 9. Skill sets

Three vendored sets ship in `skill-sets/` (pinned copies, no network at install time):
`mattpocock` (27 skills), `pstack` (66), `agent-skills` (25). `skill-sets/registry.json` is
the single source of truth for each set's step mapping.

| Question | Answer lives in |
|---|---|
| What is **installed** | `.agents/skills/` + the record `.agents/skill-sets.json` (per-set skills, skips, hosts — written by `install.sh`) |
| What is **mapped** | the `super-board:skill-map` block in AGENTS.md + `.claude/super-board/skill-map.json` (written by onboard step 10) |

Mixing sets per step: choose `custom` at onboard step 2 — one question per lifecycle step
(Plan · Design · Build · Test · Deploy · Maintain), or pre-stage a steps file and run
`--set=custom`. A set with no skills for a step is allowed; the map falls back to the
board's own loop (pstack → Maintain). Switching later, don't hand-edit:

```bash
python3 .claude/bin/super-board-setup.py sets <set|custom> [--steps FILE]
```

It drops the skills only the old set owns, installs the new choice, rewrites the config's
`skill_sets` and the skill map, and reports added/removed/skipped (`scripts/super-board-setup.py:14-19`).

Name collisions across sets (`tdd` exists in two) install once — the first set in your
`--sets` list wins, later ones are recorded as skipped in `.agents/skill-sets.json`.

## 10. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Run pauses, waves stall on quota | GraphQL is billed in points, not requests: a board read costs ~101–203 points, so 3 cards can spend ~2,850 of 5,000/hr | the guard sleeps to reset at <200 remaining and resumes by itself; after a wave that hit the limit, `max_workers` in the config steps down 3 → 2 → 1. Give the robot its own account (onboard step 4) for a separate budget. Price list: `references/rate-limit-etiquette.md` |
| Cards stuck in Building, nobody working | a crashed/stopped wave left claims and locks | next run's crash-recovery sweep releases leaked assignees and the planner returns stranded cards to Ready. Manual: `bash .claude/bin/super-board-stop.sh <slug>` |
| A wave refuses to start | stale `inflight/workflow-wave.lock` or live legacy dispatcher | verify no `super-board-run.sh` / super-board-wave process is alive, then remove the stale lock — never while one is running |
| `gh` calls fail or hit the wrong repo here | this repo has two remotes (`origin` = this fork, `upstream` = EricTechPro/super-board), so gh cannot infer the base repo | pass the repo explicitly: `gh issue view 10 -R vuquangkhtn/suber-super-board`. Same for `gh pr` commands. In target projects with one remote this is not needed |
| `{owner}/{repo}` placeholders in docs | REST paths are templates | substitute your `git remote get-url origin` values |
| Duplicate/ghost workers | cold-start race or crashed dispatcher | `pgrep -f 'claude -p .*super-board run'` must return zero before a run; the dispatcher's orphan scan + lane-zombie watchdog kill leftovers (`run.md` → anti-zombie addendum) |
| PR over ~400 changed lines parked in Blocked 🙋 | `merge_policy.auto_max_lines` (lockfiles/generated/snapshots/migration SQL excluded) | split into vertical slices (`/to-tickets`) |

## 11. Where things live

| Path | What it is |
|---|---|
| `.claude/super-board/configs/<slug>.json` | the board config (columns, merge policy, migrations, bot identity) |
| `.claude/super-board/active` | slug of the active config |
| `.claude/super-board/onboard-answers.json` | saved wizard answers (gitignored) |
| `.claude/super-board/github-halt*.json` | current + archived halt records |
| `.claude/super-board/inflight/` | per-worker PID locks + the workflow-wave lock |
| `.claude/{skills,bin,workflows,hooks}` | the board pack: skills, helper scripts, wave workflow, guard hooks |
| `.agents/skills/` + `.agents/skill-sets.json` | vendored set skills + install record |
| `.claude/super-board/skill-map.json` | machine-readable set → lifecycle-step map |
| `skills/super-board/references/` | per-verb contracts (onboard, lint, run, run-workflow, status, stop, rate-limit-etiquette, block-template, writing-standard) |
| `docs/super-board/` | `PROJECT.md`, `pre-flight.md`, run manifests and QA evidence in `runs/` |
| `docs/agents/issue-tracker.md` | the ticket format the lanes read |
| `skill-sets/registry.json` | vendored sets, pins, step mappings (source of truth) |
| `tests/` | offline suites; `bash tests/run-safety.sh` runs them all |
