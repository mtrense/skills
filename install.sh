#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Workflows are top-level directories that contain `skills/`, `agents/`, and/or
# `workflows/` (the last holding single-file Workflow scripts, `*.js`).
WORKFLOWS=(codebase-survey common milestone-driven research)

usage() {
  cat <<EOF
Usage: $(basename "$0") <workflow|all> [target]

Workflows:
$(printf '  %s\n' "${WORKFLOWS[@]}")
  all  -- install every workflow above

Target defaults to \$HOME (global install). Pass a project path for a
per-project install (skills land in <target>/.claude/skills, agents in
<target>/.claude/agents, workflow scripts in <target>/.claude/workflows).

Examples:
  $(basename "$0") all
  $(basename "$0") milestone-driven
  $(basename "$0") research /path/to/project
EOF
}

if [ $# -lt 1 ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 1
fi

SELECTION="$1"
TARGET="${2:-$HOME}"
SKILLS_DST="$TARGET/.claude/skills"
AGENTS_DST="$TARGET/.claude/agents"
WORKFLOWS_DST="$TARGET/.claude/workflows"

selected=()
if [ "$SELECTION" = "all" ]; then
  selected=("${WORKFLOWS[@]}")
else
  found=0
  for wf in "${WORKFLOWS[@]}"; do
    if [ "$wf" = "$SELECTION" ]; then
      selected=("$wf")
      found=1
      break
    fi
  done
  if [ $found -eq 0 ]; then
    echo "Error: unknown workflow '$SELECTION'" >&2
    echo >&2
    usage >&2
    exit 1
  fi
fi

echo "Installing workflows: ${selected[*]}"
echo "  Skills target:    $SKILLS_DST"
echo "  Agents target:    $AGENTS_DST"
echo "  Workflows target: $WORKFLOWS_DST"
echo

mkdir -p "$SKILLS_DST" "$AGENTS_DST" "$WORKFLOWS_DST"

skill_count=0
agent_count=0
workflow_count=0

for wf in "${selected[@]}"; do
  wf_dir="$SCRIPT_DIR/$wf"
  [ -d "$wf_dir" ] || { echo "  (skip) $wf: directory missing"; continue; }

  skills_src="$wf_dir/skills"
  if [ -d "$skills_src" ]; then
    for skill_dir in "$skills_src"/*/; do
      [ -d "$skill_dir" ] || continue
      skill_name="$(basename "$skill_dir")"
      dst="$SKILLS_DST/$skill_name"

      if [ -L "$dst" ] || [ -d "$dst" ]; then
        rm -rf "$dst"
      fi

      ln -s "$skill_dir" "$dst"
      echo "  Linked skill    [$wf] $skill_name"
      skill_count=$((skill_count + 1))
    done
  fi

  agents_src="$wf_dir/agents"
  if [ -d "$agents_src" ]; then
    for agent_file in "$agents_src"/*.md; do
      [ -f "$agent_file" ] || continue
      agent_name="$(basename "$agent_file")"
      dst="$AGENTS_DST/$agent_name"

      if [ -L "$dst" ] || [ -f "$dst" ]; then
        rm -f "$dst"
      fi

      ln -s "$agent_file" "$dst"
      echo "  Linked agent    [$wf] ${agent_name%.md}"
      agent_count=$((agent_count + 1))
    done
  fi

  workflows_src="$wf_dir/workflows"
  if [ -d "$workflows_src" ]; then
    for workflow_file in "$workflows_src"/*.js; do
      [ -f "$workflow_file" ] || continue
      workflow_name="$(basename "$workflow_file")"
      dst="$WORKFLOWS_DST/$workflow_name"

      if [ -L "$dst" ] || [ -f "$dst" ]; then
        rm -f "$dst"
      fi

      ln -s "$workflow_file" "$dst"
      echo "  Linked workflow [$wf] ${workflow_name%.js}"
      workflow_count=$((workflow_count + 1))
    done
  fi
done

echo
echo "Done. Installed $skill_count skills, $agent_count agents, and $workflow_count workflows."
