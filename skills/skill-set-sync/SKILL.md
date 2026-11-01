---
name: skill-set-sync
description: Sync one vendored skill set (pstack, mattpocock, agent-skills, …) from its upstream GitHub repo at the pinned ref or a new one — refresh the physical store, rewrite the pin in registry.json and UPSTREAM.md, flag upstream removals against the registry instead of deleting them, and validate. Use when the user runs /skill-set-sync or says "sync a skill set", "update the vendored pstack copy", or "bump a skill-set pin".
---

# /skill-set-sync

Refresh one vendored skill set from upstream: skills updated, pin rewritten,
removals flagged, validation run. One set per run. Stop and tell the user when a
step says stop. NEVER sync from a partial checkout, NEVER delete a mapped skill
because upstream dropped it, and NEVER commit — committing is the user's call.

## 1 · Dry-run first

1. Take the set name and the optional `--ref` from the user's request; no ref
   means the current `pinned_ref` in `skill-sets/registry.json`.
2. Run, from the pack root:
   `python3 scripts/super-board-skill-set-sync.py <set> --dry-run` (add
   `--ref <ref>` when one was given). It clones upstream to a temp dir and
   prints: old → new pin, skills added/updated, and removals it would flag.
3. Clone fails or the pin holds no sha → stop; fix the pin or the ref, never
   sync from a partial checkout.

## 2 · Show the plan

1. Show the user the dry-run output and say what a real sync will do:
   - skills updated in the physical store (`.agents/skills/` for the shipped
     sets, `skill-sets/<set>/` for sets vendored in place) — set symlinks stay
     pointing at the same names;
   - added skills copied in and parked under `anytime` in the registry;
   - removed skills KEPT on disk and flagged against their registry mapping —
     remapping them is the user's decision, never a silent delete;
   - `pinned_ref` in `registry.json` and the set's row in `UPSTREAM.md` rewritten.
2. Get an explicit go-ahead before the real sync unless the user already asked
   for it in so many words ("sync pstack to latest" is a go-ahead).

## 3 · Sync

1. Run without `--dry-run`. The script applies the plan and then runs
   `tests/test-registry.sh` and `bash tests/run-safety.sh`; do not skip them.
2. Exit 0 — clean sync; show the report.
3. Exit 3 — synced with flags: the removals listed in the output are KEPT on
   disk. Walk each one with the user: drop the registry mapping (and the store
   copy) by hand, or keep both and record why in the set's docs. The registry
   test still passes because nothing was deleted.
4. Exit 1 — a validation failed after the sync. Fix or revert; the previous pin
   is in git history.

## 4 · Land

1. Show the user: the new pin, the store diff summary, and any flags.
2. Suggest, do not run: `✨ [feat] skill-sets: sync <set> to <short sha>`
   (writing standard).
3. Remind: a license change in the carried LICENSE/NOTICE files is not analyzed
   by the sync — a human re-checks redistribution rights before it lands.

The deterministic half is `scripts/super-board-skill-set-sync.py`. Pack-maintainer
tool: it runs where `skill-sets/` lives; `install.sh` does not copy it into
target projects. Needs `git` and `python3`.
