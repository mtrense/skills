#!/usr/bin/env bash
# Derive the true status of every chapter in a research project from the signals
# that actually live on disk — frontmatter plus the RESEARCH / CONFIDENCE / AUDIT
# directives and reference-verification flags — rather than from a hand-maintained
# enum. One line per chapter, ordered by INDEX.md, with detail counts of what is
# still missing before the chapter is `done`.
#
# This is the single source of truth for chapter status across the research
# workflow: every skill that used to read a `**Status**:` line out of INDEX.md
# now reads it here instead.
#
# ── Derivation ────────────────────────────────────────────────────────────────
# Signals (per chapter file + its sibling <name>_references.yaml):
#   research    open <!-- RESEARCH: --> directives          (inquiry work pending)
#   conf        open <!-- CONFIDENCE: low|medium --> markers (verification pending)
#   audit       open <!-- AUDIT: --> directives, by severity (refine work pending)
#   lenses      audit types recorded in the frontmatter `audit:` field; the four
#               core lenses are consistency, coverage, quality, coherence
#               (graphics is supplementary and does NOT gate `audited`)
#   refs        verified / total entries in <name>_references.yaml
#   sections    count of `##`+ headings (distinguishes a bare stub from a draft)
#
# Status is then:
#   stub      no sections and no RESEARCH directives (freshly created)
#   inquiry   >=1 RESEARCH directive still open (outline placed, not investigated)
#   draft     no RESEARCH left, has sections, fewer than 4 core lenses recorded
#   audited   all 4 core lenses recorded, but open AUDIT / CONFIDENCE / unverified
#             references remain
#   done      all 4 core lenses recorded and nothing open
#   missing   listed in INDEX.md but the file is absent on disk
#
# ── Output ────────────────────────────────────────────────────────────────────
# One line per chapter (INDEX.md order):
#   <status>  <rel_path>  research=N conf=lo/me audit=mi/ma lenses=D/4 gfx=y|n refs=V/T [warn=...]
#   - rel_path is relative to <research>/content/
#   - each key=value token is self-describing and order-stable, so callers can
#     parse by key; `#`-prefixed lines are header/summary and can be filtered
#     with `grep -vE '^#'`.
#   - `warn=` appears only when signals contradict each other (e.g. an audit lens
#     recorded while RESEARCH directives are still open).
# A trailing `# summary:` line tallies chapters per status. Chapters on disk but
# absent from INDEX.md are listed under `# untracked:`.
#
# ── Usage ─────────────────────────────────────────────────────────────────────
#   research-status.sh [research_dir] [--status S] [--path P]
#     research_dir   path to the research project (default: ./research)
#     --status S      only emit chapters whose derived status is S
#                     (stub|inquiry|draft|audited|done|missing)
#     --path P        only emit chapters whose rel_path equals P or is under the
#                     directory prefix P (e.g. --path data-pipelines/)
#   Filters suppress the summary/untracked footer so the output stays a clean,
#   machine-parsable candidate list for the cycle skills.

set -euo pipefail

research_dir=""
status_filter=""
path_filter=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --status) status_filter="${2:-}"; shift 2 ;;
    --path)   path_filter="${2:-}"; shift 2 ;;
    -h|--help) tail -n +2 "$0" | grep '^#' | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "Error: unknown option '$1'" >&2; exit 2 ;;
    *)  if [[ -z "$research_dir" ]]; then research_dir="$1"; else
          echo "Error: unexpected argument '$1'" >&2; exit 2
        fi; shift ;;
  esac
done

research_dir="${research_dir:-research}"
index_file="$research_dir/INDEX.md"
content_dir="$research_dir/content"

if [[ ! -f "$index_file" ]]; then
  echo "Error: INDEX.md not found at $index_file" >&2
  exit 1
fi

filtered=0
[[ -n "$status_filter" || -n "$path_filter" ]] && filtered=1

# ── Signal extraction from one chapter .md file ───────────────────────────────
# Emits: sections|research|conf_low|conf_med|audit_minor|audit_major|audit_unk|audit_field
scan_md() {
  awk '
    BEGIN { fm=0; fmdone=0; af=""; sec=0; rs=0; cl=0; cm=0; amin=0; amaj=0; aunk=0; ina=0; sev="" }
    NR==1 && $0=="---" { fm=1; next }
    fm && !fmdone && $0=="---" { fmdone=1; fm=0; next }
    fm && !fmdone && /^audit:/ { af=$0; next }
    fm && !fmdone { next }
    /^#{2,}[[:space:]]/ { sec++ }
    /<!-- RESEARCH:/ { rs++ }
    /<!-- CONFIDENCE:[[:space:]]*low/ { cl++ }
    /<!-- CONFIDENCE:[[:space:]]*medium/ { cm++ }
    /<!-- AUDIT:/ { ina=1; sev=""; if ($0 ~ /-->/) closea(); next }
    ina && sev=="" && /severity:/ { s=$0; sub(/.*severity:[[:space:]]*/,"",s); gsub(/[^a-zA-Z]/,"",s); sev=tolower(s) }
    ina && /-->/ { closea() }
    function closea() {
      if (sev=="major") amaj++; else if (sev=="minor") amin++; else aunk++;
      ina=0
    }
    END { printf "%d|%d|%d|%d|%d|%d|%d|%s\n", sec, rs, cl, cm, amin, amaj, aunk, af }
  ' "$1"
}

# ── Reference verification counts from a _references.yaml sibling ─────────────
# Emits: verified|total  (0|0 when the file is absent)
scan_refs() {
  [[ -f "$1" ]] || { echo "0|0"; return; }
  awk '
    BEGIN { tot=0; ver=0 }
    /^[^[:space:]#][^:]*:[[:space:]]*$/ { tot++ }
    /^[[:space:]]+verified:[[:space:]]*true[[:space:]]*$/ { ver++ }
    END { printf "%d|%d\n", ver, tot }
  ' "$1"
}

# ── Ordered chapter list from INDEX.md (link headings only) ──────────────────
ordered_files=()
while IFS= read -r path; do
  ordered_files+=("${path#content/}")
done < <(grep -oE '^#{2,} \[.*\]\(content/[^)]+\.md\)' "$index_file" | grep -oE 'content/[^)]+\.md')

declare -A in_index=()

# ── Emit one status line per chapter ─────────────────────────────────────────
declare -A tally=()
emit() {
  local rel="$1" md="$2"
  in_index["$rel"]=1
  if [[ ! -f "$md" ]]; then
    [[ -n "$status_filter" && "$status_filter" != "missing" ]] && return
    [[ -n "$path_filter" ]] && ! path_matches "$rel" && return
    printf '%-8s %-44s (file absent on disk)\n' "missing" "$rel"
    tally[missing]=$(( ${tally[missing]:-0} + 1 ))
    return
  fi

  IFS='|' read -r sec rs cl cm amin amaj aunk af < <(scan_md "$md")
  local refs; refs="$(scan_refs "${md%.md}_references.yaml")"
  local rv rt; IFS='|' read -r rv rt <<< "$refs"

  # core lenses recorded in the frontmatter `audit:` field
  local lenses=0 gfx="n"
  [[ "$af" == *consistency* ]] && lenses=$((lenses+1))
  [[ "$af" == *coverage*    ]] && lenses=$((lenses+1))
  [[ "$af" == *quality*     ]] && lenses=$((lenses+1))
  [[ "$af" == *coherence*   ]] && lenses=$((lenses+1))
  [[ "$af" == *graphics*    ]] && gfx="y"

  local audit_open=$(( amin + amaj + aunk ))
  local conf_open=$(( cl + cm ))
  local refs_pending=$(( rt - rv ))

  local status
  if (( rs > 0 )); then
    status="inquiry"
  elif (( sec == 0 )); then
    status="stub"
  elif (( lenses < 4 )); then
    status="draft"
  elif (( audit_open == 0 && conf_open == 0 && refs_pending == 0 )); then
    status="done"
  else
    status="audited"
  fi

  # contradictory signals worth surfacing
  local warn=""
  (( rs > 0 && lenses > 0 )) && warn="audit-before-investigation"

  [[ -n "$status_filter" && "$status_filter" != "$status" ]] && return
  [[ -n "$path_filter" ]] && ! path_matches "$rel" && return

  tally[$status]=$(( ${tally[$status]:-0} + 1 ))
  printf '%-8s %-44s research=%d conf=%d/%d audit=%d/%d lenses=%d/4 gfx=%s refs=%d/%d' \
    "$status" "$rel" "$rs" "$cl" "$cm" "$amin" "$(( amaj + aunk ))" "$lenses" "$gfx" "$rv" "$rt"
  [[ -n "$warn" ]] && printf ' warn=%s' "$warn"
  printf '\n'
}

path_matches() {
  local rel="$1"
  [[ "$rel" == "$path_filter" || "$rel" == "$path_filter"/* || "$rel" == "$path_filter"* ]]
}

if [[ $filtered -eq 0 ]]; then
  printf '# status   %-44s detail\n' "chapter"
fi

for rel in "${ordered_files[@]}"; do
  emit "$rel" "$content_dir/$rel"
done

# ── Footers (suppressed when filtering) ──────────────────────────────────────
if [[ $filtered -eq 0 ]]; then
  # untracked: chapter files on disk not present in INDEX.md
  if [[ -d "$content_dir" ]]; then
    untracked=()
    while IFS= read -r f; do
      rel="${f#"$content_dir"/}"
      [[ "$rel" == *_references.yaml ]] && continue
      [[ "$rel" == *_assets/* ]] && continue
      [[ -n "${in_index[$rel]:-}" ]] && continue
      untracked+=("$rel")
    done < <(find "$content_dir" -type f -name '*.md' | sort)
    if [[ ${#untracked[@]} -gt 0 ]]; then
      echo
      for rel in "${untracked[@]}"; do
        echo "# untracked: $rel (on disk, absent from INDEX.md)"
      done
    fi
  fi

  echo
  printf '# summary:'
  for s in stub inquiry draft audited done missing; do
    printf ' %s=%d' "$s" "${tally[$s]:-0}"
  done
  printf '\n'
fi
