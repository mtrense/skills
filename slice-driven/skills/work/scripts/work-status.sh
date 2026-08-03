#!/usr/bin/env bash
# Flip the status of a work item.
# Usage: work-status.sh <id> <captured|shaped|in-progress|blocked|done|dropped> [work-dir]
set -euo pipefail

id="$1"
new="$2"
dir="${3:-work}"

case "$new" in
  captured | shaped | in-progress | blocked | done | dropped) ;;
  *) echo "invalid status: $new (want captured|shaped|in-progress|blocked|done|dropped)" >&2; exit 1 ;;
esac

shopt -s nullglob
target=""
for f in "$dir"/*.md; do
  cur="$(awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$f" | yj -yj | jq -r '.id')"
  if [ "$cur" = "$id" ]; then
    target="$f"
    break
  fi
done

if [ -z "$target" ]; then
  echo "no work item with id $id in $dir/" >&2
  exit 1
fi

# Replace the first `status:` line (always inside the frontmatter).
sed -i.bak "1,/^status:/s/^status:.*/status: $new/" "$target" && rm -f "$target.bak"
echo "$target -> $new"
