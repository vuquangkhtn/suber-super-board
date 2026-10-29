#!/usr/bin/env bash
# super-board installer.
# Copies skills/, scripts/, workflows/ and the guard hooks into the target
# project's .claude/ tree, and merges the hook settings into
# .claude/settings.json (backed up first, never duplicated).
#
# Usage:
#   ./install.sh [--no-hooks] [--protect-main] [--sets=...] [--hosts=...] [target]
# Defaults to the current working directory. --no-hooks skips the guard hooks
# and leaves settings.json untouched. --protect-main also wires the opt-in
# guard that blocks direct and force pushes to main/master/base_branch; with
# --no-hooks it installs that one guard alone. The installer asks nothing:
# super-board onboard asks the questions (protect main is one of them).
#
# This fork (suber-super-board) also installs vendored skill sets from
# skill-sets/ (see skill-sets/registry.json) into the target's agent-neutral
# .agents/skills/ tree:
#   --sets=<list>        comma list of mattpocock|pstack|agent-skills
#                        (default: mattpocock). A skill name already installed
#                        by an earlier set in the list wins; later ones are
#                        recorded as skipped in .agents/skill-sets.json.
#   --no-helper-skills   install no skill sets (upstream flag, kept working)
#   --hosts=<list>       comma list of claude,codex,opencode,copilot,zcode,other.
#                        claude is always wired (the board pack lives in
#                        .claude/); zcode/codex/opencode read .agents/skills
#                        natively so need no links; set skills additionally get
#                        .claude/skills symlinks so Claude shows them; copilot
#                        and other are recorded for onboard's AGENTS.md notes.
#                        Unknown value exits 64. Default: detect from the target.
#
# Output is grouped with emojis, one line per group of files (failures still name
# the file). Environment: SUPER_BOARD_QUIET_NEXT=1 prints only the "🔧 installing"
# group — get.sh sets it and prints its own header and summary around it.
#
# An older super-board already in the target (a different skills/super-board/VERSION,
# or one with no VERSION) is recorded in .claude/super-board/upgrade.json
# {from, to, added_skills}; onboard's 🔍 Checks finishes the upgrade and lists it.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS=1
PROTECT=0
SETS="mattpocock"
HOSTS=""
TARGET=""
for arg in "$@"; do
  case "$arg" in
    --no-hooks) HOOKS=0 ;;
    --protect-main) PROTECT=1 ;;
    --sets=*) SETS="${arg#--sets=}" ;;
    --hosts=*) HOSTS="${arg#--hosts=}" ;;
    --no-helper-skills) SETS="" ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    -*) echo "unknown option: $arg" >&2; exit 64 ;;
    *) TARGET="$arg" ;;
  esac
done
TARGET="${TARGET:-$PWD}"

# Which agent CLIs we announce/wire. claude is mandatory (board pack lives in
# .claude/); everything else is recorded so onboard can write the right notes
# into AGENTS.md. Auto-detect from the target when --hosts is not given.
KNOWN_HOSTS="claude codex opencode copilot zcode other"
for h in $(echo "$HOSTS" | tr ',' ' '); do
  ok=0
  for k in $KNOWN_HOSTS; do [ "$h" = "$k" ] && ok=1; done
  [ "$ok" -eq 1 ] || { echo "unknown host: $h (use $KNOWN_HOSTS)" >&2; exit 64; }
done
if [ -z "$HOSTS" ]; then
  HOSTS="claude"
  [ -d "$TARGET/.codex" ] && HOSTS="$HOSTS,codex"
  [ -d "$TARGET/.opencode" ] && HOSTS="$HOSTS,opencode"
  [ -d "$TARGET/.zcode" ] && HOSTS="$HOSTS,zcode"
  { [ -d "$TARGET/.copilot" ] || [ -f "$TARGET/.github/copilot-instructions.md" ]; } && HOSTS="$HOSTS,copilot"
fi
case ",$HOSTS," in
  *,claude,*) : ;;
  *) HOSTS="claude,$HOSTS" ;;
esac

# Primary: the board and its lanes. Secondary: standalone helpers the lanes
# can call (visual, git-sync, ui-refine-loop). Worktree cleanup (cleanup-wt) is a
# hook, not a skill: it ships with the guard hooks below.
PRIMARY_SKILLS="super-board super-build super-qa super-review super-collect"
SECONDARY_SKILLS="visual git-sync ui-refine-loop"

if [ ! -d "$TARGET" ]; then
  echo "target directory not found: $TARGET" >&2
  exit 64
fi

QUIET="${SUPER_BOARD_QUIET_NEXT:-}"
PACK_VERSION="$(tr -d '[:space:]' < "$REPO_ROOT/VERSION" 2>/dev/null || echo '?')"

# Record an upgrade BEFORE the copy overwrites the old VERSION.
PREV_VERSION=""
if [ -d "$TARGET/.claude/skills/super-board" ]; then
  PREV_VERSION="$(tr -d '[:space:]' < "$TARGET/.claude/skills/super-board/VERSION" 2>/dev/null || echo 'older')"
  [ -n "$PREV_VERSION" ] || PREV_VERSION="older"
fi
ADDED_SKILLS=""
if [ -n "$PREV_VERSION" ]; then
  for skill in $PRIMARY_SKILLS $SECONDARY_SKILLS; do
    [ -e "$TARGET/.claude/skills/$skill" ] || ADDED_SKILLS="$ADDED_SKILLS $skill"
  done
fi

[ -n "$QUIET" ] || echo "🧩 super-board $PACK_VERSION → $TARGET"
echo "🔧 installing"

# Resolve all skill paths before replacing anything. A destination can contain
# the pack (or a linked source skill); clearing it would destroy our input.
# A destination inside its source would instead recursively copy into itself.
python3 - "$REPO_ROOT" "$TARGET" $PRIMARY_SKILLS $SECONDARY_SKILLS <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
target = Path(sys.argv[2])
for skill in sys.argv[3:]:
    src = (root / "skills" / skill).resolve()
    dest = (target / ".claude" / "skills" / skill).resolve()
    if src == dest:
        continue
    if dest == root or dest in root.parents or dest in src.parents or src in dest.parents:
        sys.exit(f"    ✗ refusing to install {skill}: source and destination overlap ({dest})")
PY

mkdir -p "$TARGET/.claude/skills" "$TARGET/.claude/bin"

# A project may keep the real skill directories elsewhere and symlink them into
# .claude/skills — a layout some repos use to share one tree between .claude and
# another agent host. `cp -R src dest/` fails outright on such a target ("Not a
# directory"), so resolve the link and write to where it actually points. That
# keeps the project's chosen layout instead of replacing it with a plain copy.
for skill in $PRIMARY_SKILLS $SECONDARY_SKILLS; do
  if [ ! -d "$REPO_ROOT/skills/$skill" ]; then
    echo "    ✗ missing $skill in repo — skipping" >&2
    continue
  fi
  dest="$TARGET/.claude/skills/$skill"
  note=""
  if [ -L "$dest" ]; then
    # `cd -P` walks the link to its physical target in one step. Do NOT rebuild
    # the path from `readlink` output: `cd ""` SUCCEEDS in bash, so an empty
    # readlink silently leaves you in the parent, and the rm below then empties
    # .claude/skills instead of one skill. That is not hypothetical — it deleted
    # 190 entries on a real repo on 2026-08-20 before this comment existed.
    resolved=$(cd -P "$dest" 2>/dev/null && pwd) || resolved=""
    if [ -z "$resolved" ]; then
      echo "    ✗ $skill is a symlink pointing nowhere — skipping rather than replacing it" >&2
      continue
    fi
    dest="$resolved"
    note=" (via symlink → ${resolved#$TARGET/})"
  fi

  # Belt and braces: whatever the resolution produced, it must be a path ENDING
  # in this skill's own name. Anything else is a bug in the line above, and the
  # blast radius of being wrong here is the user's entire skills tree.
  case "$dest" in
    */"$skill") : ;;
    *) echo "    ✗ refusing to write $skill: resolved to '$dest', which is not a $skill directory" >&2
       continue ;;
  esac

  # A self-vendored project can expose this very source through one or more
  # links. There is nothing to copy in that case; clearing dest erases src too.
  if [ "$REPO_ROOT/skills/$skill" -ef "$dest" ]; then
    echo "   ✓ $skill already uses the source directory"
    continue
  fi

  # Replace the contents, not the directory itself, so a symlink stays a symlink.
  mkdir -p "$dest"
  rm -rf "${dest:?}/"* 2>/dev/null || true
  cp -R "$REPO_ROOT/skills/$skill/." "$dest/"
  [ -z "$note" ] || echo "   ✓ $skill$note"
done

# File destinations can be links into the pack too. -ef follows symlinks and
# also recognizes hard links, so cp never tries to overwrite its own input.
copy_file() {
  if [ ! "$1" -ef "$2" ]; then
    cp "$1" "$2"
  fi
}

for script in super-board-github-read.py super-board-run.sh super-board-gh-guard.sh super-board-card.sh super-board-status.py super-board-wave-plan.sh super-board-codex-lane.sh super-board-codex-wave.sh super-board-deps.sh super-board-preflight.sh super-board-merge-gate.sh super-board-merge-policy.py super-board-approval.py super-board-env-check.sh super-board-agents-md.py super-board-settings.py super-board-setup.py super-board-usage.sh super-board-throttle.sh super-board-host.sh super-board-pr-body.sh super-review-file-refactor.sh super-qa-file-bug.sh super-board-stop.sh; do
  if [ -f "$REPO_ROOT/scripts/$script" ]; then
    copy_file "$REPO_ROOT/scripts/$script" "$TARGET/.claude/bin/$script"
    chmod +x "$TARGET/.claude/bin/$script"
  fi
done

mkdir -p "$TARGET/.claude/workflows"
for wf in super-board-wave.js ui-refine-loop.js; do
  if [ -f "$REPO_ROOT/workflows/$wf" ]; then
    copy_file "$REPO_ROOT/workflows/$wf" "$TARGET/.claude/workflows/$wf"
  fi
done
echo "   ✓ skills, scripts and workflows → .claude/"

# ── Vendored skill sets (this fork) ─────────────────────────────────────────
# Copies each chosen set from skill-sets/ (registry.json) into the target's
# agent-neutral .agents/skills/, and records what landed in
# .agents/skill-sets.json — onboard's 🧩 Skills step and the AGENTS.md
# skill-map read that record back. With claude in --hosts, each installed skill
# also gets a relative .claude/skills/<skill> symlink so Claude's skill list
# shows it. A destination that already exists is never clobbered unless the
# previous skill-sets.json record says we installed it.
if [ -n "$SETS" ]; then
  if [ ! -f "$REPO_ROOT/skill-sets/registry.json" ]; then
    echo "   ! skill-sets/registry.json missing — skipping skill sets" >&2
  else
    mkdir -p "$TARGET/.agents/skills"
    python3 - "$REPO_ROOT" "$TARGET" "$SETS" "$HOSTS" <<'PY'
import json, os, shutil, sys, time
from pathlib import Path

repo, target, sets_arg, hosts_arg = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], sys.argv[4]
hosts = [h for h in hosts_arg.split(",") if h]
registry = json.loads((repo / "skill-sets" / "registry.json").read_text())
record_path = target / ".agents" / "skill-sets.json"
try:
    prev = json.loads(record_path.read_text())
except Exception:
    prev = {}
owned = {s["name"]: set(s.get("installed", [])) for s in prev.get("sets", [])}

def owned_by_us(setname, skill):
    return skill in owned.get(setname, ())

def copy_tree(src: Path, dest: Path):
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(src, dest)

def normalize_shared_refs(dest: Path):
    # Shared checklists live at the set root; in the flattened tree they sit one
    # level higher than the skills that point into them, so the two deep links
    # need one level less. Only ever called on files we just copied.
    for f in dest.rglob("*"):
        if not f.is_file() or f.suffix not in {".md", ".txt"}:
            continue
        text = f.read_text(errors="replace")
        if "../../../references/" in text:
            f.write_text(text.replace("../../../references/", "../../references/"))

record = {"version": 1, "hosts": hosts, "installed_at": time.strftime("%Y-%m-%dT%H:%M:%S"), "sets": []}
prev_sets = {s["name"]: s for s in prev.get("sets", [])}
current_names = set()
for setname in [s for s in sets_arg.split(",") if s]:
    meta = registry["sets"].get(setname)
    if meta is None:
        known = ", ".join(sorted(registry["sets"]))
        print(f"    ✗ unknown skill set: {setname} (use {known})", file=sys.stderr)
        sys.exit(64)
    current_names.add(setname)
    setdir = repo / meta["dir"]
    nested = meta.get("layout") == "nested"
    src_root = setdir / meta.get("nested_skills_dir", "skills") if nested else setdir
    skills = sorted(d.name for d in src_root.iterdir()
                    if d.is_dir() and (d / "SKILL.md").exists())
    installed, skipped, linked = [], [], 0
    for skill in skills:
        src = src_root / skill
        dest = target / ".agents" / "skills" / skill
        fresh = False
        if dest.exists() or dest.is_symlink():
            real_src, real_dest = os.path.realpath(src), os.path.realpath(dest)
            if real_src == real_dest:
                installed.append(skill)  # self-vendored target: the link IS the source
            elif owned_by_us(setname, skill) and not dest.is_symlink():
                copy_tree(src, dest)     # our own previous install: refresh it
                fresh = True
                installed.append(skill)
            else:
                skipped.append(skill)
                continue
        else:
            shutil.copytree(src, dest)
            fresh = True
            installed.append(skill)
        if nested and fresh:
            refs = setdir / meta.get("shared_references_dir", "references")
            if refs.is_dir():
                shutil.copytree(refs, target / ".agents" / "skills" / "references", dirs_exist_ok=True)
            normalize_shared_refs(dest)
        if "claude" in hosts:
            link = target / ".claude" / "skills" / skill
            link.parent.mkdir(parents=True, exist_ok=True)
            if not link.exists() and not link.is_symlink():
                os.symlink(f"../../.agents/skills/{skill}", link)
                linked += 1
    licdir = target / ".agents" / "skill-set-licenses" / setname
    for pat in ("LICENSE*", "NOTICE*", "COPYING*"):
        for f in setdir.glob(pat):
            licdir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(f, licdir / f.name)
    note = f", claude: {linked} links" if "claude" in hosts else ""
    extra = f", skipped: {', '.join(skipped)}" if skipped else ""
    print(f"   ✓ skill set {setname}: {len(installed)} skills → .agents/skills{note}{extra}")
    record["sets"].append({
        "name": setname, "title": meta.get("title", setname), "source": meta.get("source", ""),
        "pinned_ref": meta.get("pinned_ref", ""), "license": meta.get("license", ""),
        "installed": installed, "skipped": skipped,
        # Step mapping filtered to what actually landed, so the target record is
        # self-sufficient: onboard's skill-map never needs the original registry.
        "steps": {step: [s for s in meta.get("steps", {}).get(step, []) if s in installed]
                  for step in registry.get("lifecycle_steps", [])},
        "anytime": [s for s in meta.get("anytime", []) if s in installed],
        "maintain_fallback": meta.get("maintain_fallback", ""),
    })
# A set installed by an earlier run keeps its record entry: its files are still
# on disk, so the skill-map must keep describing (and refreshing) them.
for name, entry in prev_sets.items():
    if name not in current_names:
        record["sets"].append(entry)
tmp = record_path.with_suffix(".json.tmp")
tmp.write_text(json.dumps(record, indent=2) + "\n")
os.replace(tmp, record_path)
print("   📦 record → .agents/skill-sets.json")
PY
  fi
fi

SETTINGS_PY="$REPO_ROOT/scripts/super-board-settings.py"
# Stdlib-only merge (scripts/super-board-settings.py): keeps every existing key
# and hook, adds each guard command once per event + matcher, backs the file up
# before writing, and leaves an invalid settings.json untouched (exit 2).
# Prints one summary word for the settings line; the helper's own lines (an
# invalid-JSON refusal) go to stderr untouched.
merge_settings() {
  local had=0 res rc=0
  [ -f "$TARGET/.claude/settings.json" ] && had=1
  res=$(python3 "$SETTINGS_PY" hooks "$TARGET/.claude/settings.json" "$@" 2>&1) || rc=$?
  if [ "$rc" -eq 2 ]; then printf '%s\n' "$res" >&2; echo "not valid JSON — left untouched"
  elif echo "$res" | grep -q "already present"; then echo "already present"
  elif [ "$had" -eq 1 ]; then echo "backup kept"
  else echo "new file"; fi
}

if [ "$HOOKS" -eq 1 ]; then
  mkdir -p "$TARGET/.claude/hooks"
  # hooks/*.py only: hooks/dev/ holds gates for repos that author skills, never installed.
  n=0
  for h in "$REPO_ROOT"/hooks/*.py; do
    [ -f "$h" ] || continue
    copy_file "$h" "$TARGET/.claude/hooks/$(basename "$h")"
    chmod +x "$TARGET/.claude/hooks/$(basename "$h")"
    n=$((n + 1))
  done
  SNIPPETS="$REPO_ROOT/hooks/settings-snippet.json"
  if [ "$PROTECT" -eq 1 ]; then SNIPPETS="$SNIPPETS $REPO_ROOT/hooks/settings-protect-main.json"; fi
  # shellcheck disable=SC2086
  echo "   🛡️  $n guard hooks → .claude/settings.json ($(merge_settings $SNIPPETS))"
elif [ "$PROTECT" -eq 1 ]; then
  # --no-hooks --protect-main: the one guard asked for, nothing else. This is the
  # command onboard names when its protect-main question finds no guard script.
  mkdir -p "$TARGET/.claude/hooks"
  copy_file "$REPO_ROOT/hooks/guard-protected-push.py" "$TARGET/.claude/hooks/guard-protected-push.py"
  chmod +x "$TARGET/.claude/hooks/guard-protected-push.py"
  echo "   🛡️  --no-hooks: only the push guard → .claude/settings.json ($(merge_settings "$REPO_ROOT/hooks/settings-protect-main.json"))"
else
  echo "   ⏭️  guard hooks skipped (--no-hooks)"
fi

# AGENTS.md: a re-install refreshes the managed super-board block and touches
# nothing outside its markers. No block yet → onboard writes it (with consent).
if [ -f "$TARGET/AGENTS.md" ] && grep -q '^<!-- super-board:begin' "$TARGET/AGENTS.md"; then
  python3 "$REPO_ROOT/scripts/super-board-agents-md.py" block --root "$TARGET" \
    --template "$REPO_ROOT/skills/super-board/references/agents-md-block.md" \
    --version "$PACK_VERSION" >/dev/null 2>&1 \
    && echo "   📜 AGENTS.md: super-board block refreshed" \
    || echo "   ! AGENTS.md: couldn't refresh the super-board block — onboard repairs it"
fi
if [ -f "$TARGET/CLAUDE.md" ] && ! grep -m1 -v '^[[:space:]]*$' "$TARGET/CLAUDE.md" | grep -qx '@AGENTS.md'; then
  echo "   ! CLAUDE.md holds its own rules — onboard offers a merge"
fi

# Upgrade record for onboard's 🔍 Checks (it migrates config, labels, columns).
if [ -n "$PREV_VERSION" ] && [ "$PREV_VERSION" != "$PACK_VERSION" ]; then
  mkdir -p "$TARGET/.claude/super-board"
  python3 - "$TARGET/.claude/super-board/upgrade.json" "$PREV_VERSION" "$PACK_VERSION" $ADDED_SKILLS <<'PY'
import json, sys, time
path, frm, to, added = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
try:
    old = json.load(open(path))
except Exception:
    old = {}
rec = {"from": old.get("from", frm), "to": to, "added_skills": sorted(set(old.get("added_skills", []) + added)),
       "at": time.strftime("%Y-%m-%dT%H:%M:%S")}
json.dump(rec, open(path, "w"), indent=2)
PY
  echo "   ⬆️  upgrade from $PREV_VERSION — onboard finishes it (config, labels, columns)"
fi

if [ -z "$QUIET" ]; then
  echo "🎉 super-board $PACK_VERSION is installed"
  echo "👉 next: open Claude Code here and run /super-board onboard"
fi
