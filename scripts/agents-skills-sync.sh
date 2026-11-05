#!/usr/bin/env bash
# Re-syncs the discoverable copies in .agents/skills/ from their sources.
#
# .agents/skills/<skill> must be REAL directories: ZCode's slash-menu picker
# scans with symlink-following DISABLED, so symlinked skill dirs are invisible
# there. The board's 9 skills (source of truth: skills/, which upstream tests
# and readme-sync depend on) are therefore content-copies here, kept honest by
# tests/test-agents-skills-sync.sh. The three vendored sets are inverted: the
# physical files live in .agents/skills/ and skill-sets/<set>/<skill> holds
# relative symlinks back (install.sh copies through them fine).
set -euo pipefail
cd "$(dirname "$0")/.."

BOARD_SKILLS="super-board super-build super-qa super-review super-collect super-plan ui-refine-loop visual git-sync"

for s in $BOARD_SKILLS; do
  [ -d "skills/$s" ] || { echo "missing skills/$s" >&2; exit 1; }
  rm -rf ".agents/skills/$s"
  cp -R "skills/$s" ".agents/skills/$s"
done
echo "synced $BOARD_SKILLS into .agents/skills/"
