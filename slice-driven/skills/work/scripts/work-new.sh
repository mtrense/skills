#!/usr/bin/env bash
# Create a new work item file with frontmatter and empty body sections.
# Usage: work-new.sh <feature|chore|probe> <slug> <title...> [--dir work-dir]
# Prints the created file path. The caller (skill) fills in the body.
set -euo pipefail

type="$1"
slug="$2"
shift 2
dir="work"
title_parts=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) dir="$2"; shift 2 ;;
    *) title_parts+=("$1"); shift ;;
  esac
done
title="${title_parts[*]}"

case "$type" in
  feature | chore | probe) ;;
  *) echo "invalid type: $type (want feature|chore|probe)" >&2; exit 1 ;;
esac
if [ -z "$title" ]; then
  echo "usage: work-new.sh <type> <slug> <title...>" >&2
  exit 1
fi

mkdir -p "$dir"
last="$(find "$dir" -maxdepth 1 -name '[0-9][0-9][0-9][0-9]-*.md' -exec basename {} \; | sort | tail -1 | cut -c1-4)"
next=$((10#${last:-0} + 1))
printf -v nnnn '%04d' "$next"
file="$dir/$nnnn-$slug.md"
if [ -e "$file" ]; then
  echo "$file already exists" >&2
  exit 1
fi

cat > "$file" <<EOF
---
id: $next
slug: $slug
title: $title
type: $type
status: shaped
entered: $(date +%F)
blocked_by: []
branch: null
decision: null
---

## Outcome

## Examples

## Evidence of done

## Decisions touched

## Tasks

## Results
EOF

echo "$file"
