# Upstream provenance

This repo is a superset of [EricTechPro/super-board](https://github.com/EricTechPro/super-board),
vendored with full git history (see the merge commit landing `22b974a` in our log;
`git remote -v` shows the pinned `upstream` remote). To sync future upstream work:

```bash
git fetch upstream main          # upstream remote → EricTechPro/super-board
git merge upstream/main          # conflicts stay inside the files we forked
```

| What | Source | Pinned at | License |
|---|---|---|---|
| super-board (skills, scripts, hooks, workflows, tests, evals, docs) | [EricTechPro/super-board](https://github.com/EricTechPro/super-board) | tag `v3.1.2` (commit `22b974a`), merged 2026-10-29 | MIT (kept in [LICENSE](LICENSE)) |
| mattpocock skills | [mattpocock/skills](https://github.com/mattpocock/skills) | vendored 2026-10-29 (repo commit `282a125`) | MIT ([skill-sets/mattpocock](skill-sets/mattpocock)) |
| pstack (Claude port) | [michael-denyer/pstack-claude](https://github.com/michael-denyer/pstack-claude) | `190fc9a009491cbcfc04e25ef5b3c2d1fcf5ca8a` | MIT + [LICENSE-cursor-team-kit](skill-sets/pstack/LICENSE-cursor-team-kit) + [LICENSE-thermos](skill-sets/pstack/LICENSE-thermos), see [NOTICE.md](skill-sets/pstack/NOTICE.md), [NOTICE-skills.md](skill-sets/pstack/NOTICE-skills.md). Original pstack © Lauren Tan ([cursor/plugins/pstack](https://github.com/cursor/plugins/tree/main/pstack)) |
| agent-skills | [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | `eb07f19f52c2669f2364897aaa293e2aaddd7b1c` | MIT ([skill-sets/agent-skills/LICENSE](skill-sets/agent-skills/LICENSE)) |

## What this fork changes (upstream files touched)

- `get.sh` — default repo is this one; the `npx skills add mattpocock/skills` step is
  replaced by the vendored, pinned copy (no network, no Node needed).
- `install.sh` — `--sets=<list>` installs vendored skill sets into the target's
  `.agents/skills/` (record: `.agents/skill-sets.json`); `--hosts=<list>` wires/announces
  agent CLIs (`claude` forced on; `codex`, `opencode`, `copilot`, `zcode`, `other`).
- `scripts/super-board-setup.py` — `fix --sets=… --hosts=…` passthrough; `check` reports
  installed skill sets.
- `scripts/super-board-agents-md.py` — new `skill-map` subcommand (AGENTS.md block +
  `.claude/super-board/skill-map.json`).
- `skills/super-board/references/onboard.md` — wizard grows from 8 to 10 steps
  (🧩 Skills, 🤖 Agents); `--sets` / `--agents` parameters.
- `skills/super-board/references/config-schema.json` — `skill_sets`, `agents`,
  `other_agents` keys.
- New: `skill-sets/` (the three vendored sets + `registry.json` step mappings).
  The physical skill files live in `.agents/skills/` (ZCode's picker scans
  symlinks-disabled); `skill-sets/<set>/<skill>` are relative symlinks back, and
  the board's 8 skills get content-copies there, re-synced by
  `scripts/agents-skills-sync.sh` and guarded by `tests/test-agents-skills-sync.sh`.

Upstream files not listed here are unmodified.
