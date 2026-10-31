#!/usr/bin/env bash
# Registry integrity: every mapped skill exists in its vendored set, every
# vendored skill is mapped or anytime, and provenance fields are present.
set -uo pipefail
cd "$(dirname "$0")/.."

fail() { echo "FAIL: $*" >&2; exit 1; }

REG=skill-sets/registry.json
[ -f "$REG" ] || fail "registry missing: $REG"
python3 - "$REG" <<'PY' || exit 1
import json, sys
from pathlib import Path

reg = json.loads(Path(sys.argv[1]).read_text())
steps = reg["lifecycle_steps"]
assert steps == ["plan", "design", "build", "test", "deploy", "maintain"], steps
problems = []
for name, meta in reg["sets"].items():
    d = Path(meta["dir"])
    if not d.is_dir():
        problems.append(f"{name}: set dir missing: {d}")
        continue
    src = d / meta.get("nested_skills_dir", "skills") if meta.get("layout") == "nested" else d
    on_disk = {p.name for p in src.iterdir() if p.is_dir() and (p / "SKILL.md").exists()}
    if not on_disk:
        problems.append(f"{name}: no skills with SKILL.md under {src}")
    if not meta.get("source"):
        problems.append(f"{name}: no source")
    if not meta.get("pinned_ref"):
        problems.append(f"{name}: no pinned_ref")
    if not meta.get("license"):
        problems.append(f"{name}: no license")
    mapped, seen = [], set()
    for step in steps:
        for s in meta.get("steps", {}).get(step, []):
            mapped.append(s)
            # The same skill may serve two steps (pstack maps interrogate under
            # Design AND Test) — that is a feature, not a duplicate.
            seen.add(s)
            if s not in on_disk:
                problems.append(f"{name}: {step} maps missing skill {s}")
    for s in meta.get("anytime", []):
        if s in seen:
            problems.append(f"{name}: {s} both mapped and anytime")
        seen.add(s)
    unmapped = on_disk - seen
    if unmapped:
        problems.append(f"{name}: on disk but not in registry: {', '.join(sorted(unmapped))}")
    ghost = seen - on_disk
    if ghost:
        problems.append(f"{name}: in registry but not on disk: {', '.join(sorted(ghost))}")
if problems:
    print("\n".join(problems))
    sys.exit(1)
print("registry ok: every vendored skill mapped or anytime, every mapping vendored")
PY

rc=$?

# Store-symlink layout: the vendored skills are reached through symlinks (either
# direction — .agents/skills as the physical store with skill-sets/ linking in,
# or the reverse). A dangling link silently vanishes from the iterdir checks
# above, so every link under skill-sets/ must resolve on its own pass. This is
# deliberately direction-agnostic: it holds no matter which side owns the files.
python3 - <<'PY' || rc=1
import os
from pathlib import Path

broken = []
for link in Path("skill-sets").rglob("*"):
    if not link.is_symlink():
        continue
    target = os.readlink(link)
    resolved = target if os.path.isabs(target) else link.parent / target
    if not os.path.exists(resolved):
        broken.append(f"{link} -> {target}")
if broken:
    print("dangling symlinks in skill-sets/:")
    print("\n".join(sorted(broken)))
    raise SystemExit(1)
PY

[ "$rc" -eq 0 ] && echo "PASS: test-registry.sh"
exit "$rc"
