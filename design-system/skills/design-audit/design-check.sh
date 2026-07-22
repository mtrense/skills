#!/usr/bin/env bash
# design-check.sh — deterministic quality gate for a generated design system.
#
# Usage: design-check.sh <design-system-dir> [<theme-dir-name> ...]
#   With no theme-dir names, every <theme>-light / <theme>-dark directory is checked.
#
# Per theme dir:
#   - index.css exists, defines --ds-* tokens, required color roles present
#   - WCAG contrast >= 4.5:1 for every --ds-color-on-<x> vs --ds-color-<x> pair (hex values)
#   - index.html: lang= and dir= on <html>, index.css linked, Tailwind CDN present
#   - marker integrity against the COMPONENTS.md catalog (MISS for absent, FAIL for unbalanced)
#   - per component block: RTL sample (dir="rtl"), long-string sample (data-ds-sample="long"),
#     aria/role presence, focus-visible, no physical direction classes
#     (lines carrying data-ds-physical are exempt from the direction check)
# Root:
#   - FOUNDATION.md / THEMES.md / COMPONENTS.md / references.md present
#   - root index.html links every theme dir
#
# Output: one "OK|WARN|FAIL|MISS <detail>" line per finding, then a summary.
# Exit status: 1 if any FAIL, else 0 (WARN and MISS do not fail the gate).
set -euo pipefail

DS="${1:?usage: design-check.sh <design-system-dir> [<theme-dir-name> ...]}"
shift || true
[ -d "$DS" ] || { echo "FAIL no such directory: $DS"; exit 1; }

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

# ---------- root files ----------
for f in FOUNDATION.md THEMES.md COMPONENTS.md references.md; do
  [ -f "$DS/$f" ] && ok "root: $f present" || warn "root: $f missing"
done

# ---------- catalog ----------
catalog=""
[ -f "$DS/COMPONENTS.md" ] && catalog="$(sed -n 's/^- `\([a-z0-9][a-z0-9-]*\)`.*$/\1/p' "$DS/COMPONENTS.md")"
[ -n "$catalog" ] || warn "catalog: no slugs found in COMPONENTS.md (## Catalog '- \`slug\` — …' lines)"

# ---------- theme dirs ----------
if [ "$#" -gt 0 ]; then
  themes="$(printf '%s\n' "$@")"
else
  themes="$(find "$DS" -maxdepth 1 -type d \( -name '*-light' -o -name '*-dark' \) | sed "s|^$DS/||" | sort)"
fi
[ -n "$themes" ] || fail "no theme directories found (expected <theme>-light / <theme>-dark)"

# ---------- root index ----------
if [ -f "$DS/index.html" ]; then
  while IFS= read -r t; do
    [ -z "$t" ] && continue
    grep -q "href=\"$t/index.html\"" "$DS/index.html" \
      && ok "root index: links $t" || warn "root index: does not link $t"
  done <<< "$themes"
else
  warn "root: index.html missing (run assemble.sh index)"
fi

# ---------- per theme ----------
while IFS= read -r theme; do
  [ -z "$theme" ] && continue
  dir="$DS/$theme"
  css="$dir/index.css"
  page="$dir/index.html"
  p="theme $theme:"

  [ -f "$dir/tokens.md" ] && ok "$p tokens.md present" || warn "$p tokens.md missing"

  # ----- tokens -----
  if [ ! -f "$css" ]; then
    fail "$p index.css missing"
  else
    tokens="$(sed -n 's/^[[:space:]]*\(--ds-[a-z0-9-]*\)[[:space:]]*:[[:space:]]*\([^;]*\);.*$/\1 \2/p' "$css")"
    if [ -z "$tokens" ]; then
      fail "$p index.css defines no --ds-* tokens"
    else
      for role in bg on-bg surface on-surface primary on-primary border; do
        echo "$tokens" | grep -q "^--ds-color-$role " \
          && ok "$p token --ds-color-$role present" || fail "$p required token --ds-color-$role missing"
      done
      echo "$tokens" | grep -q "^--ds-font-sans " || warn "$p token --ds-font-sans missing"
      # contrast for every on-<x> / <x> pair
      while IFS= read -r base; do
        [ -z "$base" ] && continue
        onv="$(echo "$tokens" | sed -n "s/^--ds-color-on-$base //p" | head -1)"
        basev="$(echo "$tokens" | sed -n "s/^--ds-color-$base //p" | head -1)"
        if [ -z "$basev" ]; then
          warn "$p --ds-color-on-$base has no matching --ds-color-$base"
        elif ratio="$(contrast "$onv" "$basev" 2>/dev/null)"; then
          if [ "$(awk -v r="$ratio" 'BEGIN { print (r >= 4.5) ? 1 : 0 }')" = "1" ]; then
            ok "$p contrast on-$base/$base = $ratio"
          else
            fail "$p contrast on-$base/$base = $ratio (< 4.5)"
          fi
        else
          warn "$p contrast on-$base/$base not checkable (non-hex values: '$onv' / '$basev')"
        fi
      done < <(echo "$tokens" | sed -n 's/^--ds-color-on-\([a-z0-9-]*\) .*$/\1/p')
    fi
  fi

  # ----- page -----
  if [ ! -f "$page" ]; then
    miss "$p index.html not yet assembled"
    continue
  fi
  grep -q '<html[^>]* lang=' "$page" && ok "$p <html> has lang" || fail "$p <html> missing lang attribute"
  grep -q '<html[^>]* dir=' "$page" && ok "$p <html> has dir" || fail "$p <html> missing dir attribute"
  grep -q 'stylesheet[^>]*index.css\|index.css[^>]*stylesheet' "$page" && ok "$p index.css linked" || fail "$p index.css not linked"
  grep -q '@tailwindcss/browser' "$page" && ok "$p Tailwind CDN present" || warn "$p Tailwind browser CDN script not found"

  # ----- markers & per-component blocks -----
  while IFS= read -r slug; do
    [ -z "$slug" ] && continue
    opens="$(grep -c "<!-- component: $slug -->" "$page" || true)"
    closes="$(grep -c "<!-- /component: $slug -->" "$page" || true)"
    if [ "$opens" = "0" ] && [ "$closes" = "0" ]; then
      miss "$p component '$slug' not in kitchen-sink"
      continue
    fi
    if [ "$opens" != "1" ] || [ "$closes" != "1" ]; then
      fail "$p component '$slug' markers unbalanced (open=$opens close=$closes)"
      continue
    fi
    block="$(awk -v open="<!-- component: $slug -->" -v close_="<!-- /component: $slug -->" '
      index($0, open) { f = 1 } f { print } index($0, close_) { f = 0 }
    ' "$page")"

    grep -q "id=\"component-$slug\"" <<< "$block" && ok "$p $slug: anchor id present" || fail "$p $slug: missing id=\"component-$slug\""
    grep -q 'dir="rtl"' <<< "$block" && ok "$p $slug: RTL sample" || warn "$p $slug: no RTL sample (dir=\"rtl\")"
    grep -q 'data-ds-sample="long"' <<< "$block" && ok "$p $slug: long-string sample" || warn "$p $slug: no long-string sample (data-ds-sample=\"long\")"
    grep -qE 'aria-|role=' <<< "$block" && ok "$p $slug: aria/role present" || warn "$p $slug: no aria-* or role= attributes"
    grep -q 'focus-visible' <<< "$block" && ok "$p $slug: focus-visible styling" || warn "$p $slug: no focus-visible styling"

    phys="$(grep -nE '[" ](ml|mr|pl|pr)-[0-9]|text-left[" ]|text-right[" ]|rounded-[lr]-|rounded-t[lr]-|rounded-b[lr]-|[" ]border-[lr][" -]' <<< "$block" | grep -v 'data-ds-physical' || true)"
    if [ -n "$phys" ]; then
      fail "$p $slug: physical direction classes (use ms-/me-/ps-/pe-/text-start/rounded-s-…, or mark the line data-ds-physical): $(echo "$phys" | head -3 | tr '\n' ' ')"
    else
      ok "$p $slug: logical direction classes only"
    fi
  done <<< "$catalog"

  # stray markers for slugs not in the catalog
  while IFS= read -r s; do
    [ -z "$s" ] && continue
    echo "$catalog" | grep -qx "$s" || warn "$p stray component block '$s' not in COMPONENTS.md catalog"
  done < <(grep -o '<!-- component: [a-z0-9-]* -->' "$page" | sed 's/<!-- component: \(.*\) -->/\1/')
done <<< "$themes"

echo "----"
echo "summary: $fails FAIL, $warns WARN, $misses MISS"
[ "$fails" -eq 0 ]
