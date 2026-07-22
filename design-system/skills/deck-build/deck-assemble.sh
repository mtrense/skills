#!/usr/bin/env bash
# deck-assemble.sh — deterministic assembly for the design-system deck layer.
#
# Kit commands (masters live as marker blocks in the sample decks):
#   masters          <ds-dir>                       print master slugs in sample order (from deck-kit/DECKKIT.md "## Masters")
#   missing-masters  <ds-dir> <theme-dir>           masters with neither a fragment nor a marker block in the sample deck
#   assemble-sample  <ds-dir> <theme-dir>           rebuild deck-kit/sample/<theme-dir>.html from fragments/existing blocks
#   master-block     <ds-dir> <theme-dir> <master>  print master's marker-delimited block from the sample deck
#
# Deck commands (deck dir holds OUTLINE.md; frontmatter keys: title, theme, ds, lang, dir):
#   slides           <deck-dir>                     print "<slug> <master>" lines from OUTLINE.md "## Slides"
#   missing-slides   <deck-dir>                     slides with neither a fragment nor a marker block in index.html
#   assemble         <deck-dir>                     rebuild <deck-dir>/index.html from fragments/existing blocks
#
# Kit fragments:  <ds-dir>/deck-kit/.fragments/<master>/<theme-dir>.html
# Deck fragments: <deck-dir>/.fragments/<slug>.html
# Markers: <!-- master: <slug> --> ... <!-- /master: <slug> -->   (sample decks)
#          <!-- slide: <slug> -->  ... <!-- /slide: <slug> -->    (decks)
set -euo pipefail

usage() { sed -n '2,18p' "$0" >&2; exit 2; }

REVEAL_CDN="https://cdn.jsdelivr.net/npm/reveal.js@5"
TAILWIND_CDN="https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4"

cmd="${1:-}"; root="${2:-}"
[ -n "$cmd" ] && [ -n "$root" ] || usage
[ -d "$root" ] || { echo "error: no such directory: $root" >&2; exit 1; }

masters() { # $1=ds-dir
  local f="$1/deck-kit/DECKKIT.md"
  [ -f "$f" ] || { echo "error: $f not found" >&2; exit 1; }
  awk '/^## Masters$/ { s = 1; next } s && /^## / { exit } s' "$f" \
    | sed -n 's/^- `\([a-z0-9][a-z0-9-]*\)`.*$/\1/p'
}

slides() { # $1=deck-dir -> "slug master" lines
  local f="$1/OUTLINE.md"
  [ -f "$f" ] || { echo "error: $f not found" >&2; exit 1; }
  awk '/^## Slides$/ { s = 1; next } s && /^## / { exit } s' "$f" \
    | sed -n 's/^- `\([a-z0-9][a-z0-9-]*\)` \[\([a-z0-9-]*\)\].*$/\1 \2/p'
}

fm_get() { # $1=file $2=key $3=default
  local v
  v="$(awk 'NR == 1 && $0 == "---" { f = 1; next } f && $0 == "---" { exit } f' "$1" \
    | sed -n "s/^$2:[[:space:]]*//p" | head -1)"
  echo "${v:-${3:-}}"
}

has_block() { # $1=file $2=kind $3=slug
  [ -f "$1" ] && grep -q "<!-- $2: $3 -->" "$1"
}

extract_block() { # $1=file $2=kind $3=slug
  awk -v open="<!-- $2: $3 -->" -v close_="<!-- /$2: $3 -->" '
    index($0, open) { f = 1 }
    f { print }
    index($0, close_) { f = 0 }
  ' "$1"
}

title_case() { # aurora-dark -> Aurora Dark
  echo "$1" | tr '-' ' ' | awk '{ for (i = 1; i <= NF; i++) $i = toupper(substr($i,1,1)) substr($i,2); print }'
}

page_head() { # $1=lang $2=dir $3=title $4=deck.css href
  printf '<!doctype html>\n<html lang="%s" dir="%s">\n<head>\n' "$1" "$2"
  printf '<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1">\n'
  printf '<title>%s</title>\n' "$3"
  printf '<link rel="stylesheet" href="%s/dist/reveal.css">\n' "$REVEAL_CDN"
  printf '<link rel="stylesheet" href="%s/dist/theme/white.css">\n' "$REVEAL_CDN"
  printf '<script src="%s"></script>\n' "$TAILWIND_CDN"
  printf '<link rel="stylesheet" href="%s">\n' "$4"
  printf '</head>\n<body>\n<div class="reveal">\n<div class="slides">\n'
}

page_foot() {
  printf '</div>\n</div>\n'
  printf '<script src="%s/dist/reveal.js"></script>\n' "$REVEAL_CDN"
  printf '<script>Reveal.initialize({ hash: true });</script>\n'
  printf '</body>\n</html>\n'
}

case "$cmd" in
  masters)
    masters "$root"
    ;;

  missing-masters)
    theme="${3:?usage: deck-assemble.sh missing-masters <ds-dir> <theme-dir>}"
    page="$root/deck-kit/sample/$theme.html"
    masters "$root" | while IFS= read -r slug; do
      frag="$root/deck-kit/.fragments/$slug/$theme.html"
      if [ ! -f "$frag" ] && ! has_block "$page" master "$slug"; then
        echo "$slug"
      fi
    done
    ;;

  assemble-sample)
    theme="${3:?usage: deck-assemble.sh assemble-sample <ds-dir> <theme-dir>}"
    [ -d "$root/$theme" ] || { echo "error: no such theme dir: $root/$theme" >&2; exit 1; }
    mkdir -p "$root/deck-kit/sample"
    page="$root/deck-kit/sample/$theme.html"
    prev="$root/deck-kit/sample/.$theme.html.prev"; rm -f "$prev"; [ -f "$page" ] && cp "$page" "$prev"
    out="$root/deck-kit/sample/.$theme.html.tmp"
    {
      page_head "en" "ltr" "$(title_case "$theme") — Deck Masters" "../$theme/deck.css"
      masters "$root" | while IFS= read -r slug; do
        frag="$root/deck-kit/.fragments/$slug/$theme.html"
        if [ -f "$frag" ]; then
          cat "$frag"
        elif has_block "$prev" master "$slug"; then
          extract_block "$prev" master "$slug"
        else
          echo "note: no fragment and no existing block for master '$slug' in $theme — skipped" >&2
        fi
        printf '\n'
      done
      page_foot
    } > "$out"
    mv "$out" "$page"
    rm -f "$prev"
    echo "assembled $page"
    ;;

  master-block)
    theme="${3:?usage: deck-assemble.sh master-block <ds-dir> <theme-dir> <master>}"
    slug="${4:?usage: deck-assemble.sh master-block <ds-dir> <theme-dir> <master>}"
    page="$root/deck-kit/sample/$theme.html"
    has_block "$page" master "$slug" || { echo "error: no block for master '$slug' in $page" >&2; exit 1; }
    extract_block "$page" master "$slug"
    ;;

  slides)
    slides "$root"
    ;;

  missing-slides)
    page="$root/index.html"
    slides "$root" | while IFS=' ' read -r slug master; do
      frag="$root/.fragments/$slug.html"
      if [ ! -f "$frag" ] && ! has_block "$page" slide "$slug"; then
        echo "$slug $master"
      fi
    done
    ;;

  assemble)
    outline="$root/OUTLINE.md"
    [ -f "$outline" ] || { echo "error: $outline not found" >&2; exit 1; }
    dtitle="$(fm_get "$outline" title "Untitled Deck")"
    theme="$(fm_get "$outline" theme "")"
    ds="$(fm_get "$outline" ds "../../design-system")"
    lang="$(fm_get "$outline" lang "en")"
    dir_="$(fm_get "$outline" dir "ltr")"
    [ -n "$theme" ] || { echo "error: OUTLINE.md frontmatter has no 'theme:'" >&2; exit 1; }
    [ -f "$root/$ds/deck-kit/$theme/deck.css" ] \
      || echo "warning: $root/$ds/deck-kit/$theme/deck.css not found — the assembled deck will be unstyled" >&2

    page="$root/index.html"
    prev="$root/.index.html.prev"; rm -f "$prev"; [ -f "$page" ] && cp "$page" "$prev"
    out="$root/.index.html.tmp"
    {
      page_head "$lang" "$dir_" "$dtitle" "$ds/deck-kit/$theme/deck.css"
      slides "$root" | while IFS=' ' read -r slug master; do
        frag="$root/.fragments/$slug.html"
        if [ -f "$frag" ]; then
          cat "$frag"
        elif has_block "$prev" slide "$slug"; then
          extract_block "$prev" slide "$slug"
        else
          echo "note: no fragment and no existing block for slide '$slug' — skipped" >&2
        fi
        printf '\n'
      done
      page_foot
    } > "$out"
    mv "$out" "$page"
    rm -f "$prev"
    echo "assembled $page"
    ;;

  *)
    usage
    ;;
esac
