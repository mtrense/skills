#!/usr/bin/env bash
# assemble.sh — deterministic assembly for design-system kitchen-sink pages.
#
# Commands:
#   catalog  <ds-dir>               print catalog slugs in kitchen-sink order (from COMPONENTS.md "## Catalog")
#   missing  <ds-dir> <theme-dir>   print catalog slugs that have neither a fragment file nor an
#                                   existing marker block in <theme-dir>/index.html
#   assemble <ds-dir> <theme-dir>   rebuild <theme-dir>/index.html: page shell + one block per catalog
#                                   slug, taken from the fragment file if present, else carried over
#                                   from the existing index.html; slugs with neither are skipped (stderr note)
#   index    <ds-dir>               rebuild the root <ds-dir>/index.html linking every <theme>-<mode> dir
#
# Fragments live at <ds-dir>/.fragments/<slug>/<theme-dir>.html and contain the full marker-delimited
# block: <!-- component: <slug> --> ... <!-- /component: <slug> -->
set -euo pipefail

usage() { sed -n '2,15p' "$0" >&2; exit 2; }

cmd="${1:-}"; ds="${2:-}"
[ -n "$cmd" ] && [ -n "$ds" ] || usage
[ -d "$ds" ] || { echo "error: no such directory: $ds" >&2; exit 1; }

catalog() {
  [ -f "$ds/COMPONENTS.md" ] || { echo "error: $ds/COMPONENTS.md not found" >&2; exit 1; }
  sed -n 's/^- `\([a-z0-9][a-z0-9-]*\)`.*$/\1/p' "$ds/COMPONENTS.md"
}

has_block() { # $1=file $2=slug
  [ -f "$1" ] && grep -q "<!-- component: $2 -->" "$1"
}

extract_block() { # $1=file $2=slug
  awk -v open="<!-- component: $2 -->" -v close_="<!-- /component: $2 -->" '
    index($0, open) { f = 1 }
    f { print }
    index($0, close_) { f = 0 }
  ' "$1"
}

title_case() { # aurora-dark -> Aurora Dark
  echo "$1" | tr '-' ' ' | awk '{ for (i = 1; i <= NF; i++) $i = toupper(substr($i,1,1)) substr($i,2); print }'
}

case "$cmd" in
  catalog)
    catalog
    ;;

  missing)
    theme="${3:?usage: assemble.sh missing <ds-dir> <theme-dir>}"
    page="$ds/$theme/index.html"
    catalog | while IFS= read -r slug; do
      frag="$ds/.fragments/$slug/$theme.html"
      if [ ! -f "$frag" ] && ! has_block "$page" "$slug"; then
        echo "$slug"
      fi
    done
    ;;

  assemble)
    theme="${3:?usage: assemble.sh assemble <ds-dir> <theme-dir>}"
    dir="$ds/$theme"
    [ -d "$dir" ] || { echo "error: no such theme dir: $dir" >&2; exit 1; }
    page="$dir/index.html"
    prev="$dir/.index.html.prev"; rm -f "$prev"; [ -f "$page" ] && cp "$page" "$prev"
    out="$dir/.index.html.tmp"
    title="$(title_case "$theme")"

    {
      printf '<!doctype html>\n<html lang="en" dir="ltr">\n<head>\n'
      printf '<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1">\n'
      printf '<title>%s — Kitchen Sink</title>\n' "$title"
      printf '<script src="https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4"></script>\n'
      printf '<link rel="stylesheet" href="index.css">\n'
      printf '</head>\n<body>\n'
      printf '<header class="p-8 border-b border-(--ds-color-border)">\n'
      printf '  <h1 class="text-2xl font-bold">%s — Kitchen Sink</h1>\n' "$title"
      printf '  <p class="mt-1 text-sm"><a class="underline" href="../index.html">All themes</a></p>\n'
      printf '  <nav class="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-sm" aria-label="Components">\n'
      catalog | while IFS= read -r slug; do
        printf '    <a class="underline" href="#component-%s">%s</a>\n' "$slug" "$(title_case "$slug")"
      done
      printf '  </nav>\n</header>\n<main class="p-8 flex flex-col gap-16">\n'
      catalog | while IFS= read -r slug; do
        frag="$ds/.fragments/$slug/$theme.html"
        if [ -f "$frag" ]; then
          cat "$frag"
        elif has_block "$prev" "$slug"; then
          extract_block "$prev" "$slug"
        else
          echo "note: no fragment and no existing block for '$slug' in $theme — skipped" >&2
        fi
        printf '\n'
      done
      printf '</main>\n</body>\n</html>\n'
    } > "$out"

    mv "$out" "$page"
    rm -f "$prev"
    echo "assembled $page"
    ;;

  index)
    out="$ds/.index.html.tmp"
    {
      printf '<!doctype html>\n<html lang="en" dir="ltr">\n<head>\n'
      printf '<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1">\n'
      printf '<title>Design System — Themes</title>\n'
      printf '<style>body{font-family:system-ui,sans-serif;max-width:40rem;margin:3rem auto;padding:0 1rem;line-height:1.6}</style>\n'
      printf '</head>\n<body>\n<h1>Design System — Themes</h1>\n<ul>\n'
      find "$ds" -maxdepth 1 -type d \( -name '*-light' -o -name '*-dark' \) | sed "s|^$ds/||" | sort | while IFS= read -r d; do
        printf '  <li><a href="%s/index.html">%s</a></li>\n' "$d" "$(title_case "$d")"
      done
      printf '</ul>\n</body>\n</html>\n'
    } > "$out"
    mv "$out" "$ds/index.html"
    echo "assembled $ds/index.html"
    ;;

  *)
    usage
    ;;
esac
