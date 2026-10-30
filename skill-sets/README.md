# skill-sets

Vendored, pinned skill sets that [`/super-board onboard`](../skills/super-board/references/onboard.md)
can install into any project, on top of super-board's own [`skills/`](../skills/) pack.

| Set | Source | Pinned | License |
|---|---|---|---|
| `mattpocock` | [mattpocock/skills](https://github.com/mattpocock/skills) | 2026-10-29 (repo commit 282a125) | MIT |
| `pstack` | [michael-denyer/pstack-claude](https://github.com/michael-denyer/pstack-claude) · original by Lauren Tan ([cursor/plugins/pstack](https://github.com/cursor/plugins/tree/main/pstack)) | `190fc9a0` | MIT + [LICENSE-cursor-team-kit](pstack/LICENSE-cursor-team-kit) + [LICENSE-thermos](pstack/LICENSE-thermos), see [NOTICE.md](pstack/NOTICE.md), [NOTICE-skills.md](pstack/NOTICE-skills.md) |
| `agent-skills` | [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | `eb07f19f` | MIT |

## Layout

- `.agents/skills/` is the **physical home** of every discoverable skill (ZCode's
  slash-menu picker scans with symlink-following disabled, so skill entries there
  must be real directories):
  - the three vendored sets' skills (mattpocock, pstack, agent-skills),
  - `agent-skills`' shared `references/` checklists,
  - content-copies of the board's 8 skills (source of truth stays `skills/`, which
    upstream tests and readme-sync depend on — re-sync via
    `scripts/agents-skills-sync.sh`, guarded by `tests/test-agents-skills-sync.sh`).
- `skill-sets/<set>/<skill>` holds **relative symlinks** back into `.agents/skills/`
  (agent-skills one level deeper: `../../../`). `install.sh` copies through them, so
  targets still get real files. Set-level LICENSE / NOTICE / README files stay
  physical here.

The step → skills mapping for every set lives in [`registry.json`](registry.json)
(one entry per lifecycle step: Plan · Design · Build · Test · Deploy · Maintain,
plus `anytime` for routers and utilities). `install.sh` and the onboard wizard
both read it; edit mappings there, not in prose.

## Updating a set

1. Bump the upstream pin (record the new commit SHA in `registry.json`).
2. Copy the new skills over the set directory, preserving the layout above.
3. Re-run `tests/test-registry.sh` (validates that every mapped skill exists
   and every vendored skill is mapped or listed under `anytime`).
