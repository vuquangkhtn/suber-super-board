# skill-sets

Vendored, pinned skill sets that [`/super-board onboard`](../skills/super-board/references/onboard.md)
can install into any project, on top of super-board's own [`skills/`](../skills/) pack.

| Set | Source | Pinned | License |
|---|---|---|---|
| `mattpocock` | [mattpocock/skills](https://github.com/mattpocock/skills) | 2026-10-29 (repo commit 282a125) | MIT |
| `pstack` | [michael-denyer/pstack-claude](https://github.com/michael-denyer/pstack-claude) · original by Lauren Tan ([cursor/plugins/pstack](https://github.com/cursor/plugins/tree/main/pstack)) | `190fc9a0` | MIT + [LICENSE-cursor-team-kit](pstack/LICENSE-cursor-team-kit) + [LICENSE-thermos](pstack/LICENSE-thermos), see [NOTICE.md](pstack/NOTICE.md), [NOTICE-skills.md](pstack/NOTICE-skills.md) |
| `agent-skills` | [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | `eb07f19f` | MIT |

## Layout

- `mattpocock/`, `pstack/` — **flat**: each subdirectory is one skill.
- `agent-skills/` — **nested**: skills under `skills/`, plus the set's shared
  `references/` checklists that the skills point into. Keeping the internal
  layout means every relative link inside the set stays valid here.

The step → skills mapping for every set lives in [`registry.json`](registry.json)
(one entry per lifecycle step: Plan · Design · Build · Test · Deploy · Maintain,
plus `anytime` for routers and utilities). `install.sh` and the onboard wizard
both read it; edit mappings there, not in prose.

## Updating a set

1. Bump the upstream pin (record the new commit SHA in `registry.json`).
2. Copy the new skills over the set directory, preserving the layout above.
3. Re-run `tests/test-registry.sh` (validates that every mapped skill exists
   and every vendored skill is mapped or listed under `anytime`).
