#!/usr/bin/env bash
# Print the next actionable work item: the in-progress item if one exists,
# otherwise the lowest-id shaped item whose blockers are all done.
# Usage: work-next.sh [work-dir]   (default: ./work)
set -euo pipefail

dir="${1:-work}"
shopt -s nullglob
files=("$dir"/*.md)
if [ ${#files[@]} -eq 0 ]; then
  echo "no work items in $dir/" >&2
  exit 1
fi

for f in "${files[@]}"; do
  awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$f" \
    | yj -yj \
    | jq --arg file "$f" '. + {file: $file}'
done | jq -rs '
  map(.blocked_by = (.blocked_by // [])) |
  ([.[] | select(.status == "done") | .id]) as $done |
  ([.[] | select(.status == "in-progress")] | sort_by(.id) | first) as $active |
  (if $active != null then $active
   else ([.[] | select(.status == "shaped") | select((.blocked_by - $done) == [])] | sort_by(.id) | first)
   end) as $next |
  if $next != null then "\($next.id)\t\($next.type)\t\($next.file)\t\($next.title)"
  else "nothing actionable"
  end'
