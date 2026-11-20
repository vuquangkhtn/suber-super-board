# How commands reach skill sets

Installing a set makes its skills available. Mapping a skill to a lifecycle step
records where it fits. Only a command that reads that map conducts those skills.
The [registry](../skill-sets/registry.json) is the source of truth; onboard writes
its selected steps to `.claude/super-board/skill-map.json` and the managed AGENTS.md
block. The installation record `.agents/skill-sets.json` says what actually installed.

## Four routing paths

| Path | Entry point | Selection rule |
|---|---|---|
| Named-set conduct | `/super-plan` | Reads the map's Plan and Design steps and conducts those skills with the user. Custom per-step selections work through the same map. |
| Hardcoded lane routing | `/super-board run`, `/super-build`, `/super-qa`, `/super-review` | The board dispatches lanes; each lane follows its own instructions. Choosing a named set does not replace those instructions with its Build/Test/Deploy lists. |
| Explicit card skills | `Skills:` in an issue body | The Builder uses this list instead of its label-derived row. The always-required checks still apply. |
| Anytime / on demand | Direct skill invocation by a user or agent | Installed skills can be requested when useful; the registry's `anytime` list is not an automatic lane schedule. |

The [planner contract](../skills/super-plan/SKILL.md) reads Plan and Design at run
time. The [Builder decision policy](../skills/super-build/references/decision-policy.md#label-routing)
hardcodes `bug` to diagnosing-bugs and tdd; `feature` to implement, tdd and
codebase-design; and `docs` to no label-specific skills. Multiple labels use the
first matching row. An explicit **`Skills:` line wins outright**, replacing that
row rather than extending it. Ponytail (or its inline fallback), verification and
code review remain required in either case.

Board routing and skill routing are separate decisions: `qa` skips Building;
`bug`, `feature` and untyped cards are built first. The
[QA contract](../skills/super-qa/SKILL.md) suggests diagnosing-bugs and tdd on bug
tickets; the [Review contract](../skills/super-review/SKILL.md) names its review
skills directly. Neither becomes the named set's whole Test list.

## mattpocock

[Open the mattpocock diagram](skill-routing/mattpocock-skill-routing.html).

- **Named-set conduct:** when selected for Plan/Design, `/super-plan` reaches
  research, grilling, grill-me, grill-with-docs, to-questionnaire, to-tickets and
  wayfinder for Plan; codebase-design, domain-modeling and to-spec for Design.
- **Lane routing:** Builder defaults explicitly name mattpocock skills according
  to the card label. QA suggests diagnosing-bugs and tdd; Review explicitly loads
  code-review and codebase-design. These are subsets, not execution of every
  skill mapped to Build or Test.
- **Explicit card skills:** a `Skills: mattpocock-skills:tdd` line replaces the
  Builder label row, subject to the always-list and installed availability.
- **Anytime / on demand:** ask-matt and setup-matt-pocock-skills are the anytime
  entries. Other installed skills, including Deploy's pr and handoff and the
  Maintain skills, can be requested directly.

The vendored source is `mattpocock/skills`, recorded as vendored 2026-10-29
(repo commit `282a125`). See [upstream provenance](../UPSTREAM.md).

## pstack

[Open the pstack diagram](skill-routing/pstack-skill-routing.html).

- **Named-set conduct:** `/super-plan` conducts how, why, teach, figure-it-out and
  show-me-your-work for Plan; architect, arena and interrogate for Design.
- **Lane routing:** selecting pstack does not switch Builder, QA or Review to
  pstack's mapped lists. Build includes tdd, typescript-best-practices, deslop and
  no-comments, but that mapping alone does not dispatch them.
- **Explicit card skills:** a card can request installed pstack skills through
  `Skills:` instead of the Builder label row; the always-list still applies.
- **Anytime / on demand:** poteto-mode, recall, the principle skills and the other
  registry anytime entries are available on demand. Test and Deploy entries are
  also mapped for use when requested. Maintain is empty: the registry explicitly
  falls back to super-board's super-collect and calibration loop.

The source is `michael-denyer/pstack-claude`, pinned at
`190fc9a009491cbcfc04e25ef5b3c2d1fcf5ca8a`. The reconciled mapping includes **teach
in Plan and tdd in Build**; neither is removed merely because another set owns an
installed skill with that name.

## agent-skills

[Open the agent-skills diagram](skill-routing/agent-skills-skill-routing.html).

- **Named-set conduct:** `/super-plan` conducts interview-me, idea-refine,
  spec-driven-development, constraint-driven-development and planning-and-task-breakdown
  for Plan; api-and-interface-design and frontend-ui-engineering for Design.
- **Lane routing:** selecting agent-skills does not replace the hardcoded lane
  defaults. Its Build, Test, Deploy and Maintain mappings describe available
  capabilities, not automatic calls by `/super-board run`.
- **Explicit card skills:** a card may request installed agent-skills skills via
  `Skills:` in place of the Builder label row, retaining the always-list.
- **Anytime / on demand:** using-agent-skills is the anytime entry; other installed
  skills can also be invoked directly when their task applies.

The source is `addyosmani/agent-skills`, pinned at
`eb07f19f52c2669f2364897aaa293e2aaddd7b1c`. Installation flattens its nested skill
layout and copies shared references; it does not change routing precedence.

## Reading the diagrams and checking the active installation

The three self-contained HTML pages are the existing generated archify bundles,
kept unchanged. Download a page and open it locally to use the interactive viewer;
GitHub's file view displays its source. Each node carries repository source links
pinned to `81ec1de379bac8c7a59d166c78ef95e509747d9c`, the diagram snapshot revision.
Their named-set examples show pstack active; they do not inspect your installation.
The current registry and lane contracts linked above govern current behavior.

`/super-collect` files verified cards; `/ui-refine-loop`, `/visual` and `/git-sync`
serve their own tasks. `/skill-set-add` and `/skill-set-sync` maintain vendored
sets. Their presence in a diagram does not mean they conduct every lifecycle row.

When names collide (notably tdd and teach), the first installed set wins and later
copies are recorded as skipped. Check `.agents/skill-sets.json` for ownership;
check the generated map for selected lifecycle steps. A map is not an installation
inventory. See the [guide's skill-set section](GUIDE.md#9-skill-sets) for switching
sets and the [registry](../skill-sets/registry.json) for complete lists.
