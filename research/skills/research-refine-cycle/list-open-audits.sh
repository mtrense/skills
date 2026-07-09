#!/usr/bin/env bash
# List all open AUDIT directives in research content files, ordered by INDEX.md.
# One line per AUDIT directive:
#     <rel_path>:<lineno>:<type>:<severity>
#   - rel_path  is relative to <research>/content/
#   - lineno    is the 1-based line of the opening "<!-- AUDIT:" marker
#   - type      is the AUDIT type (contradiction | weak-source | gap | flow | ...)
#   - severity  is minor | major | ? (when absent)
#
# The list drives /research-refine-cycle: the orchestrator groups the lines by
# rel_path to build batches (one worker per file) and counts them to honour the
# <count> budget. Re-running after a refine pass yields fewer lines — that is
# what makes the cycle resumable and idempotent.
#
# Usage: ./list-open-audits.sh [path/to/research]
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
  # Strip the leading "content/" prefix so paths are relative to content_dir.
  path="${path#content/}"
  ordered_files+=("$path")
done < <(grep -oE '^#{2,} \[.*\]\(content/[^)]+\.md\)' "$index_file" | grep -oE 'content/[^)]+\.md')

if [[ ${#ordered_files[@]} -eq 0 ]]; then
  exit 0
fi

# For each file in INDEX.md order, emit one line per AUDIT directive.
# AUDIT directives are multi-line HTML comments of the form:
#   <!-- AUDIT:
#     type: <type>
#     severity: <minor|major>
#     ...
#   -->
# We capture the opening marker's line number, then read forward within the
# same comment for `type:` and `severity:` until the closing `-->`.
for rel_path in "${ordered_files[@]}"; do
  full_path="$content_dir/$rel_path"
  [[ -f "$full_path" ]] || continue
  awk -v rel="$rel_path" '
    /<!-- AUDIT:/ {
      inblk = 1; start = NR; type = ""; sev = "";
      # Support a one-line directive that also closes on this line.
      if ($0 ~ /-->/) {
        emit();
      }
      next;
    }
    inblk && type == "" && /type:/ {
      t = $0; sub(/.*type:[ \t]*/, "", t); sub(/[ \t].*$/, "", t); type = t;
    }
    inblk && sev == "" && /severity:/ {
      s = $0; sub(/.*severity:[ \t]*/, "", s); gsub(/[ \t]/, "", s); sev = s;
    }
    inblk && /-->/ { emit(); }
    function emit() {
      printf "%s:%d:%s:%s\n", rel, start, (type == "" ? "?" : type), (sev == "" ? "?" : sev);
      inblk = 0;
    }
  ' "$full_path"
done
