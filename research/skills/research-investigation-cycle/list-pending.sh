#!/usr/bin/env bash
# List all pending RESEARCH directives across research content files, paired
# with the nearest preceding markdown heading (the directive's section).
#
# Output: TSV with three columns — <file_path>\t<directive_line>\t<heading>
#   where <heading> is the verbatim heading line (e.g. "## Section title").
#
# Usage: ./list-pending.sh [path/to/research]
#   Defaults to ./research if no argument given.

set -euo pipefail

research_dir="${1:-research}"
content_dir="$research_dir/content"

if [[ ! -d "$content_dir" ]]; then
  echo "Error: content directory not found at $content_dir" >&2
  exit 1
fi

# For each file containing a RESEARCH directive, walk it once and emit a row
# per directive paired with the most recent heading seen so far.
while IFS= read -r file; do
  awk -v F="$file" '
    /^#+ / { heading = $0; next }
    /<!-- RESEARCH:/ {
      if (heading == "") { heading = "(no preceding heading)" }
      printf "%s\t%d\t%s\n", F, NR, heading
    }
  ' "$file"
done < <(grep -rl '<!-- RESEARCH:' "$content_dir" | sort)
