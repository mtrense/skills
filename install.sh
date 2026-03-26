#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/skills"

# Default: install globally; pass a project path to install per-project
TARGET="${1:-$HOME}"
SKILLS_DST="$TARGET/.claude/skills"

echo "Installing all skills..."
echo "  Source: $SKILLS_SRC"
echo "  Target: $SKILLS_DST"
echo

mkdir -p "$SKILLS_DST"

count=0
for skill_dir in "$SKILLS_SRC"/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name="$(basename "$skill_dir")"
  dst="$SKILLS_DST/$skill_name"

  # Remove existing (symlink or directory) so we can recreate
  if [ -L "$dst" ] || [ -d "$dst" ]; then
    rm -rf "$dst"
  fi

  ln -s "$skill_dir" "$dst"
  echo "  Linked $skill_name"
  count=$((count + 1))
done

echo
echo "Done. Installed $count skills."
echo
echo "Usage:"
echo "  Global install (default):  ./install.sh"
echo "  Per-project install:       ./install.sh /path/to/project"
