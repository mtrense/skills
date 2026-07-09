#!/usr/bin/env bash
# List all AUDIT comments in research content files, ordered by INDEX.md.
# Output: <directory>/<filename>.md:<linenumber>
#
# Usage: ./list-audits.sh [path/to/research]
#   Defaults to ./research if no argument given.

set -euo pipefail

research_dir="${1:-research}"
index_file="$research_dir/INDEX.md"
content_dir="$research_dir/content"

if [[ ! -f "$index_file" ]]; then
  echo "Error: INDEX.md not found at $index_file" >&2
  exit 1
fi

# Extract ordered list of content file paths from INDEX.md headings.
# Leaf chapters are markdown-link headings at any depth, e.g.
#   "### [dir/file.md](content/dir/file.md)" or "#### [a/b/c.md](content/a/b/c.md)".
# Directory group headings carry no link, so they are naturally skipped.
ordered_files=()
while IFS= read -r path; do
  # Strip the leading "content/" prefix so paths are relative to content_dir
  path="${path#content/}"
  ordered_files+=("$path")
done < <(grep -oE '^#{2,} \[.*\]\(content/[^)]+\.md\)' "$index_file" | grep -oE 'content/[^)]+\.md')

# For each file in INDEX.md order, find AUDIT comment start lines.
if [[ ${#ordered_files[@]} -eq 0 ]]; then
  exit 0
fi
for rel_path in "${ordered_files[@]}"; do
  full_path="$content_dir/$rel_path"
  [[ -f "$full_path" ]] || continue
  { grep -n '<!-- AUDIT:' "$full_path" || true; } | while IFS=: read -r lineno _rest; do
    echo "$rel_path:$lineno"
  done
done
