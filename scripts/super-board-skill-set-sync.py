#!/usr/bin/env python3
"""Sync one vendored skill set from its upstream GitHub repo.

    super-board-skill-set-sync.py <set> [--ref <ref>] [--dry-run] [--no-validate]

The deterministic half of /skill-set-sync (skills/skill-set-sync): clones the
set's upstream at the current pin (or --ref), diffs the clone against the set's
physical store, applies adds and updates, rewrites pinned_ref in
skill-sets/registry.json and the set's pin row in UPSTREAM.md, and runs
tests/test-registry.sh + tests/run-safety.sh so a broken sync never lands.

The physical store is wherever the set's skills live today, read from disk:

- symlink layout (the shipped sets): real dirs in .agents/skills/, reached
  through skill-sets/<set>/[skills/]<skill> links. The links keep pointing at
  the same names, so only the .agents/skills copies change. Nested sets with
  shared references refresh .agents/skills/references/ too, and copies get the
  same ../../../references/ -> ../../references/ rewrite install.sh applies.
- vendored-in-place layout (skill-set-add): real dirs under
  skill-sets/<set>/, updated where they stand, verbatim.

Skills the upstream no longer ships are flagged against the registry mappings
and KEPT on disk — never silently deleted. Deleting a mapped skill would leave
a registry ghost (test-registry.sh fails) and remapping is a human decision;
the same hold covers carried LICENSE/NOTICE files upstream dropped.

Exit codes: 0 clean sync, nothing to do, or dry-run · 1 post-sync validation
failed · 2 bad input or refusal · 3 synced, but removals were flagged (kept).
Stdlib only. Runs from any cwd; paths are relative to the pack root.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "skill-sets" / "registry.json"
UPSTREAM_MD = ROOT / "UPSTREAM.md"
STEPS = ["plan", "design", "build", "test", "deploy", "maintain"]
LICENSE_PATTERNS = ("LICENSE*", "LICENCE*", "NOTICE*", "COPYING*", "AUTHORS*")
COPY_IGNORE = shutil.ignore_patterns(
    ".git", ".gitignore", ".github", ".gitattributes",
    "__pycache__", "*.pyc", ".DS_Store", "node_modules",
)
SHA_RE = re.compile(r"[0-9a-f]{7,40}")


def die(msg: str) -> None:
    print(f"skill-set-sync: {msg}", file=sys.stderr)
    sys.exit(2)


def git(*args: str, cwd: Path | None = None) -> str:
    r = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)
    if r.returncode != 0:
        die(f"git {' '.join(args[:2])} failed: {r.stderr.strip()}")
    return r.stdout.strip()


def tree_hash(root: Path) -> dict[str, str]:
    """Stable {relative path: content hash} map for diffing two trees."""
    out: dict[str, str] = {}
    for p in sorted(root.rglob("*")):
        if p.is_file():
            out[str(p.relative_to(root))] = hashlib.sha256(p.read_bytes()).hexdigest()
    return out


def mapping_of(reg_entry: dict, name: str) -> str:
    for step in reg_entry.get("steps", {}):
        if name in reg_entry["steps"].get(step, []):
            return step
    if name in reg_entry.get("anytime", []):
        return "anytime"
    return "unmapped"


def find_skill_dirs(root: Path) -> list[Path]:
    """Skill dirs (containing SKILL.md) one level down; else grouped two down
    (mattpocock ships skills/engineering/<skill> and skills/productivity/<skill>)."""
    at = sorted(p for p in root.iterdir() if p.is_dir() and (p / "SKILL.md").is_file())
    if at:
        return at
    grouped: list[Path] = []
    for sub in sorted(p for p in root.iterdir() if p.is_dir()):
        grouped.extend(p for p in sub.iterdir()
                       if p.is_dir() and (p / "SKILL.md").is_file())
    return grouped


def skills_root(clone: Path, meta: dict) -> Path:
    if meta.get("vendored_path"):
        return clone / meta["vendored_path"]
    if meta.get("layout") == "nested":
        return clone / meta.get("nested_skills_dir", "skills")
    return clone


def current_skills(setdir: Path, meta: dict) -> dict[str, Path]:
    """Physical skill dirs for the set, read from disk. Link entries resolve
    into .agents/skills/ (symlink layout); real dirs are vendored in place."""
    src = setdir / meta.get("nested_skills_dir", "skills") \
        if meta.get("layout") == "nested" else setdir
    if not src.is_dir():
        die(f"set skills dir missing: {src.relative_to(ROOT)} — repair by hand")
    out: dict[str, Path] = {}
    for entry in sorted(src.iterdir()):
        if entry.is_symlink():
            if not entry.exists():
                die(f"dangling set link: {entry.relative_to(ROOT)} -> "
                    f"{os.readlink(entry)} — repair by hand")
            physical = entry.resolve()
            # Set-level file links (e.g. README.md → the store) are not skills.
            if not (physical.is_dir() and (physical / "SKILL.md").is_file()):
                continue
        elif entry.is_dir() and (entry / "SKILL.md").is_file():
            physical = entry
        else:
            continue
        out[entry.name] = physical
    if not out:
        die(f"no skills on disk under {src.relative_to(ROOT)} — repair by hand")
    return out


def physical_home(setdir: Path, meta: dict, existing: dict[str, Path]) -> Path:
    """Where an ADDED skill's physical dir goes: the .agents/skills store for
    symlink-layout sets, the set dir itself for vendored-in-place sets."""
    if any(p.is_relative_to(ROOT / ".agents" / "skills") for p in existing.values()):
        return ROOT / ".agents" / "skills"
    src = setdir / meta.get("nested_skills_dir", "skills") \
        if meta.get("layout") == "nested" else setdir
    return src


def normalize_shared_refs(dest: Path) -> None:
    # Shared checklists live at the set root; in the flattened .agents/skills
    # tree they sit one level higher than upstream's skills/<skill> dirs, so
    # the deep links need one level less. Same rewrite install.sh applies.
    for f in dest.rglob("*"):
        if not f.is_file() or f.suffix not in {".md", ".txt"}:
            continue
        text = f.read_text(errors="replace")
        if "../../../references/" in text:
            f.write_text(text.replace("../../../references/", "../../references/"))


def refs_store_dir(setdir: Path, meta: dict) -> Path | None:
    """The set's shared-references copy on disk, resolved through its link."""
    if meta.get("layout") != "nested":
        return None
    refs = setdir / meta.get("shared_references_dir", "references")
    if refs.is_symlink():
        refs = refs.resolve()
    return refs if refs.is_dir() else None


def rewrite_upstream_row(name: str, meta: dict, new_sha: str, today: str) -> str:
    """Rewrite the set's pin in UPSTREAM.md's provenance table; idempotent."""
    if not UPSTREAM_MD.is_file():
        return "UPSTREAM.md missing — pin row not updated"
    source = meta.get("source", "")
    lines = UPSTREAM_MD.read_text().splitlines()
    rows = [i for i, ln in enumerate(lines)
            if ln.startswith("|") and source and source in ln]
    if not rows:
        rows = [i for i, ln in enumerate(lines)
                if ln.startswith("|") and re.search(rf"\b{name}\b", ln)]
    if not rows:
        return f"UPSTREAM.md: no pin row found for {name} — update it by hand"
    i = rows[0]
    row = lines[i]
    row = SHA_RE.sub(new_sha, row)  # hex runs of 7+ in a pin row are pins
    row = re.sub(r"vendored \d{4}-\d{2}-\d{2}", f"vendored {today}", row)
    lines[i] = row
    UPSTREAM_MD.write_text("\n".join(lines) + "\n")
    return f"UPSTREAM.md pin row {i + 1} → {new_sha[:12]}"


def run_suite(script: str) -> None:
    r = subprocess.run(["bash", str(ROOT / "tests" / script)], cwd=ROOT)
    if r.returncode != 0:
        print(f"skill-set-sync: {script} failed after sync — fix or revert "
              f"(the previous pin is in git history)", file=sys.stderr)
        sys.exit(1)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("set", metavar="SET", help="set name in skill-sets/registry.json")
    ap.add_argument("--ref", default="",
                    help="sync to this ref instead of the current pinned_ref")
    ap.add_argument("--dry-run", action="store_true",
                    help="print what would change; write nothing")
    ap.add_argument("--no-validate", action="store_true",
                    help="skip the tests/test-registry.sh + tests/run-safety.sh runs")
    args = ap.parse_args()

    if not REGISTRY.is_file():
        die(f"registry missing: {REGISTRY.relative_to(ROOT)} — "
            f"this tool belongs in the super-board pack repo")
    reg = json.loads(REGISTRY.read_text())
    meta = reg.get("sets", {}).get(args.set)
    if meta is None:
        die(f"unknown set '{args.set}' (have: {', '.join(sorted(reg.get('sets', {})))})")
    setdir = ROOT / meta["dir"]
    if not setdir.is_dir():
        die(f"registry lists '{args.set}' but {meta['dir']} is missing — repair by hand")
    source = meta.get("source", "")
    # Production sources are https repos; a local checkout (or file:// URL) is
    # allowed so the flow stays testable offline — anything else refuses.
    if not (re.match(r"^https?://", source) or source.startswith("file://")
            or Path(source).expanduser().is_dir()):
        die(f"set '{args.set}' source is neither an http(s) URL nor a local "
            f"checkout: {source or '(none)'}")

    old_pin = meta.get("pinned_ref", "")
    old_sha_m = SHA_RE.search(old_pin)
    target_ref = args.ref or (old_sha_m.group(0) if old_sha_m else "")
    if not target_ref:
        die(f"pinned_ref '{old_pin}' holds no commit sha — pass --ref <ref> once "
            f"to move this set onto a sha pin")

    # Clone (full history: the pin may be any sha) and check out the target.
    tmp = Path(tempfile.mkdtemp(prefix="skill-set-sync-"))
    try:
        checkout = tmp / "clone"
        r = subprocess.run(["git", "clone", "--quiet", source, str(checkout)],
                           capture_output=True, text=True)
        if r.returncode != 0:
            die(f"clone of {source} failed — never sync from a partial checkout: "
                f"{r.stderr.strip()}")
        git("checkout", "--quiet", "--detach", target_ref, cwd=checkout)
        new_sha = git("rev-parse", "HEAD", cwd=checkout)

        upstream = {p.name: p for p in find_skill_dirs(skills_root(checkout, meta))}
        if not upstream:
            die(f"no skills with SKILL.md found in {source} "
                f"(under {skills_root(checkout, meta).relative_to(checkout)})")
        store = current_skills(setdir, meta)

        added = sorted(set(upstream) - set(store))
        removed = sorted(set(store) - set(upstream))
        changed = [n for n in sorted(set(store) & set(upstream))
                   if tree_hash(store[n]) != tree_hash(upstream[n])]

        store_refs = refs_store_dir(setdir, meta)
        clone_refs = checkout / meta.get("shared_references_dir", "references") \
            if meta.get("layout") == "nested" else None
        refs_changed = bool(
            store_refs and clone_refs and clone_refs.is_dir()
            and tree_hash(store_refs) != tree_hash(clone_refs))

        carried_now = {f.name: f for pat in LICENSE_PATTERNS
                       for f in setdir.glob(pat) if f.is_file() and not f.is_symlink()}
        carried_up = {f.name: f for pat in LICENSE_PATTERNS
                      for f in checkout.glob(pat) if f.is_file()}
        carried_set = sorted(n for n, f in carried_up.items()
                             if n not in carried_now
                             or hashlib.sha256(f.read_bytes()).hexdigest()
                             != hashlib.sha256(carried_now[n].read_bytes()).hexdigest())
        carried_gone = sorted(set(carried_now) - set(carried_up))

        pin_moves = new_sha != (old_sha_m.group(0) if old_sha_m else "")
        if not (pin_moves or added or removed or changed or refs_changed
                or carried_set or carried_gone):
            print(f"skill-set-sync: {args.set} already at {new_sha[:12]} — nothing to sync")
            return 0

        print(f"skill-set-sync: {args.set} @ {source}")
        print(f"  pin: {old_pin or '(none)'} → {new_sha}"
              f"{' (registry.json + UPSTREAM.md)' if pin_moves else ''}")
        print(f"  added: {', '.join(added) if added else 'none'}"
              f"{'  (→ physical store + registry anytime)' if added else ''}")
        print(f"  updated: {', '.join(changed) if changed else 'none'}")
        if removed:
            print("  removed — KEPT, flagged against registry mappings "
                  "(upstream no longer ships them; remap or drop by hand):")
            for n in removed:
                print(f"    - {n} — registry: {mapping_of(meta, n)}")
        else:
            print("  removed: none")
        if refs_changed:
            print(f"  shared references: refreshed ({clone_refs.name}/ differs)")
        if carried_set:
            print(f"  carried files refreshed: {', '.join(carried_set)}")
        if carried_gone:
            print("  carried files upstream dropped — KEPT, flagged:")
            for n in carried_gone:
                print(f"    - {n}")
        if args.dry_run:
            print("  dry-run: nothing written")
            return 0

        # Apply: updates in place, adds into the physical home, then pins.
        home = physical_home(setdir, meta, store)
        flatten = home == ROOT / ".agents" / "skills" and refs_store_dir(setdir, meta)
        for n in changed:
            physical = store[n]
            shutil.rmtree(physical)
            shutil.copytree(upstream[n], physical, ignore=COPY_IGNORE)
            if flatten:
                normalize_shared_refs(physical)
        for n in added:
            physical = home / n
            if physical.exists() or physical.is_symlink():
                die(f"refusing to clobber {physical.relative_to(ROOT)} — "
                    f"it exists but is not part of {args.set}'s store")
            shutil.copytree(upstream[n], physical, ignore=COPY_IGNORE)
            if flatten:
                normalize_shared_refs(physical)
            src_level = setdir / meta.get("nested_skills_dir", "skills") \
                if meta.get("layout") == "nested" else setdir
            if physical.parent != src_level:  # symlink layout: link the new name in
                link = src_level / n
                if link.exists() or link.is_symlink():
                    link.unlink()  # a dangling leftover, never real content
                os.symlink(os.path.relpath(physical, link.parent), link)
            meta.setdefault("anytime", [])
            if mapping_of(meta, n) == "unmapped":
                meta["anytime"] = sorted(set(meta["anytime"]) | {n})
        if refs_changed and store_refs and clone_refs:
            shutil.copytree(clone_refs, store_refs, dirs_exist_ok=True)
        for n in carried_set:
            shutil.copy2(carried_up[n], setdir / n)

        meta["pinned_ref"] = new_sha
        REGISTRY.write_text(json.dumps(reg, indent=2) + "\n")
        print(f"  registry.json: pinned_ref → {new_sha}"
              + (f", {', '.join(added)} → anytime" if added else ""))
        print(f"  {rewrite_upstream_row(args.set, meta, new_sha, dt.date.today().isoformat())}")

        if not args.no_validate:
            run_suite("test-registry.sh")
            run_suite("run-safety.sh")
        if removed or carried_gone:
            print("skill-set-sync: synced with flags — removals above are kept on "
                  "disk and need a remapping decision")
            return 3
        print(f"skill-set-sync: {args.set} synced to {new_sha[:12]}")
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
