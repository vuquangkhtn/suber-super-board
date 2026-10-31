#!/usr/bin/env python3
"""Vendor a skill repo into the pack's skill-sets/ store as a new set.

    super-board-skill-set-add.py --source <dir> --name <set> [options]

The deterministic half of /skill-set-add (skills/skill-set-add): the caller
clones the repo to a temp dir, this script copies the skills into
skill-sets/<name>/ (flat or nested), carries LICENSE/NOTICE files, writes the
registry entry (source, pinned sha, license, step draft, rest anytime), and
runs tests/test-registry.sh so a bad entry never lands.

Exit codes: 0 ok · 2 bad input (refused) · 1 registry validation failed.
Stdlib only. Runs from any cwd; paths are relative to the pack root.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "skill-sets" / "registry.json"
DEFAULT_STEPS = ["plan", "design", "build", "test", "deploy", "maintain"]
LICENSE_PATTERNS = ("LICENSE*", "LICENCE*", "NOTICE*", "COPYING*", "AUTHORS*")
COPY_IGNORE = shutil.ignore_patterns(
    ".git", ".gitignore", ".github", ".gitattributes",
    "__pycache__", "*.pyc", ".DS_Store", "node_modules",
)


def die(msg: str) -> None:
    print(f"skill-set-add: {msg}", file=sys.stderr)
    sys.exit(2)


def git_sha(source: Path) -> str | None:
    """Head commit of the checkout, when it still has git metadata."""
    if not (source / ".git").exists():
        return None
    r = subprocess.run(["git", "-C", str(source), "rev-parse", "HEAD"],
                       capture_output=True, text=True)
    return r.stdout.strip() or None if r.returncode == 0 else None


def detect_license(source: Path) -> str:
    """SPDX guess from the license text; anything else stays a pointer."""
    for pat in ("LICENSE*", "LICENCE*", "COPYING*"):
        for f in sorted(source.glob(pat)):
            text = f.read_text(errors="replace")[:2000].lower()
            if "apache license" in text:
                return "Apache-2.0"
            if re.search(r"\bmit\b", text) and "permission is hereby granted" in text:
                return "MIT"
            if re.search(r"\bitsc\b", text) and "permission to use, copy" in text:
                return "ISC"
            if "permission is hereby granted, free of charge" in text:
                return "MIT"
    return "see LICENSE"


def find_skills(source: Path, layout: str) -> tuple[str, list[Path]]:
    """Skill dirs (containing SKILL.md): nested under skills/, or flat."""
    def with_skill_md(d: Path) -> list[Path]:
        return sorted(p for p in d.iterdir() if p.is_dir() and (p / "SKILL.md").exists())

    nested = with_skill_md(source / "skills") if (source / "skills").is_dir() else []
    if layout == "nested" or (layout == "auto" and nested):
        if not nested:
            die(f"no skills with SKILL.md under {source / 'skills'}")
        return "nested", nested
    flat = with_skill_md(source)
    if not flat:
        die(f"no skill dirs with SKILL.md under {source}")
    return "flat", flat


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True, type=Path, metavar="DIR",
                    help="checkout of the skill repo to vendor (a temp clone)")
    ap.add_argument("--name", required=True, metavar="SET",
                    help="store/registry name: a-z0-9 and dashes")
    ap.add_argument("--url", default="", help="source repo URL for the registry")
    ap.add_argument("--ref", default="", help="branch or tag vendored")
    ap.add_argument("--title", default="", help="registry title (default: the set name)")
    ap.add_argument("--description", default="", help="one-line registry description")
    ap.add_argument("--license", default="", dest="license", metavar="SPDX",
                    help="license (default: detected from the LICENSE file)")
    ap.add_argument("--layout", choices=("auto", "flat", "nested"), default="auto")
    ap.add_argument("--steps-json", type=Path, default=None,
                    help="JSON {step: [skill,...]} draft; unmapped skills stay anytime")
    ap.add_argument("--force", action="store_true", help="replace an existing set")
    ap.add_argument("--no-validate", action="store_true",
                    help="skip the tests/test-registry.sh run at the end")
    args = ap.parse_args()

    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", args.name):
        die(f"bad set name '{args.name}': use a-z, 0-9, dashes")
    source = args.source.resolve()
    if not source.is_dir():
        die(f"source checkout not found: {source}")
    if not REGISTRY.is_file():
        die(f"registry missing: {REGISTRY.relative_to(ROOT)} — "
            f"this tool belongs in the super-board pack repo")

    reg = json.loads(REGISTRY.read_text())
    steps_order = reg.get("lifecycle_steps") or DEFAULT_STEPS
    setdir = ROOT / "skill-sets" / args.name
    if args.name in reg.get("sets", {}):
        if not args.force:
            die(f"set '{args.name}' is already in the registry — "
                f"pick another name, or use --force to re-vendor it")
        if not setdir.exists():
            die(f"registry lists '{args.name}' but {setdir.relative_to(ROOT)} is missing — "
                f"repair the registry by hand before vendoring")

    layout, skills = find_skills(source, args.layout)
    names = [p.name for p in skills]

    draft: dict[str, list[str]] = {}
    if args.steps_json:
        try:
            draft = json.loads(args.steps_json.read_text())
        except (OSError, ValueError) as e:
            die(f"cannot read --steps-json: {e}")
        for step, mapped in draft.items():
            if step not in steps_order:
                die(f"unknown lifecycle step '{step}' (use: {', '.join(steps_order)})")
            for s in mapped:
                if s not in names:
                    die(f"steps draft maps '{s}', which is not vendored (have: {', '.join(names)})")

    # Vendor: skills first, then shared references, then the license files.
    if setdir.exists():
        shutil.rmtree(setdir)
    setdir.mkdir(parents=True)
    skills_root = setdir / "skills" if layout == "nested" else setdir
    for p in skills:
        shutil.copytree(p, skills_root / p.name, ignore=COPY_IGNORE)
    refs_copied = False
    if layout == "nested" and (source / "references").is_dir():
        shutil.copytree(source / "references", setdir / "references", ignore=COPY_IGNORE)
        refs_copied = True
    carried = []
    for pat in LICENSE_PATTERNS:
        for f in sorted(source.glob(pat)):
            if f.is_file():
                shutil.copy2(f, setdir / f.name)
                carried.append(f.name)

    mapped = {s for ms in draft.values() for s in ms}
    entry = {
        "title": args.title or args.name,
        "description": args.description or f"Vendored from {args.url or source.name}.",
        "source": args.url or f"local import ({source})",
        "pinned_ref": git_sha(source) or (f"ref {args.ref}" if args.ref
                                          else f"vendored {dt.date.today().isoformat()}"),
        "license": args.license or detect_license(source),
        "dir": f"skill-sets/{args.name}",
        "layout": layout,
    }
    if layout == "nested":
        entry["nested_skills_dir"] = "skills"
    if refs_copied:
        entry["shared_references_dir"] = "references"
    entry["steps"] = {step: draft.get(step, []) for step in steps_order}
    entry["anytime"] = sorted(set(names) - mapped)
    reg.setdefault("sets", {})[args.name] = entry
    REGISTRY.write_text(json.dumps(reg, indent=2) + "\n")

    pin = entry["pinned_ref"]
    pin = pin[:12] if re.fullmatch(r"[0-9a-f]{40}", pin) else pin
    print(f"skill-set-add: vendored {len(names)} skills from "
          f"{args.url or source} → {entry['dir']} "
          f"(license {entry['license']}, pinned {pin}; "
          f"carried {', '.join(carried) if carried else 'no license files'})")

    if args.no_validate:
        return 0
    r = subprocess.run(["bash", str(ROOT / "tests" / "test-registry.sh")], cwd=ROOT)
    if r.returncode != 0:
        print("skill-set-add: registry validation failed — fix or remove the entry "
              f"and the {entry['dir']} dir", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
