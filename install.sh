#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/skills"
AGENTS_SRC="$SCRIPT_DIR/agents"

# Default: install globally; pass a project path to install per-project
TARGET="${1:-$HOME}"
SKILLS_DST="$TARGET/.claude/skills"
AGENTS_DST="$TARGET/.claude/agents"

echo "Installing all skills and agents..."
echo "  Skills source: $SKILLS_SRC"
echo "  Skills target: $SKILLS_DST"
echo "  Agents source: $AGENTS_SRC"
echo "  Agents target: $AGENTS_DST"
echo

mkdir -p "$SKILLS_DST"

skill_count=0
for skill_dir in "$SKILLS_SRC"/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name="$(basename "$skill_dir")"
  dst="$SKILLS_DST/$skill_name"

  # Remove existing (symlink or directory) so we can recreate
  if [ -L "$dst" ] || [ -d "$dst" ]; then
    rm -rf "$dst"
  fi

  ln -s "$skill_dir" "$dst"
  echo "  Linked skill   $skill_name"
  skill_count=$((skill_count + 1))
done

agent_count=0
if [ -d "$AGENTS_SRC" ]; then
  mkdir -p "$AGENTS_DST"
  for agent_file in "$AGENTS_SRC"/*.md; do
    [ -f "$agent_file" ] || continue
    agent_name="$(basename "$agent_file")"
    dst="$AGENTS_DST/$agent_name"

    # Remove existing (symlink or file) so we can recreate
    if [ -L "$dst" ] || [ -f "$dst" ]; then
      rm -f "$dst"
    fi

    ln -s "$agent_file" "$dst"
    echo "  Linked agent   ${agent_name%.md}"
    agent_count=$((agent_count + 1))
  done
fi

echo
echo "Done. Installed $skill_count skills and $agent_count agents."
echo
echo "Usage:"
echo "  Global install (default):  ./install.sh"
echo "  Per-project install:       ./install.sh /path/to/project"
