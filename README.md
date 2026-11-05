<div align="center">

<img src="docs/assets/logo.svg" width="88" height="88" alt="super-board kanban logo">

<h1>suber-super-board</h1>

<p><strong>super-board, plus the three best skill sets, reaching every agent CLI.</strong></p>

<p>
<img alt="Upstream" src="https://img.shields.io/badge/upstream-super--board%20v3.1.2-1f883d?style=flat-square">
<img alt="License" src="https://img.shields.io/badge/license-MIT-0969da?style=flat-square">
</p>

</div>

A fork-superset of [EricTechPro/super-board](https://github.com/EricTechPro/super-board) —
the autonomous GitHub-Project loop where you add task cards to `Ready` and the board drains
itself into merged PRs with evidence: 11 skills (8 you type, 3 the board runs), six guard
hooks, one merge gate — extended here with:

1. **Three vendored skill sets** you can onboard with: [mattpocock/skills](https://github.com/mattpocock/skills),
   [pstack](https://github.com/michael-denyer/pstack-claude) (Lauren Tan's stack, Claude port),
   and [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) — all pinned copies
   in [`skill-sets/`](skill-sets/), no network needed at install time.
2. **A lifecycle map**: every set is mapped onto Plan · Design · Build · Test · Deploy · Maintain
   in [`skill-sets/registry.json`](skill-sets/registry.json); onboard writes the chosen mapping
   into your `AGENTS.md` and `.claude/super-board/skill-map.json`.
3. **Multi-agent install**: skills land in the agent-neutral `.agents/skills/`, and Claude,
   Codex, OpenCode, ZCode, Copilot or any other CLI gets the right wiring (see the matrix below).
4. **Onboard parameters**: pick the skill set and the agents as flags instead of wizard answers.

Everything upstream is unchanged otherwise — provenance and pins: [UPSTREAM.md](UPSTREAM.md).

**New here?** [docs/GUIDE.md](docs/GUIDE.md) is the end-to-end usage guideline: prerequisites → install → onboard → drain the board → human gates → recovery → troubleshooting.

## Install

One command, in your project folder:

```bash
curl -fsSL https://raw.githubusercontent.com/vuquangkhtn/suber-super-board/main/get.sh | bash
```

Flags (passed to `install.sh`): `--sets=mattpocock,pstack,agent-skills` (default: all three, in
registry order — pass a shorter list for a lean picker), `--hosts=claude,codex,opencode,copilot,zcode,other`,
plus upstream's `--no-hooks`, `--protect-main`, `--no-helper-skills`, `--target <dir>`, `--ref <tag>`.

Then onboard:

```
/super-board onboard                                   # interactive wizard
/super-board onboard --set=pstack --agents=claude,codex
```

Onboard takes one set: `--set=pstack` (`--sets` is a deprecated alias) — install.sh's `--sets=a,b`
is the comma list.

## The onboard wizard (10 steps)

Checks · **Skills** · **Agents** · GitHub · Board · Branch · AGENTS.md · Policies · Bug sources ·
Review. Enter takes the recommended answer; it resumes if interrupted.

- **🧩 Skills (step 2)** — pick one set: `mattpocock` (27 skills: grilling, specs, TDD, PRs,
  retros) / `pstack` (65: architect, arena, interrogate, blast-radius…) / `agent-skills` (25:
  spec-driven, security, shipping…) / **custom** — one question per lifecycle step
  (Plan / Design / Build / Test / Deploy / Maintain), each asking which set covers it. A step
  whose set has no skills (pstack → Maintain) falls back to the board's own loop.
- **🤖 Agents (step 3)** — multi-select which CLIs the skills must reach; installed CLIs are
  preselected. `claude` is always on; copilot and "other" agents get `AGENTS.md` pass-through notes.

## Use the board

The daily loop, in the project you installed into. super-board has five verbs:
`onboard` · `lint` · `status` · `run` · `stop` (in Codex they are `$super-board <verb>`).

1. **File tickets** — one issue per task in the card format: Problem · Context ·
   Fix · Acceptance Criteria · Risk · Blocked by
   ([docs/agents/issue-tracker.md](docs/agents/issue-tracker.md)). Lint refuses
   tickets without acceptance criteria.
2. **Lint** — `/super-board lint` walks the active-pipeline issues, flags vague
   ACs, and runs pre-flight readiness before anything is built.
3. **Ready** — move the cards you want drained to the `Ready` column. Labels
   route them: `qa` skips Building; `bug`, `feature` or no label are built first.
4. **Run** — `/super-board run` plans waves and hands each card to Build → QA →
   Review lane agents in their own worktrees, merging what passes the merge gate.
   Tier: `--low`, default medium, `--high`; `--codex` runs the lanes on Codex.
5. **Unblock** — cards stop with a 🙋 comment instead of merging when the merge
   gate needs a human: money, auth, destructive schema, live-DB migrations, or a
   PR over 400 changed lines. Answer on the issue, then `run` again.
6. **Watch or stop** — `/super-board status` is a read-only snapshot;
   `/super-board stop` shuts down gracefully mid-flight. State lives on the
   GitHub Project board, never in a session — the next `run` resumes where the
   board says.

Side doors while the board is idle:

| Skill | Use it for |
|---|---|
| [`/super-collect`](skills/super-collect/README.md) | Turn Sentry, PostHog, issues or PRs into verified Backlog cards. |
| [`/ui-refine-loop`](skills/ui-refine-loop/README.md) | Human-driven critique → refine polish of one page or component. |
| [`/git-sync`](skills/git-sync/README.md) | Commit per logical change, merge-pull, push without force. |
| [`/visual`](skills/visual/README.md) | A one-off diagram or explainer page. |

## Skill-set → lifecycle mapping

Each set's default mapping (curated; pstack's comes straight from the
[pstack map](https://erictechpro.github.io/super-board/pstack/)) lives in
[`skill-sets/registry.json`](skill-sets/registry.json):

| Step | mattpocock | pstack | agent-skills |
|---|---|---|---|
| Plan | research, grilling, to-questionnaire, to-tickets, wayfinder | how, why, teach, figure-it-out, show-me-your-work | interview-me, idea-refine, spec-driven-development, constraint-driven-development, planning-and-task-breakdown |
| Design | codebase-design, domain-modeling, to-spec | architect, arena, interrogate | api-and-interface-design, frontend-ui-engineering |
| Build | implement, implement-spec, tdd, prototype, wizard | tdd, typescript-best-practices, deslop, no-comments | incremental-implementation, test-driven-development, context-engineering, source-driven-development, doubt-driven-development |
| Test | diagnosing-bugs, triage, wait-what, code-review | create-verification-skill, swarm, blast-radius, benchmark-checklist, interrogate, thermo-nuclear-code-quality-review | browser-testing-with-devtools, debugging-and-error-recovery, code-review-and-quality, security-and-hardening, performance-optimization, code-simplification |
| Deploy | pr, handoff | make-pr-easy-to-review, babysit, fix-merge-conflicts, get-pr-comments, fix-ci | git-workflow-and-versioning, ci-cd-and-automation, shipping-and-launch |
| Maintain | retro, teach, improve-codebase-architecture, writing-for-agents | — (super-board loop covers it) | deprecation-and-migration, documentation-and-adrs, observability-and-instrumentation |

Skill-name collisions across sets (e.g. `tdd` in mattpocock *and* pstack) install once — the
first set in your `--sets` list wins (the default order is registry order — mattpocock,
pstack, agent-skills — so `tdd` and `teach` resolve to mattpocock); the record in
`.agents/skill-sets.json` notes the skips.

## Agent support

| Agent | How skills are reached |
|---|---|
| Claude Code | Board pack in `.claude/`; set skills symlinked `.claude/skills/<name>` → `.agents/skills/<name>` — slash commands work |
| Codex | reads `.agents/skills/` (symlinks followed); type `$skill-name` |
| OpenCode | reads `.agents/skills/` natively |
| ZCode | reads `.agents/skills/` natively |
| Copilot | no skill loader — the `AGENTS.md` skill-map block maps each step to its skills |
| other | same pass-through as Copilot; name it in onboard's "Other" box |

## The board itself

Unchanged from upstream: `/super-board run <slug>` plans waves, runs the Build → QA → Review
lanes (worktrees, draft PRs, evidence, merge gate with `verify_commands`), six guard hooks,
`/super-collect` for Sentry/PostHog/issues/PRs, `/ui-refine-loop`, `/visual`, `/git-sync`,
`/skill-set-add` to vendor a new skill set (pack repo only).
See upstream's docs in `docs/` and `skills/*/README.md`. Its own 11 skills (8 you type, 3 the board runs):

<!-- skills:start -->
**You type — 8 skills**

| Skill | What it does |
|---|---|
| [`/super-board`](skills/super-board/README.md) | Orchestrator: plans waves, runs Build → QA → Review, merges when green. |
| [`/super-collect`](skills/super-collect/README.md) | Finds problems (Sentry, PostHog, issues, PRs, architecture) and files verified Backlog cards. |
| [`/super-plan`](skills/super-plan/README.md) | Turns a request into approved board cards by conducting the mapped plan/design skills. |
| [`/ui-refine-loop`](skills/ui-refine-loop/README.md) | Critique → refine loop that polishes one page or component. |
| [`/visual`](skills/visual/README.md) | One HTML page: branch recap, plan, or codebase map with diagrams. |
| [`/git-sync`](skills/git-sync/README.md) | Commit per logical change, merge-pull, push without force, report. |
| [`/skill-set-add`](skills/skill-set-add/README.md) | Vendors a GitHub skill repo into skill-sets/ + registry.json, licenses carried, validated. |
| [`/skill-set-sync`](skills/skill-set-sync/README.md) | Syncs a vendored skill set from upstream: store, registry pin, UPSTREAM.md, removals flagged, validated. |

**The board runs — 3 lanes**

| Skill | What it does |
|---|---|
| [`/super-build`](skills/super-build/README.md) | Builder lane: worktree, smallest safe change, tests, draft PR. |
| [`/super-qa`](skills/super-qa/README.md) | Tester lane: evidence, test-gap check, screenshots, or bounce to Build. |
| [`/super-review`](skills/super-review/README.md) | Reviewer lane: own hypotheses, remembers prior findings, merge gate. |
<!-- skills:end -->

Each name links to that skill's README. Adding a skill? Write its `SKILL.md` and `README.md`,
add a line to `skills/families.json`, and this table updates itself.

## Develop this repo

This is a skill pack, not an app. Layout: `skills/` the eleven board skills ·
`skill-sets/` vendored sets + `registry.json` · `hooks/` guard hooks ·
`workflows/` dynamic-workflow definitions · `scripts/` dispatcher and guard
tooling · `tests/` the offline suite · `docs/` upstream and agent docs.

| Change | How |
|---|---|
| Run the checks | `bash tests/run-safety.sh` (offline suite; a pushed `v*` tag runs the same checks before publishing). |
| Add a skill | Write `skills/<name>/SKILL.md` + `README.md`, add a line to `skills/families.json`, then run the sync below. |
| Update the README skill tables | `python3 scripts/super-board-readme-sync.py` — generated from SKILL.md frontmatter and `skills/families.json`; never hand-edit between the `<!-- skills:start -->` / `<!-- skills:end -->` markers. |
| Vendor a new skill set | `/skill-set-add` in this repo only — pins the repo into `skill-sets/`, extends `registry.json`, carries licenses. |
| Change the board shape | Columns and label routing live in `scripts/super-board-wave-plan.sh`, `workflows/super-board-wave.js` and `skills/super-board/references/run.md` — change all three together. |
| Change a writing format | `skills/super-board/references/writing-standard.md` first, then the templates and `tests/test_writing_format.py`. |
| Release | [RELEASING.md](RELEASING.md); publish only if the tag checks pass. |
| Sync upstream | [UPSTREAM.md](UPSTREAM.md); merge via the `upstream` remote, pins recorded there. |

Agent-facing behavior lives in [AGENTS.md](AGENTS.md); its managed
`<!-- super-board:begin … -->` blocks are rewritten on upgrade, so edit only
outside the markers.

## Credits

- [EricTechPro/super-board](https://github.com/EricTechPro/super-board) v3.1.2 (MIT © Eric Tech) — the board. Merged with full history; sync via the `upstream` remote.
- [mattpocock/skills](https://github.com/mattpocock/skills) (MIT) — 27 skills.
- [pstack](https://github.com/cursor/plugins/tree/main/pstack) by Lauren Tan (MIT) and its port [pstack-claude](https://github.com/michael-denyer/pstack-claude) (MIT © Michael Denyer) — 66 skills; NOTICE files preserved.
- [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) (MIT © Addy Osmani) — 25 skills + shared checklists.

All licenses: [LICENSE](LICENSE) (upstream) and [skill-sets/](skill-sets/); pins and notices: [UPSTREAM.md](UPSTREAM.md).
