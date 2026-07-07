#!/usr/bin/env bash
# init-workflow.sh — Bootstrap the AI-native milestone-driven workflow files
# Run this in your project root to create ROADMAP.md, roadmap/, and PLAN.md

set -euo pipefail

if [ -f ROADMAP.md ]; then
  echo "ROADMAP.md already exists. Skipping."
else
  cat > ROADMAP.md << 'EOF'
# Roadmap

<!--
  Index of project milestones. This file holds only a one-line summary per
  milestone so it stays cheap to load; the full content for each milestone
  (value, outcome, success criteria, notes, closing notes) lives in its own
  file under roadmap/NNNN-slug.md.

  Each entry is one line:
    NNNN-slug.md — [status] one-line summary of what the milestone achieves

  Statuses: open | in progress | completed
  Append-only: add milestones and update their status/summary, never delete a line.
  Numbers are zero-padded and sequential (0001, 0002, ...).

  Workflow: strategic-planning → milestone-breakdown → task-implementation → milestone-closing
-->

EOF
  echo "Created ROADMAP.md"
fi

if [ -d roadmap ]; then
  echo "roadmap/ already exists. Skipping."
else
  mkdir roadmap
  echo "Created roadmap/ (one file per milestone: roadmap/NNNN-slug.md)"
fi

if [ -f PLAN.md ]; then
  echo "PLAN.md already exists. Skipping."
else
  cat > PLAN.md << 'EOF'
# Plan

> Ready for first milestone breakdown.
EOF
  echo "Created PLAN.md"
fi

echo ""
echo "Workflow initialized. Next step: use the strategic-planning skill to add your first milestone."
