# super-board — agent-facing notes

This repo ships eight skills under `skills/`: five you type (`super-board`, `super-collect`,
`ui-refine-loop`, `visual`, `git-sync`) and three the board runs (the lane workers `super-build`, `super-qa`,
`super-review`). Architecture findings come from `/super-collect architecture`.
Worktree cleanup (`hooks/cleanup-wt.py`) is a hook, not a skill. README skill tables are generated
by `scripts/super-board-readme-sync.py` from SKILL.md frontmatter and `skills/families.json`.

## The cardinal rule

**`super-board` is an autonomous trader. The interactive Claude session that invokes `/super-board run` is an *orchestrator*, NOT a worker.** Its only jobs are:

1. Verify preconditions (clean git, no orphan workers, GraphQL quota, etc.).
2. Dispatch per the config's `worker_backend`:
   - `"workflow"` (default) — stay in-session and run the wave loop in `skills/super-board/references/run-workflow.md`: plan a wave, claim assignees, launch the `super-board-wave` dynamic workflow, reconcile, repeat. Lane agents inside the workflow do all product work.
   - `"claude-p"` (legacy, explicit opt-in only) — spawn the headless runner `nohup .claude/bin/super-board-run.sh <slug> &`, report PID + log path, exit. The runner refuses to start (exit 78) unless the config sets this value.
3. Report back to the user (dispatch confirmation, or one status line per wave).

The orchestrator MUST NOT:

- Build, test, review, or fix issues itself. All product work is delegated to workflow lane agents (or `claude -p` workers on the legacy backend).
- Patch the dispatcher script or skill files mid-run, even if it sees a problem. Capture the symptom and tell the user; wait for explicit approval.
- Wait on individual workers or relay their work. They write their evidence back to the GitHub issue + PR. The orchestrator's user-facing output is the dispatch confirmation (claude-p) or one short report per wave (workflow), not the run result.
- Hold context for multi-card progress. State lives on the GitHub Project board + the inflight lockfiles, not in the orchestrator's session.

If a problem surfaces during the run, the orchestrator's reply is: "I saw X. Want me to dig in or stop the runner?" — not "I went ahead and fixed it."

## Worker rules

Workers (`super-build`, `super-qa`, `super-review`) share the dispatcher's `gh` token bucket. They MUST:

- Required GitHub reads use `.claude/bin/super-board-github-read.py`; exit 79 stops the run.
- Check its `--check` before GitHub writes, migrations, merges, and new dispatch; preserve work when halted.
- Source `.claude/bin/super-board-gh-guard.sh` (`scripts/` in this repo) at worker start.
- Call `sb_gh_guard_check 200` before any burst of `gh` calls.
- Prefer local `git blame` / `git log` over `gh api graphql` for any sub-agent that doesn't need fresh state.
- Cap adversarial sub-agents at 50 gh calls each. If a sub-agent runs out, it returns `confidence: insufficient_data` rather than burning the shared quota.
- Append `gh-quota-on-exit: graphql=<n>/5000 rest=<n>/5000` to the PR handoff comment.

See `skills/super-board/references/rate-limit-etiquette.md` for the full discipline.

## Installation contract

`install.sh [--no-hooks] [--protect-main] <target>` copies the pack into the target project's `.claude/` tree:

```
.claude/
├── skills/<all eight>/...
├── hooks/guard-*.py, cleanup-wt.py   (wired into settings.json; --no-hooks skips)
├── workflows/super-board-wave.js, ui-refine-loop.js
└── bin/super-board-*.sh (incl. pr-body), super-board-*.py (status, merge-policy, agents-md, settings, setup), super-qa-file-bug.sh, super-review-file-refactor.sh
```

It also refreshes the managed `<!-- super-board:begin … -->` block in the target's AGENTS.md when
one exists (nothing outside the markers), records an older install in
`.claude/super-board/upgrade.json`, prints grouped emoji output, and asks nothing:
`super-board onboard` asks the questions. Onboard's 🔍 Checks (`scripts/super-board-setup.py`)
fixes must-haves and finishes upgrades with no question.

## Board shape (v3.0.0)

Columns are always Backlog · Ready · Building · QA · Review · Blocked · Done — no Skipped, no
per-board `variant`. Labels `qa` · `bug` · `feature` route cards: `qa` skips Building, everything
else (and no label) is built. Change routing in `scripts/super-board-wave-plan.sh`,
`workflows/super-board-wave.js` and `run.md` → "Lanes and label routing" together.

Skills call the dispatcher scripts as `.claude/bin/<script>`.

## Writing

Commits, PR bodies, tickets and comments in this repo follow
`skills/super-board/references/writing-standard.md`, the same standard super-board writes into
every project it is installed in.

| Thing | Format |
|---|---|
| Commit | `<emoji> [type] scope: subject` + short bullets (✨ feat · 🐛 fix · 🔧 chore · ♻️ refactor · 🧪 test · ⚡ perf · 📝 docs · 👷 ci · 💄 ui · 🔒 security · ⏪ revert · 🚧 wip) |
| PR body | marker blocks, one owner each: status · problem · solution · ac · history · visual · risk |
| Ticket | Problem · Context · Fix · Acceptance Criteria · Risk · Blocked by (+ Evidence for bugs) |
| Comment | `[role] [label] status` · Did · ✅ Done · ❌ Not done · Next · ≤ 8 lines |
| PR author notes | Purpose · What changed · Why it matters, in native file/inline review comments; follow `skills/super-board/references/pr-author-notes.md` |

- NEVER rewrite a whole PR body: `scripts/super-board-pr-body.sh` rewrites one block.
- ALWAYS change a format in `writing-standard.md` first, then the templates and `tests/test_writing_format.py`.

## Release checks

Run `bash tests/run-safety.sh` for the offline suite. A pushed `v*` tag runs the same checks
on Linux/macOS plus status-reader smoke checks, then publishes only if they pass. Follow
[RELEASING.md](RELEASING.md); it also lists the settings needed to limit manual bypass.

<!-- super-board:begin v3.1.2 (managed; edits inside are overwritten on upgrade) -->
## Super Board

Board: Backlog · Ready · Building · QA · Review · Blocked · Done. Labels route: `qa` skips Building · `bug`, `feature`, none → built first.

| When | Use | NEVER |
|---|---|---|
| Set up / repair the board | `/super-board onboard` | DON'T hand-edit config mid-run |
| Check tickets before a run | `/super-board lint` | NEVER run with AC-less tickets |
| Drain the board | `/super-board run` | NEVER build, test or merge from the orchestrator |
| Board state / halt | `/super-board status` · `/super-board stop` | |
| Build one ticket | `/super-build` | NEVER build outside the card's worktree |
| QA a branch, or a live URL alone | `/super-qa` · `/super-qa <url>` | NEVER mark QA pass without evidence |
| Review a PR, merge | `/super-review` | NEVER `gh pr merge` direct — merge gate only |
| File bugs from Sentry, PostHog, PRs | `/super-collect` | DON'T file without a verifier pass |
| UI polish | `/ui-refine-loop` (human runs it) | board NEVER runs it |
| Diagram / explainer page | `/visual` | |
| Commit, pull, push this branch | `/git-sync` | NEVER force push or rebase shared history |

| Rule | Value |
|---|---|
| Config | `.claude/super-board/configs/<slug>.json` |
| Isolation | 1 card · 1 worktree · 1 branch |
| Merge | auto for normal changes · money, auth, destructive schema (DROP/TRUNCATE/RENAME) → human · PR > 400 changed lines → human |
| Migrations | additive → robot migrates allowed DBs only · live DB ALWAYS → 🙋 needs you |
| Blocked card | block-template comment · last line `blocked-by:` · 🙋 = needs you |
| Secrets | NEVER read `.env`; key names via `.claude/bin/super-board-env-check.sh` |

## Writing (super-board)

| Thing | Format → `.claude/skills/super-board/references/writing-standard.md` |
|---|---|
| Commit, PR title | `<emoji> [type] scope: subject` + short bullets · ✨ feat 🐛 fix 🔧 chore ♻️ refactor 🧪 test 📝 docs |
| PR body | blocks: status · Problem · Solution · AC + proof · history · Before\|After · Risk — `super-board-pr-body.sh` |
| Ticket | Problem · Context · Fix · AC · Risk · Blocked by → `docs/agents/issue-tracker.md` |
| Comment | `[role] [label] status` · Did · ✅ Done · ❌ Not done · Next · ≤ 8 lines |
| PR author notes | file + critical inline review comments: Purpose · What changed · Why it matters → `pr-author-notes.md` |

- NEVER chain steps with arrows. One step per line, lettered under Where.
- NEVER link screenshots. Embed a raw URL pinned to a sha.
- DON'T repeat file lists in status comments. DON'T write "Not verified" or "Next" in a PR body.
<!-- super-board:end -->

<!-- super-board:skill-map begin (managed) -->
## Skill sets & lifecycle map

Which vendored skill set serves each lifecycle step, and how each agent reaches a skill.

Skill set: **pstack** — pstack (Claude port) (source: https://github.com/michael-denyer/pstack-claude, pinned: 190fc9a009491cbcfc04e25ef5b3c2d1fcf5ca8a).

Machine-readable map: `.claude/super-board/skill-map.json` · install record: `.agents/skill-sets.json`.

| Step | Set | Skills |
|---|---|---|
| Plan | pstack | how, why, figure-it-out, show-me-your-work |
| Design | pstack | architect, arena, interrogate |
| Build | pstack | typescript-best-practices, deslop, no-comments |
| Test | pstack | create-verification-skill, swarm, blast-radius, benchmark-checklist, interrogate, thermo-nuclear-code-quality-review |
| Deploy | pstack | make-pr-easy-to-review, babysit, fix-merge-conflicts, get-pr-comments, fix-ci |
| Maintain | pstack | — |

pstack has no Maintain skills; super-board's own loop (super-collect, calibration) covers it.

pstack anytime skills: poteto-mode, setup-pstack, poteto-help, recall, ketchup, ketchup-video, bro, what-did-i-get-done, in-your-own-words, technical-writing, unslop, sharpen, statechart, thermos, thermo-nuclear-review, reflect, correct, automate-me, maintain-verification-skill, create-formal-verification-skill, maintain-formal-verification-skill, principle-attack-the-premise, principle-boundary-discipline, principle-build-the-lever, principle-encode-lessons-in-structure, principle-exhaust-the-design-space, principle-experience-first, principle-explain-the-number, principle-fix-root-causes, principle-foundational-thinking, principle-guard-the-context-window, principle-laziness-protocol, principle-make-operations-idempotent, principle-migrate-callers-then-delete-legacy-apis, principle-minimize-reader-load, principle-model-the-domain, principle-never-block-on-the-human, principle-outcome-oriented-execution, principle-prove-it-works, principle-redesign-from-first-principles, principle-separate-before-serializing-shared-state, principle-sequence-verifiable-units, principle-subtract-before-you-add, principle-test-behavior-not-implementation, principle-type-system-discipline

Agents: slash commands (`/tdd`) and the Skill tool, from .claude/skills; reads .agents/skills natively.
<!-- super-board:skill-map end -->
