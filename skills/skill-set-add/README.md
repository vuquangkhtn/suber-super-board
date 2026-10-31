# /skill-set-add

Vendors one GitHub skill repo into the pack's store (`skill-sets/` + `registry.json`) as a
new set: skills copied, LICENSE/NOTICE carried, registry entry written, validation run.

## What It Does

- **Clones to a temp dir first.** `--depth 1` at the ref you name; the pinned commit sha
  from the clone becomes the registry's `pinned_ref`. Never vendors from a partial checkout.
- **Preserves the layout.** Skills under `skills/` are vendored nested (with any shared
  `references/` dir); skills at the repo top go in flat — auto-detected, overridable.
- **Carries the licenses.** `LICENSE*`, `NOTICE*`, `COPYING*`, `AUTHORS*` land in the set
  dir, where `install.sh` copies them to `.agents/skill-set-licenses/<set>` on install.
- **Writes a registry entry.** Source, pin, license, layout, and a step-mapping draft —
  skills you don't place stay in `anytime`, which the registry test accepts.
- **Validates.** Runs `tests/test-registry.sh` before it reports success; a bad entry
  never lands. Refuses an existing set name (`--force` re-vendors).

## When To Use It

- You want to extend the pack with another vendor's skills as a fourth (fifth, …) set.
- You re-vendor an existing set at a new pin: same command, `--force`.

A carried license is not a license analysis — a human checks redistribution rights before
the commit lands. The deterministic half is `scripts/super-board-skill-set-add.py`.

## Install

Pack-maintainer tool: it runs where `skill-sets/` lives, i.e. in this pack repo. It is not
copied into target projects by `install.sh`. Needs `git` and `python3`.
