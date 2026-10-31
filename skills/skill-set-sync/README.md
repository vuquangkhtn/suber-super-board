# /skill-set-sync

Syncs one vendored skill set from its upstream GitHub repo at the current pin or
a new ref: store refreshed, pin rewritten, removals flagged, validation run.

## What It Does

- **Dry-run first.** `--dry-run` clones upstream to a temp dir and prints what
  would change — skills added/updated, old → new pin — without writing.
- **Updates the physical store, not the links.** The shipped sets' skills live
  in `.agents/skills/` with `skill-sets/<set>/` symlinks pointing at the names;
  the links are untouched, only the store copies change. Sets vendored in place
  (`/skill-set-add` layout) are updated where they stand.
- **Rewrites the pins.** `pinned_ref` in `skill-sets/registry.json` and the
  set's row in the root `UPSTREAM.md` both move to the new commit sha.
- **Flags removals, never deletes.** A skill upstream no longer ships stays on
  disk and is reported against its registry mapping (step or `anytime`) —
  deleting a mapped skill would leave a registry ghost; remapping is a human
  decision. Carried LICENSE/NOTICE files upstream dropped get the same hold.
- **Adds park in `anytime`.** New upstream skills are copied in and linked like
  their siblings, then listed `anytime` in the registry until mapped.
- **Validates.** Runs `tests/test-registry.sh` + `bash tests/run-safety.sh`
  after a real sync; a broken sync never lands. Exit 3 means "synced with
  flags" (removals kept), 0 clean, 2 refused, 1 validation failed.

## When To Use It

- A new upstream release of pstack / mattpocock / agent-skills (or any set).
- Auditing what an update would touch: run `--dry-run`, read, decide.

A moved pin is not a license review — check carried LICENSE/NOTICE diffs before
committing. The deterministic half is `scripts/super-board-skill-set-sync.py`.

## Install

Pack-maintainer tool: it runs where `skill-sets/` lives, i.e. in this pack repo.
It is not copied into target projects by `install.sh`. Needs `git` and `python3`.
