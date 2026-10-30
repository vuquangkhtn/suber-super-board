# PROJECT.md — suber-super-board

Context for board workers: what this repo is, where things live, how to verify.

## What this is

A fork-superset of [EricTechPro/super-board](https://github.com/EricTechPro/super-board)
v3.1.2 — an autonomous GitHub-Project build → QA → review loop — extended with three
vendored skill sets (mattpocock, pstack, agent-skills) and multi-agent install
(claude / codex / opencode / copilot / zcode / other). Upstream provenance, pins, and the
list of forked files: [UPSTREAM.md](../../UPSTREAM.md).

## Where things live

| Path | What it is |
|---|---|
| `skills/` | The board's own 8 skills (5 you type, 3 lanes) + `families.json` |
| `scripts/` | `super-board-*.py/.sh` helpers; `super-board-setup.py` is onboard's deterministic half |
| `hooks/` | Six guard hooks + settings snippets |
| `workflows/` | `super-board-wave.js`, `ui-refine-loop.js` |
| `skill-sets/` | Vendored sets + `registry.json` (step → skills mapping, the single source of truth) |
| `tests/` | 51 offline suites; `run-safety.sh` runs them all |
| `evals/` | Paid/online evals (offline in CI is `run-safety.sh`) |

Layout contract for a target project: `.claude/{skills,bin,workflows,hooks}` +
agent-neutral `.agents/skills/` (record: `.agents/skill-sets.json`).

## Commands

- Verify: `bash tests/run-safety.sh` (the only merge gate command — must pass)
- Board checks: `python3 .claude/bin/super-board-setup.py check --text`
- README skill tables: `python3 scripts/super-board-readme-sync.py` (auto-run by hook)

## Conventions

- Commit format `<emoji> [type] scope: subject` — see the writing standard
  (`skills/super-board/references/writing-standard.md`).
- Tickets follow `docs/agents/issue-tracker.md`.
- Change skill-set mappings in `skill-sets/registry.json`, never in prose; run
  `tests/test-registry.sh` after editing.
- Keep upstream files' behavior intact unless the change is one of the documented fork
  deltas in [UPSTREAM.md](../../UPSTREAM.md) — future `git fetch upstream && git merge
  upstream/main` must stay reasonably clean.

## Boundaries

- ALWAYS run `bash tests/run-safety.sh` before declaring done.
- NEVER edit files under `skill-sets/{mattpocock,pstack,agent-skills}/` except to bump a
  pinned upstream copy (record the new SHA in `registry.json` + `UPSTREAM.md`).
- NEVER clobber `.agents/skills/<name>` that the install record doesn't own.
- Ask first before: changing board lane behavior (super-build/qa/review SKILL.md),
  touching `get.sh`/`install.sh` output contracts, or adding a 4th skill set.
