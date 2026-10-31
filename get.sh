#!/usr/bin/env bash
# super-board one-line installer (suber-super-board fork).
#
#   curl -fsSL https://raw.githubusercontent.com/vuquangkhtn/suber-super-board/main/get.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/vuquangkhtn/suber-super-board/main/get.sh | bash -s -- --protect-main
#
# Options (everything else that starts with "-" goes straight to install.sh):
#   --target <dir>        project to install into (default: the current folder)
#   --ref <tag|branch>    which version to fetch (default: the latest release)
#   --no-helper-skills    install no vendored skill sets (default: mattpocock)
#   -h, --help            show this help
# Passed through to install.sh: --no-hooks, --protect-main, --sets=a,b,
# --hosts=a,b (skill sets and agent CLIs). Onboard's own flag is --set=<one set>
# (deprecated alias: --sets) — install.sh's --sets is the comma list. Onboard can
# also be run with --set/--agents instead of answering its questions.
#
# Environment:
#   SUPER_BOARD_REF       same as --ref
#   SUPER_BOARD_REPO      GitHub owner/repo to fetch from (default vuquangkhtn/suber-super-board)
#   SUPER_BOARD_TARBALL   exact tarball URL to fetch instead (file:// works; used by tests)
#
# Written for bash 3.2 (stock macOS). The whole script lives in main(), called on
# the last line, so a download cut off halfway through runs nothing.

set -euo pipefail

say()  { printf '%s\n' "$*"; }
warn() { printf '⚠️  %s\n' "$*" >&2; }
die()  { printf '❌ %s\n' "$*" >&2; exit "${2:-1}"; }
have() { command -v "$1" >/dev/null 2>&1; }

usage() { sed -n '2,22p' "${BASH_SOURCE[0]:-$0}" 2>/dev/null | sed 's/^# \{0,1\}//' || true; }

main() {
  local target="" ref="${SUPER_BOARD_REF:-}"
  local repo="${SUPER_BOARD_REPO:-vuquangkhtn/suber-super-board}"
  local pass=()

  while [ $# -gt 0 ]; do
    case "$1" in
      --target) [ $# -ge 2 ] || die "--target needs a folder" 64; target="$2"; shift 2 ;;
      --target=*) target="${1#--target=}"; shift ;;
      --ref) [ $# -ge 2 ] || die "--ref needs a tag or branch name" 64; ref="$2"; shift 2 ;;
      --ref=*) ref="${1#--ref=}"; shift ;;
      -h|--help) usage; exit 0 ;;
      -*) pass+=("$1"); shift ;;
      *) [ -z "$target" ] || die "two target folders given: '$target' and '$1'" 64; target="$1"; shift ;;
    esac
  done
  target="${target:-$PWD}"

  # --- safety -----------------------------------------------------------
  if [ "$(id -u)" -eq 0 ]; then
    die "please don't run this as root (or with sudo). Run it as your normal user, inside your project folder." 1
  fi
  [ -d "$target" ] || die "the target '$target' is not a folder. Create it first, or pass --target <an existing folder>." 64
  target="$(cd "$target" && pwd)"

  say "🧩 super-board installer"
  say "   target: $target"

  # --- prerequisites ----------------------------------------------------
  local fetch=""
  if have curl && have tar; then fetch="tar"
  elif have git; then fetch="git"
  else die "I need either curl + tar, or git, to download super-board. Install one of those and run this again." 69
  fi
  have python3 || die "python3 is missing. super-board's installer and scripts use it. Install Python 3 (https://www.python.org/downloads/) and run this again." 69

  # One grouped line: what is here ✓, what is not ✗ (onboard's 🔍 Checks installs it).
  local later="" ok="" t
  for t in curl tar git python3 gh jq node; do
    case "$t" in
      curl|tar) [ "$fetch" = "tar" ] || continue ;;
      git) [ "$fetch" = "git" ] || continue ;;
    esac
    if have "$t" && { [ "$t" != node ] || have npx; }; then ok="${ok:+$ok · }$t"; else later="$later $t"; fi
  done
  say "🔍 checking what you need"
  if [ -n "$later" ]; then
    say "   ✓ $ok   ✗$later (🔍 Checks in onboard installs them)"
  else
    say "   ✓ $ok"
  fi

  # --- download ---------------------------------------------------------
  local tmp
  tmp="$(mktemp -d 2>/dev/null || mktemp -d -t super-board)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT INT TERM

  local url="${SUPER_BOARD_TARBALL:-}" label
  if [ -n "$url" ]; then
    fetch="tar"; label="$url"
  elif [ "$fetch" = "tar" ]; then
    if [ -z "$ref" ]; then
      ref="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
        | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("tag_name",""))
except Exception: print("")' 2>/dev/null || true)"
      if [ -z "$ref" ]; then warn "couldn't find a published release; using the main branch instead."; ref="main"; fi
    fi
    url="https://codeload.github.com/$repo/tar.gz/$ref"
    label="$repo@$ref"
  else
    label="$repo@${ref:-default branch}"
  fi

  say "📦 downloading $label"
  local src=""
  if [ "$fetch" = "tar" ]; then
    curl -fsSL "$url" -o "$tmp/pack.tgz" || die "download failed: $url. Check the version name and your internet connection." 1
    mkdir -p "$tmp/x"
    tar -xzf "$tmp/pack.tgz" -C "$tmp/x" || die "the download isn't a valid tarball: $url" 1
    if [ -f "$tmp/x/install.sh" ]; then src="$tmp/x"
    else
      local d
      for d in "$tmp"/x/*/; do
        if [ -f "${d}install.sh" ]; then src="${d%/}"; break; fi
      done
    fi
  else
    if [ -n "$ref" ]; then
      git clone -q --depth 1 --branch "$ref" "https://github.com/$repo.git" "$tmp/x" || die "git clone of $label failed." 1
    else
      git clone -q --depth 1 "https://github.com/$repo.git" "$tmp/x" || die "git clone of $label failed." 1
    fi
    src="$tmp/x"
  fi
  [ -n "$src" ] && [ -f "$src/install.sh" ] || die "the download has no install.sh at its top level — is '$label' really super-board?" 1
  local version="?"
  [ -f "$src/VERSION" ] && version="$(tr -d '[:space:]' < "$src/VERSION")"

  # --- install ----------------------------------------------------------
  # Quiet mode: install.sh prints only its "🔧 installing" group; the summary is ours.
  SUPER_BOARD_QUIET_NEXT=1 bash "$src/install.sh" ${pass[@]+"${pass[@]}"} "$target" || die "install.sh stopped with an error (see above). Nothing else was changed after that point." 1

  # --- skill sets -------------------------------------------------------
  # install.sh installed the chosen vendored skill sets (mattpocock by default)
  # into .agents/skills and printed one ✓ line per set above — no npx, no
  # network. Its record lands in .agents/skill-sets.json.
  local sets_note="installed → .agents/skills (record: .agents/skill-sets.json)"
  case " ${pass[*]-} " in *" --no-helper-skills "*) sets_note="skipped (--no-helper-skills)" ;; esac

  # --- summary ----------------------------------------------------------
  say "🧠 skill sets: $sets_note"
  say "🎉 super-board $version is installed"
  say "👉 next: open Claude Code here and run /super-board onboard"
}

main "$@"
