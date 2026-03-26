#!/usr/bin/env bash
# init-workflow.sh — Bootstrap the AI-native engineering workflow files
# Run this in your project root to create ROADMAP.md and PLAN.md

set -euo pipefail

if [ -f ROADMAP.md ]; then
  echo "ROADMAP.md already exists. Skipping."
else
  cat > ROADMAP.md << 'EOF'
# Roadmap

<!-- 
  This file tracks high-level milestones for the project.
  It is append-only: milestones are added and their status updated, but never deleted.
  
  Statuses: open | in progress | completed
  
  Workflow: strategic-planning → milestone-breakdown → task-implementation → milestone-closing
-->

EOF
  echo "Created ROADMAP.md"
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
