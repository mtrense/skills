#!/usr/bin/env bash
# List all work items with their frontmatter essentials.
# Usage: work-list.sh [work-dir]   (default: ./work)
set -euo pipefail

dir="${1:-work}"
shopt -s nullglob
files=("$dir"/*.md)
if [ ${#files[@]} -eq 0 ]; then
  echo "no work items in $dir/"
  exit 0
fi

{
  printf 'ID\tTYPE\tSTATUS\tFILE\tTITLE\n'
  for f in "${files[@]}"; do
    awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$f" \
      | yj -yj \
      | jq -r --arg file "$(basename "$f")" '[.id, .type, .status, $file, .title] | map(tostring) | @tsv'
  done | sort -n
} | column -t -s "$(printf '\t')"
