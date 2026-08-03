#!/usr/bin/env bash
# Project board: all work items with their frontmatter essentials, then open decisions —
# provisional (not-yet-grounded) records in the decision log, and decisions that
# in-flight probes have promised but not yet recorded.
# Usage: board.sh [work-dir] [decisions-dir]   (defaults: ./work ./decisions)
set -euo pipefail

dir="${1:-work}"
decisions_dir="${2:-decisions}"
shopt -s nullglob

frontmatter() {
  awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$1" | yj -yj
}

files=("$dir"/*.md)
if [ ${#files[@]} -eq 0 ]; then
  echo "no work items in $dir/"
else
  {
    printf 'ID\tTYPE\tSTATUS\tFILE\tTITLE\n'
    for f in "${files[@]}"; do
      frontmatter "$f" \
        | jq -r --arg file "$(basename "$f")" '[.id, .type, .status, $file, .title] | map(tostring) | @tsv'
    done | sort -n
  } | column -t -s "$(printf '\t')"
fi

open_decisions=""

# Accepted-but-provisional decision records: standing assumptions, fair game for grounding.
dfiles=("$decisions_dir"/*.md)
for f in "${dfiles[@]}"; do
  line="$(frontmatter "$f" \
    | jq -r --arg file "$(basename "$f")" \
        'select(.status == "accepted" and .grounding == "provisional") | "  \($file) — provisional — \(.title)"')"
  if [ -n "$line" ]; then open_decisions+="$line"$'\n'; fi
done

# In-flight probes: the decision each one exists to unblock is still unrecorded.
for f in "${files[@]}"; do
  line="$(frontmatter "$f" \
    | jq -r 'select(.type == "probe" and (.status | IN("done", "dropped") | not) and .decision != null)
             | "  undecided: \(.decision) — awaiting probe \(.id) (\(.status))"')"
  if [ -n "$line" ]; then open_decisions+="$line"$'\n'; fi
done

if [ -n "$open_decisions" ]; then
  printf '\nOPEN DECISIONS\n%s' "$open_decisions"
fi
