#!/usr/bin/env bash
# deck-check.sh — deterministic quality gate for the design-system deck layer.
#
# Usage:
#   deck-check.sh kit  <ds-dir> [<theme-dir-name> ...]   check the deck kit (default: every theme dir)
#   deck-check.sh deck <deck-dir>                        check one assembled deck
#
# kit, per theme dir:
#   - deck-kit/<theme>/deck.css exists, imports the theme's index.css
#   - required --r-* mappings present, colors routed through var(--ds-*)
#   - contrast re-verified through the var chain (hex from the theme's index.css):
#     main-color/link-color vs background-color >= 4.5, heading-color >= 3.0
#   - sample deck assembled; page shell (lang/dir, reveal css+js+initialize, base theme,
#     Tailwind CDN, deck.css) present; marker integrity against DECKKIT.md "## Masters";
#     per block: <section>, anchor id, no unmarked physical direction classes
# deck:
#   - OUTLINE.md present with frontmatter theme/ds and a parseable "## Slides" list
#   - every referenced master exists in the kit; theme dir + deck.css resolvable
#   - index.html shell + marker integrity against the slide list; per block: <section>,
#     anchor id, no unmarked physical direction classes; WARN if no speaker notes at all
#
# Output: one "OK|WARN|FAIL|MISS <detail>" line per finding, then a summary.
# Exit status: 1 if any FAIL, else 0 (WARN and MISS do not fail the gate).
set -euo pipefail

mode="${1:-}"; root="${2:-}"
[ -n "$mode" ] && [ -n "$root" ] || { sed -n '2,25p' "$0" >&2; exit 2; }
shift 2 || true
[ -d "$root" ] || { echo "FAIL no such directory: $root"; exit 1; }

fails=0; warns=0; misses=0
ok()   { echo "OK   $1"; }
warn() { echo "WARN $1"; warns=$((warns + 1)); }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
miss() { echo "MISS $1"; misses=$((misses + 1)); }

hex_rgb() { # "#abc" or "#aabbcc" -> "r g b" (decimal); empty output if not plain hex
  local h="${1#\#}"
  case "$h" in
    [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) h="${h:0:1}${h:0:1}${h:1:1}${h:1:1}${h:2:1}${h:2:1}" ;;
    [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) ;;
    *) return 1 ;;
  esac
  printf '%d %d %d' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
}

contrast() { # $1=hex-fg $2=hex-bg -> ratio like "4.62"
  local a b
  a="$(hex_rgb "$1")" || return 1
  b="$(hex_rgb "$2")" || return 1
  awk -v ar="$a" -v br="$b" '
    function lin(c) { c /= 255; return (c <= 0.04045) ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4 }
    BEGIN {
      split(ar, x, " "); split(br, y, " ")
      l1 = 0.2126 * lin(x[1]) + 0.7152 * lin(x[2]) + 0.0722 * lin(x[3])
      l2 = 0.2126 * lin(y[1]) + 0.7152 * lin(y[2]) + 0.0722 * lin(y[3])
      if (l1 < l2) { t = l1; l1 = l2; l2 = t }
      printf "%.2f", (l1 + 0.05) / (l2 + 0.05)
    }'
}

masters_list() { # $1=ds-dir
  awk '/^## Masters$/ { s = 1; next } s && /^## / { exit } s' "$1/deck-kit/DECKKIT.md" 2>/dev/null \
    | sed -n 's/^- `\([a-z0-9][a-z0-9-]*\)`.*$/\1/p'
}

fm_get() { # $1=file $2=key $3=default
  local v
  v="$(awk 'NR == 1 && $0 == "---" { f = 1; next } f && $0 == "---" { exit } f' "$1" \
    | sed -n "s/^$2:[[:space:]]*//p" | head -1)"
  echo "${v:-${3:-}}"
}

extract_block() { # $1=file $2=kind $3=slug
  awk -v open="<!-- $2: $3 -->" -v close_="<!-- /$2: $3 -->" '
    index($0, open) { f = 1 } f { print } index($0, close_) { f = 0 }
  ' "$1"
}

check_shell() { # $1=page $2=prefix $3=deck.css href hint (grep pattern)
  local page="$1" p="$2"
  grep -q '<html[^>]* lang=' "$page" && ok "$p <html> has lang" || fail "$p <html> missing lang attribute"
  grep -q '<html[^>]* dir=' "$page" && ok "$p <html> has dir" || fail "$p <html> missing dir attribute"
  grep -q 'reveal.js@5/dist/reveal.css' "$page" && ok "$p reveal.css linked" || fail "$p reveal.css not linked"
  grep -q 'dist/theme/' "$page" && ok "$p reveal base theme linked" || fail "$p reveal base theme css not linked"
  grep -q '@tailwindcss/browser' "$page" && ok "$p Tailwind CDN present" || warn "$p Tailwind browser CDN script not found"
  grep -q "$3" "$page" && ok "$p deck.css linked" || fail "$p deck.css not linked"
  grep -q 'reveal.js@5/dist/reveal.js' "$page" && ok "$p reveal.js script present" || fail "$p reveal.js script missing"
  grep -q 'Reveal.initialize' "$page" && ok "$p Reveal.initialize present" || fail "$p Reveal.initialize missing"
}

check_block() { # $1=page $2=kind $3=slug $4=prefix -> checks one marker block
  local page="$1" kind="$2" slug="$3" p="$4" opens closes block phys
  opens="$(grep -c "<!-- $kind: $slug -->" "$page" || true)"
  closes="$(grep -c "<!-- /$kind: $slug -->" "$page" || true)"
  if [ "$opens" = "0" ] && [ "$closes" = "0" ]; then
    miss "$p $kind '$slug' not in page"
    return
  fi
  if [ "$opens" != "1" ] || [ "$closes" != "1" ]; then
    fail "$p $kind '$slug' markers unbalanced (open=$opens close=$closes)"
    return
  fi
  block="$(extract_block "$page" "$kind" "$slug")"
  grep -q '<section' <<< "$block" && ok "$p $slug: is a <section>" || fail "$p $slug: block has no <section>"
  grep -q "id=\"$kind-$slug\"" <<< "$block" && ok "$p $slug: anchor id present" || fail "$p $slug: missing id=\"$kind-$slug\""
  phys="$(grep -nE '[" ](ml|mr|pl|pr)-[0-9]|text-left[" ]|text-right[" ]|rounded-[lr]-|rounded-t[lr]-|rounded-b[lr]-|[" ]border-[lr][" -]' <<< "$block" | grep -v 'data-ds-physical' || true)"
  if [ -n "$phys" ]; then
    fail "$p $slug: physical direction classes (use ms-/me-/ps-/pe-/text-start/rounded-s-…, or mark the line data-ds-physical): $(echo "$phys" | head -3 | tr '\n' ' ')"
  else
    ok "$p $slug: logical direction classes only"
  fi
}

check_bridge() { # $1=ds-dir $2=theme-dir -> checks deck.css mappings + contrast via var chain
  local ds="$1" theme="$2" css="$1/deck-kit/$2/deck.css" p="kit $2:"
  local maps tokens bghex fghex dsvar val ratio
  grep -q "@import.*$theme/index.css" "$css" \
    && ok "$p deck.css imports the theme's index.css" || fail "$p deck.css does not @import ../../$theme/index.css"
  maps="$(sed -n 's/^[[:space:]]*--r-\([a-z-]*\)[[:space:]]*:[[:space:]]*\([^;]*\);.*$/\1|\2/p' "$css")"
  tokens="$(sed -n 's/^[[:space:]]*\(--ds-[a-z0-9-]*\)[[:space:]]*:[[:space:]]*\([^;]*\);.*$/\1 \2/p' "$ds/$theme/index.css" 2>/dev/null)"

  resolve() { # $1=--r-name -> hex via the theme's --ds token, or empty
    local raw ref
    raw="$(echo "$maps" | sed -n "s/^$1|//p" | head -1)"
    [ -n "$raw" ] || return 1
    ref="$(grep -o -- '--ds-[a-z0-9-]*' <<< "$raw" | head -1)" || true
    [ -n "$ref" ] || { echo "LITERAL:$raw"; return 0; }
    echo "$tokens" | sed -n "s/^$ref //p" | head -1
  }

  for name in background-color main-color heading-color link-color; do
    if echo "$maps" | grep -q "^$name|"; then
      if echo "$maps" | sed -n "s/^$name|//p" | head -1 | grep -q -- 'var(--ds-'; then
        ok "$p --r-$name mapped through a --ds- token"
      else
        fail "$p --r-$name is not routed through a --ds- token"
      fi
    else
      fail "$p required mapping --r-$name missing from deck.css"
    fi
  done
  for name in main-font heading-font; do
    echo "$maps" | grep -q "^$name|" && ok "$p --r-$name present" || fail "$p required mapping --r-$name missing from deck.css"
  done
  echo "$maps" | grep -q "^code-font|" || warn "$p --r-code-font not mapped"

  bghex="$(resolve background-color || true)"
  for pair in "main-color 4.5" "link-color 4.5" "heading-color 3.0"; do
    set -- $pair
    fghex="$(resolve "$1" || true)"
    case "$bghex$fghex" in *LITERAL*) fghex="" ;; esac
    if [ -n "$bghex" ] && [ -n "$fghex" ] && ratio="$(contrast "$fghex" "$bghex" 2>/dev/null)"; then
      if [ "$(awk -v r="$ratio" -v m="$2" 'BEGIN { print (r >= m) ? 1 : 0 }')" = "1" ]; then
        ok "$p contrast $1/background = $ratio"
      else
        fail "$p contrast $1/background = $ratio (< $2)"
      fi
    else
      warn "$p contrast $1/background not checkable (unresolvable or non-hex values)"
    fi
  done
}

case "$mode" in
  kit)
    DS="$root"
    [ -f "$DS/deck-kit/DECKKIT.md" ] || { fail "deck-kit/DECKKIT.md missing (run /deck-kit)"; echo "----"; echo "summary: $fails FAIL, $warns WARN, $misses MISS"; exit 1; }
    masters="$(masters_list "$DS")"
    [ -n "$masters" ] && ok "DECKKIT.md: masters list parsed" || fail "DECKKIT.md: no masters found (## Masters '- \`slug\` — …' lines)"

    if [ "$#" -gt 0 ]; then
      themes="$(printf '%s\n' "$@")"
    else
      themes="$(find "$DS" -maxdepth 1 -type d \( -name '*-light' -o -name '*-dark' \) | sed "s|^$DS/||" | sort)"
    fi
    [ -n "$themes" ] || fail "no theme directories found (expected <theme>-light / <theme>-dark)"

    while IFS= read -r theme; do
      [ -z "$theme" ] && continue
      p="kit $theme:"
      if [ ! -f "$DS/deck-kit/$theme/deck.css" ]; then
        miss "$p deck.css not yet written"
        continue
      fi
      check_bridge "$DS" "$theme"
      page="$DS/deck-kit/sample/$theme.html"
      if [ ! -f "$page" ]; then
        miss "$p sample deck not yet assembled"
        continue
      fi
      check_shell "$page" "$p" "$theme/deck.css"
      while IFS= read -r slug; do
        [ -z "$slug" ] && continue
        check_block "$page" master "$slug" "$p"
      done <<< "$masters"
      while IFS= read -r s; do
        [ -z "$s" ] && continue
        echo "$masters" | grep -qx "$s" || warn "$p stray master block '$s' not in DECKKIT.md"
      done < <(grep -o '<!-- master: [a-z0-9-]* -->' "$page" | sed 's/<!-- master: \(.*\) -->/\1/')
    done <<< "$themes"
    ;;

  deck)
    DECK="$root"
    outline="$DECK/OUTLINE.md"
    [ -f "$outline" ] || { fail "OUTLINE.md missing in $DECK"; echo "----"; echo "summary: $fails FAIL, $warns WARN, $misses MISS"; exit 1; }
    theme="$(fm_get "$outline" theme "")"
    ds="$(fm_get "$outline" ds "../../design-system")"
    [ -n "$theme" ] && ok "deck: frontmatter theme = $theme" || fail "deck: OUTLINE.md frontmatter has no 'theme:'"
    slist="$(awk '/^## Slides$/ { s = 1; next } s && /^## / { exit } s' "$outline" \
      | sed -n 's/^- `\([a-z0-9][a-z0-9-]*\)` \[\([a-z0-9-]*\)\].*$/\1 \2/p')"
    [ -n "$slist" ] && ok "deck: slide list parsed ($(echo "$slist" | wc -l | tr -d ' ') slides)" \
      || fail "deck: no slides found (## Slides '- \`NN-slug\` [master] — …' lines)"

    dsdir="$DECK/$ds"
    if [ -d "$dsdir" ] && [ -n "$theme" ]; then
      [ -f "$dsdir/deck-kit/$theme/deck.css" ] && ok "deck: kit bridge resolvable" \
        || fail "deck: $ds/deck-kit/$theme/deck.css not found from deck dir"
      masters="$(masters_list "$dsdir")"
      while IFS=' ' read -r slug master; do
        [ -z "$slug" ] && continue
        echo "$masters" | grep -qx "$master" || fail "deck: slide '$slug' references unknown master '$master'"
      done <<< "$slist"
    else
      fail "deck: design-system dir not resolvable at $ds (frontmatter 'ds:')"
    fi

    page="$DECK/index.html"
    if [ ! -f "$page" ]; then
      miss "deck: index.html not yet assembled"
    else
      check_shell "$page" "deck:" "deck-kit/$theme/deck.css"
      while IFS=' ' read -r slug master; do
        [ -z "$slug" ] && continue
        check_block "$page" slide "$slug" "deck:"
      done <<< "$slist"
      while IFS= read -r s; do
        [ -z "$s" ] && continue
        echo "$slist" | awk '{print $1}' | grep -qx "$s" || warn "deck: stray slide block '$s' not in OUTLINE.md"
      done < <(grep -o '<!-- slide: [a-z0-9-]* -->' "$page" | sed 's/<!-- slide: \(.*\) -->/\1/')
      grep -q '<aside class="notes"' "$page" && ok "deck: speaker notes present" || warn "deck: no speaker notes in the whole deck"
    fi
    ;;

  *)
    sed -n '2,25p' "$0" >&2; exit 2
    ;;
esac

echo "----"
echo "summary: $fails FAIL, $warns WARN, $misses MISS"
[ "$fails" -eq 0 ]
