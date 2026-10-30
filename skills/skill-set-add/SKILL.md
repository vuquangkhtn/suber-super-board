---
name: skill-set-add
description: Vendor another vendor's skill repo into this pack's skill-sets/ store as a new set — clone to a temp dir, copy the skills, carry LICENSE/NOTICE, write the registry entry with a step-mapping draft, and validate. Use when the user runs /skill-set-add or says "add a skill set", "vendor these skills", or "add a new skill-set to super-board".
---

# /skill-set-add

Vendor one GitHub skill repo into the store (`skill-sets/` + `registry.json`) as a new
set: skills copied, licenses carried, registry entry written, validation run. One set per
run. Stop and tell the user when a step says stop. NEVER vendor from a partial checkout,
NEVER touch files under `skill-sets/{mattpocock,pstack,agent-skills}/`, and NEVER commit —
committing is the user's call.

## 1 · Gather

1. Take `<repo>` (owner/name or URL) and the optional `<ref>` from the user's request;
   no ref means the default branch.
2. Read `skill-sets/registry.json`. Stop when a set of the same name exists — suggest a
   different name, or a hand edit to bump the existing set's pin.
3. Defaults, no questions: layout auto-detected, license detected from the repo's LICENSE,
   every skill unmapped (lands in `anytime`).

## 2 · Clone

1. `git clone --depth 1 <repo>` (add `--branch <ref>` when one is given) into a fresh
   temp dir. Clone fails → stop; never vendor from a partial checkout.
2. Note the pinned sha: `git -C <tmp> rev-parse HEAD`.
3. Note the layout: skills under `skills/` (nested) or directly at the top (flat).

## 3 · Vendor

1. Draft a step mapping when the skill names make it obvious: one line per lifecycle step
   (`plan`, `design`, `build`, `test`, `deploy`, `maintain`) with the skills that belong
   there. Write it to a temp JSON file (`{"build": ["tdd", ...]}`, partial is fine).
2. Run, from the pack root:
   `python3 scripts/super-board-skill-set-add.py --source <tmp> --name <set> --url <repo-url> [--ref <ref>] [--steps-json <file>]`
   plus `--title` / `--description` / `--license` when they add something.
3. The script refuses an existing name, an unknown step, an unknown skill name, and a bad
   set name. Fix the flag and re-run; it never half-writes (registry and dir are replaced
   together).
4. Skills you could not place stay in `anytime` — the registry test accepts that; say so in
   the report.

## 4 · Verify

1. `bash tests/test-registry.sh` must pass — the script runs it; do not skip it.
2. Show the user: the new registry entry, the vendored dir with its skill count, and the
   carried LICENSE/NOTICE files.
3. Stop and say: carrying a license is not a license analysis — a human must check the
   source repo's license allows redistribution before this is committed.

## 5 · Land

1. Suggest, do not run: `✨ [feat] skill-sets: vendor <set> from <repo>` (writing standard).
2. The new set is picked up with no further edits: onboard's 🧩 Skills step reads its
   options from `skill-sets/registry.json`, and
   `python3 scripts/super-board-setup.py fix --sets=<set> --text` installs it into a target.
