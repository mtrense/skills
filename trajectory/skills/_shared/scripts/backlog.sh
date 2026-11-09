#!/usr/bin/env bash
# Deterministic query-and-bookkeeping surface over a trajectory project's backlog.
#
# The backlog is three directories of markdown files whose YAML frontmatter is the
# query index: tasks/NNNN-slug.md, demos/NNNN-slug.md, and
# documentation/decisions/NNNN-slug.md. The backlog can grow large, so NO skill or
# subagent ever scans the file bodies — every mechanical question is answered here
# and returns only ids / paths / small JSON. Prose bodies are read only by the one
# agent working that one item.
#
# ── Identity ──────────────────────────────────────────────────────────────────
# An item's canonical id is the 4-digit `NNNN` filename prefix — it is NEVER
# duplicated into frontmatter (two sources of truth drift, and YAML parses bare
# 0042 as octal). Each kind (task/demo/decision) has its own id sequence.
# List references (`depends_on`, `demos`, `decisions`, `proves`) are normalized
# to 4-digit strings however the frontmatter wrote them.
#
# ── Frontmatter fields ────────────────────────────────────────────────────────
#   all kinds     title
#   task          status (todo|in-progress|done|rejected), complexity (low|medium|high),
#                 demos [], depends_on [], decisions [], proves [], documents []
#   demo          status (red|green|shown|dropped), gate (flag|hold),
#                 check (shell command, run from the project root), checked_at (sha|null)
#   decision      status (proposed|accepted|rejected|superseded),
#                 proof (none|pending|proven), superseded_by (id or null)
#
# ── Demos ─────────────────────────────────────────────────────────────────────
# A demo is a checkpoint worth calling the human over for: a scenario plus an
# executable end-to-end `check`. It is NOT a container of tasks — tasks list the
# demos they are known to serve (`demos: [...]`) as a hint for scheduling, never
# as a definition of done. A demo's red/green status is set ONLY by `demo-check`,
# which runs the check command: the code decides, never task bookkeeping.
#   red      the check fails (or does not exist yet) — still being built
#   green    the check passes — ready for the human test cycle (/land)
#   shown    the human ran the test cycle and accepted it (set by /land)
#   dropped  human tombstone — the demo is abandoned
# A red demo with no live (todo|in-progress) task listing it is STALLED: every
# known piece of work is finished and the outcome still does not run, so the
# missing work was never written down. That is the gap signal (-> /enrich).
# A red demo with no live task that has an open `## Decisions to make` item
# carrying `after: NNNN`, where demo NNNN is not yet shown, is WAITING instead:
# its next step depends on the human's verdict on that demo (-> /land NNNN, then
# /decide). Verdict items are how work is held back until a human has seen
# something — a knowledge dependency on breakdown, never a scheduling barrier.
#
# ── Commands ──────────────────────────────────────────────────────────────────
#   backlog.sh new <task|demo|decision> <slug> <title...>
#                                mint the next id, write the frontmatter + body
#                                skeleton, print the created path
#   backlog.sh next-id <kind>    next free 4-digit id for that kind
#   backlog.sh ready [--demo <id>]
#                                todo tasks whose every depends_on is done (the
#                                burn-down's available set), ascending id; with
#                                --demo, only tasks listing that demo plus the
#                                tasks they transitively depend on
#   backlog.sh by-status <kind> <s>   ids of <kind> whose status is <s>
#   backlog.sh by-demo <id>      task ids listing demo <id>
#   backlog.sh get <kind> <id>   that item's frontmatter as JSON (+ _id, _file)
#   backlog.sh blockers <id>     task <id>'s depends_on that are NOT yet done
#   backlog.sh dependents <id>   tasks that depend_on task <id> (reverse edges)
#   backlog.sh provers <id>      tasks whose `proves` lists decision <id>
#   backlog.sh set-status <kind> <id> <status>    flip a status (validated per kind)
#   backlog.sh set-proof <id> <none|pending|proven> [--force]
#                                flip a decision's proof field; `proven` is
#                                refused while any `## Proof` claim is unticked
#                                (--force overrides, for a claimless legacy record)
#   backlog.sh proof-claims <id> that decision's `## Proof` claims, one per line,
#                                prefixed OPEN/DONE (exit 1 if any is OPEN)
#   backlog.sh set-superseded <old-id> <new-id>   old decision -> status: superseded
#                                + superseded_by: <new-id>
#   backlog.sh demo-check <id>... | --all
#                                run each demo's `check` command from the project
#                                root, flip status red/green, record checked_at
#                                (short HEAD sha); full output goes to
#                                .trajectory/demo-NNNN.log. --all checks every red
#                                and green demo. Prints one line per demo
#                                (`NNNN GREEN|RED`, plus FLIPPED when it changed);
#                                exit 0 iff every checked demo is green
#   backlog.sh demo-state [<id>] state report for one demo (exit 0 iff GREEN) or,
#                                with no id, for every red/green demo
#   backlog.sh waiting-on <id>   open verdict items (`after: <id>`) in other
#                                demos, one per line: `NNNN<TAB><item text>`
#   backlog.sh held              green demos with gate: hold — built, not yet
#                                seen by the human (/burn will not dispatch past
#                                them without asking)
#   backlog.sh pending-proofs    every proof:pending decision with its proving
#                                tasks and their statuses
#   backlog.sh check             structural gate: canonical filenames, dangling
#                                references, live deps on rejected tasks,
#                                dependency cycles -> non-zero exit; plus warnings
#                                (stalled demos, pending proof without a live
#                                proving task, ...)
#   backlog.sh board [-c]        human board: tasks table, demos with derived
#                                state, decisions, warnings (-c colors the status
#                                column)
#   backlog.sh dense [-c] [-w N] glyph-only dashboard: one glyph per item, slot =
#                                id (gaps shown as ·), grouped in tens, N slots
#                                per row (default 50). Counts per glyph in each
#                                kind's header; legend last
#
# All commands accept optional trailing `--tasks-dir D` / `--demos-dir D` /
# `--decisions-dir D` (defaults: ./tasks ./demos ./documentation/decisions).
#
# Requires: yj (YAML->JSON, invoked as `yj -yj`) and jq.
set -euo pipefail

TASKS_DIR="tasks"
DEMOS_DIR="demos"
DECISIONS_DIR="documentation/decisions"
LOG_DIR=".trajectory"

args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --tasks-dir) TASKS_DIR="$2"; shift 2 ;;
    --demos-dir) DEMOS_DIR="$2"; shift 2 ;;
    --decisions-dir) DECISIONS_DIR="$2"; shift 2 ;;
    *) args+=("$1"); shift ;;
  esac
done
set -- "${args[@]:-}"

command -v jq >/dev/null 2>&1 || { echo "backlog.sh: jq not found on PATH" >&2; exit 3; }
command -v yj >/dev/null 2>&1 || { echo "backlog.sh: yj not found on PATH" >&2; exit 3; }

_dir_for() {
  case "$1" in
    task) echo "$TASKS_DIR" ;;
    demo) echo "$DEMOS_DIR" ;;
    decision) echo "$DECISIONS_DIR" ;;
    *) echo "backlog.sh: unknown kind '$1' (want task|demo|decision)" >&2; exit 2 ;;
  esac
}

_pad4() { printf '%04d' "$((10#$1))"; }

# Frontmatter of one file as JSON ({} when absent/unparseable).
_fm_json() {
  local fm
  fm="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f{print}' "$1")"
  if [ -z "$fm" ]; then echo '{}'; else
    printf '%s\n' "$fm" | yj -yj 2>/dev/null || echo '{}'
  fi
}

# Emit one kind's whole corpus as a normalized JSON array (ids are 4-digit
# strings everywhere, list fields default to [], _id derives from the filename).
_load() {
  local kind="$1" dir f id json first=1
  dir="$(_dir_for "$kind")"
  printf '['
  shopt -s nullglob
  for f in "$dir"/[0-9][0-9][0-9][0-9]-*.md; do
    id="$(basename "$f")"; id="${id:0:4}"
    json="$(_fm_json "$f")"
    [ $first -eq 1 ] || printf ','
    first=0
    printf '%s' "$json" | jq -c --arg id "$id" --arg file "$f" --arg kind "$kind" '
      def pad4: if . == null then empty
                elif (.|type)=="number" then (.|floor|tostring|("0000"+.)[-4:])
                else (tostring|gsub("[^0-9]";"")|("0000"+.)[-4:]) end;
      def ids(k): (.[k] // []) | (if type=="array" then . else [.] end)
                  | map(pad4) | map(select(length>0));
      {_id: $id, _file: $file, title: (.title // "")}
      + (if $kind=="task" then
          {status: (.status // "todo"),
           complexity: (.complexity // "medium"),
           demos: ids("demos"),
           depends_on: ids("depends_on"),
           decisions: ids("decisions"),
           proves: ids("proves"),
           documents: ((.documents // []) | if type=="array" then . else [.] end)}
        elif $kind=="demo" then
          {status: (.status // "red"),
           gate: (.gate // "flag"),
           check: ((.check // "") | tostring),
           checked_at: (if .checked_at == null then null else (.checked_at|tostring) end)}
        else
          {status: (.status // "proposed"),
           proof: (.proof // "none"),
           superseded_by: (if .superseded_by == null then null else (.superseded_by|pad4) end)}
        end)'
  done
  printf ']'
}

# Decision ids back-referenced from a demo body via the `decision: NNNN`
# markers /decide writes (the demo->decision edge lives in prose, so this one
# bounded grep is the sanctioned way to read it).
_demo_decisions() {
  local file="$1"
  # Skip the frontmatter block so a stray frontmatter field never matches.
  awk 'NR==1&&$0=="---"{f=1;next} f==1&&$0=="---"{f=2;next} f!=1{print}' "$file" \
    | grep -oE 'decision: [0-9]{4}' | grep -oE '[0-9]{4}' | sort -u || true
}

# ── Body-section readers ──────────────────────────────────────────────────────
# The two edges that cannot live in frontmatter — a demo's item checklists and a
# decision's proof claims — are checklist lines in the body. These bounded
# readers are the sanctioned way to see them; nothing else reads a body. Each one
# is line-shaped, so the grammar is the contract:
#   demo item           - [x] <text> — decision: NNNN
#   verdict item        - [ ] <text> — after: NNNN   (a Decisions-to-make item
#                       that cannot be decided before demo NNNN is shown)
#   proof claim         - [x] <claim> — <how it was demonstrated>

# Lines of one `## <heading>` section (heading text without the `## `).
_section_lines() {
  awk -v want="## $2" '/^## /{ insec = ($0 == want); next } insec { print }' "$1"
}

# Bullet lines of one section (anything starting `- `), or nothing.
_section_bullets() {
  _section_lines "$1" "$2" | grep -E '^[[:space:]]*-[[:space:]]' || true
}

# A demo's UNSETTLED checklist items: not ticked, or ticked without the
# `decision: NNNN` back-reference /decide writes (either way, no decision record
# exists, so nothing downstream can wire or clear it).
_demo_open_items() {
  local f="$1" h line
  for h in "Decisions to make" "Needs proving"; do
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      if printf '%s' "$line" | grep -qE '^[[:space:]]*-[[:space:]]*\[[xX]\]' \
         && printf '%s' "$line" | grep -qE 'decision:[[:space:]]*[0-9]{4}'; then continue; fi
      printf '%s: %s\n' "$h" "$(printf '%s' "$line" | sed -E 's/^[[:space:]]*-[[:space:]]*(\[[[:space:]xX]?\][[:space:]]*)?//')"
    done <<< "$(_section_bullets "$f" "$h")"
  done
}

# A demo's open verdict items: unsettled `## Decisions to make` items carrying
# `after: NNNN`. One line each: `NNNN<TAB><item text>`.
_demo_verdict_items() {
  _demo_open_items "$1" | grep -E '^Decisions to make: .*after:[[:space:]]*[0-9]{4}' \
    | sed -E 's/^Decisions to make: //' \
    | while IFS= read -r item; do
        printf '%s\t%s\n' "$(printf '%s' "$item" | grep -oE 'after:[[:space:]]*[0-9]{4}' | grep -oE '[0-9]{4}' | head -1)" "$item"
      done || true
}

# Demo ids a demo is still waiting on: awaited by an open verdict item and not
# yet shown (a dropped one counts too — the item needs re-homing, see _warnings).
_demo_waiting() { # $1 demo id, $2 demos json
  local f
  f="$(printf '%s' "$2" | jq -r --arg id "$1" 'map(select(._id==$id))|.[0]._file // empty')"
  [ -n "$f" ] || return 0
  _demo_verdict_items "$f" | cut -f1 | sort -u | while read -r a; do
    [ -n "$a" ] || continue
    printf '%s' "$2" | jq -e --arg id "$a" 'map(select(._id==$id and .status=="shown"))|length>0' >/dev/null \
      || echo "$a"
  done
}

# A decision's proof claims (checklist lines under ## Proof), all / unticked.
_decision_claims() {
  _section_bullets "$1" "Proof" | grep -E '^[[:space:]]*-[[:space:]]*\[[ xX]\]' || true
}
_decision_open_claims() {
  _decision_claims "$1" | grep -E '^[[:space:]]*-[[:space:]]*\[[[:space:]]?\]' || true
}

_head_sha() { git rev-parse --short HEAD 2>/dev/null || echo "nogit"; }

# Rewrite (or insert) one top-level frontmatter field of a file.
_fm_set() {
  local file="$1" key="$2" val="$3" tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/backlog.XXXXXX")"
  awk -v key="$key" -v val="$val" '
    NR==1 && $0=="---" { infm=1; print; next }
    infm && $0=="---" { if (!done) print key ": " val; infm=0; print; next }
    infm && index($0, key ":")==1 { print key ": " val; done=1; next }
    { print }' "$file" > "$tmp"
  cat "$tmp" > "$file"
  rm -f "$tmp"
}

# Derived display state of one demo (JSON object in, word out): with no live
# task listing the demo, red becomes WAITING when it awaits another demo's
# verdict, STALLED otherwise.
_demo_display_state() { # $1 demo id, $2 demo status, $3 tasks json, $4 demos json
  local live
  if [ "$2" != "red" ]; then echo "$2"; return; fi
  live="$(printf '%s' "$3" | jq -r --arg d "$1" \
    '[.[]|select((.demos|index($d)) and (.status|IN("todo","in-progress")))]|length')"
  if [ "$live" -ne 0 ]; then echo "red"
  elif [ -n "$(_demo_waiting "$1" "$4")" ]; then echo "waiting"
  else echo "stalled"; fi
}

# State report of one demo. Prints detail lines; last line is the verdict:
# GREEN | RED | WAITING | STALLED | SHOWN | DROPPED. Returns 0 iff GREEN.
_demo_state_report() {
  local did="$1" demo dfile dstatus dcheck dchecked tasks_json demos_json head verdict d
  demos_json="$(_load demo)"
  demo="$(printf '%s' "$demos_json" | jq -c --arg id "$did" 'map(select(._id==$id))|.[0] // empty')"
  [ -n "$demo" ] || { echo "no such demo: $did" >&2; return 2; }
  dfile="$(printf '%s' "$demo" | jq -r '._file')"
  dstatus="$(printf '%s' "$demo" | jq -r '.status')"
  dcheck="$(printf '%s' "$demo" | jq -r '.check')"
  dchecked="$(printf '%s' "$demo" | jq -r '.checked_at // ""')"
  case "$dstatus" in
    shown) echo "SHOWN"; return 1 ;;
    dropped) echo "DROPPED"; return 1 ;;
  esac
  tasks_json="$(_load task)"
  head="$(_head_sha)"

  [ -n "$dcheck" ] || echo "  no check command — the demo can never turn green (add \`check:\` via /aim or /enrich)"
  if [ -z "$dchecked" ]; then
    echo "  never checked (backlog.sh demo-check $did)"
  elif [ "$dchecked" != "$head" ]; then
    echo "  last checked at $dchecked, HEAD is $head — re-run backlog.sh demo-check $did"
  fi

  # Unsettled items: ground /decide never settled, so /enrich could not break it down.
  local open_items; open_items="$(_demo_open_items "$dfile")"
  [ -z "$open_items" ] || printf '%s\n' "$open_items" | sed 's/^/  open item: /'

  # Verdict items: which awaited demos are still unseen, which have been shown.
  local a ast waiting
  while IFS=$'\t' read -r a _; do
    [ -n "$a" ] || continue
    ast="$(printf '%s' "$demos_json" | jq -r --arg id "$a" 'map(select(._id==$id))|.[0].status // "missing"')"
    case "$ast" in
      shown)   echo "  verdict given: demo $a is shown — its verdict item can be decided now (/decide)" ;;
      dropped) echo "  awaits dropped demo $a — re-home or drop the verdict item" ;;
      missing) echo "  awaits demo $a, which does not exist" ;;
      *)       echo "  awaiting verdict: demo $a ($ast) — /land $a first, then /decide" ;;
    esac
  done <<< "$(_demo_verdict_items "$dfile" | cut -f1 | sort -u)"
  waiting="$(_demo_waiting "$did" "$demos_json")"

  local total live done_ids
  total="$(printf '%s' "$tasks_json" | jq -r --arg d "$did" '[.[]|select(.demos|index($d))]|length')"
  live="$(printf '%s' "$tasks_json" | jq -r --arg d "$did" '
    [.[]|select((.demos|index($d)) and (.status|IN("todo","in-progress")))|._id]|join(", ")')"
  done_ids="$(printf '%s' "$tasks_json" | jq -r --arg d "$did" '
    [.[]|select((.demos|index($d)) and .status=="done")|._id]|join(", ")')"
  if [ "$total" -eq 0 ]; then
    echo "  no tasks list demo $did yet (run /enrich)"
  else
    [ -z "$live" ] || echo "  open tasks: $live"
    [ -z "$done_ids" ] || echo "  done tasks: $done_ids"
  fi

  # Pending proofs back-referenced from the demo: informational. They are cleared
  # with the user at /land; they never hold the check's verdict hostage.
  local decisions_json; decisions_json="$(_load decision)"
  for d in $(_demo_decisions "$dfile"); do
    local dproof provers dec_file n_all n_open
    dproof="$(printf '%s' "$decisions_json" | jq -r --arg id "$d" 'map(select(._id==$id))|.[0].proof // "missing"')"
    [ "$dproof" = "pending" ] || continue
    dec_file="$(printf '%s' "$decisions_json" | jq -r --arg id "$d" 'map(select(._id==$id))|.[0]._file // empty')"
    provers="$(printf '%s' "$tasks_json" | jq -r --arg d "$d" \
      '[.[]|select(.proves|index($d))|"\(._id) (\(.status))"]|join(", ")')"
    n_all="$(_decision_claims "$dec_file" | grep -c . || true)"
    n_open="$(_decision_open_claims "$dec_file" | grep -c . || true)"
    echo "  pending proof: decision $d — proving tasks: ${provers:-NONE} — claims: $((n_all - n_open))/$n_all ticked (cleared at /land)"
  done

  case "$dstatus" in
    green) verdict="GREEN" ;;
    *) if [ -z "$live" ] && [ -n "$waiting" ]; then
         verdict="WAITING"
         echo "  waiting: the next step depends on the human's verdict on demo(s) $(printf '%s' "$waiting" | paste -sd, -)"
       elif [ -z "$live" ]; then
         verdict="STALLED"
         echo "  stalled: red with no live task — the missing work was never written down (/enrich $did)"
       else verdict="RED"; fi ;;
  esac
  echo "$verdict"
  [ "$verdict" = "GREEN" ]
}

# Warning lines shared by `check` and `board`.
_warnings() {
  local tasks_json decisions_json demos_json
  tasks_json="$(_load task)"
  decisions_json="$(_load decision)"
  demos_json="$(_load demo)"
  # proof:pending decision with no live (todo|in-progress|done) proving task
  printf '%s' "$decisions_json" | jq -r --argjson tasks "$tasks_json" '
    .[] | select(.proof=="pending" and (.status|IN("rejected","superseded")|not))
    | ._id as $d
    | ([$tasks[]|select((.proves|index($d)) and (.status|IN("todo","in-progress","done")))]) as $provers
    | select(($provers|length)==0)
    | "pending proof with no live proving task: decision \(._id) (\(.title))"'
  # stalled demos: red with no live task listing them and no verdict to wait for
  # (a waiting demo is the honest state of held-back work, not a warning)
  printf '%s' "$demos_json" | jq -r --argjson tasks "$tasks_json" '
    .[] | select(.status=="red") | ._id as $d
    | select([$tasks[]|select((.demos|index($d)) and (.status|IN("todo","in-progress")))]|length==0)
    | "\(._id)\t\(.title)"' \
  | while IFS=$'\t' read -r sid stitle; do
      [ -n "$sid" ] || continue
      [ -z "$(_demo_waiting "$sid" "$demos_json")" ] \
        && echo "demo $sid is stalled: red with no live task ($stitle) — /enrich $sid"
    done
  # verdict items whose awaited demo was dropped — the verdict will never come
  local vf vid va
  shopt -s nullglob
  for vf in "$DEMOS_DIR"/[0-9][0-9][0-9][0-9]-*.md; do
    vid="$(basename "$vf")"; vid="${vid:0:4}"
    printf '%s' "$demos_json" | jq -e --arg id "$vid" \
      'map(select(._id==$id and (.status|IN("red","green"))))|length>0' >/dev/null || continue
    while IFS=$'\t' read -r va _; do
      [ -n "$va" ] || continue
      printf '%s' "$demos_json" | jq -e --arg id "$va" 'map(select(._id==$id and .status=="dropped"))|length>0' >/dev/null \
        && echo "demo $vid awaits the verdict of dropped demo $va — re-home or drop the item (/decide or edit the demo)"
    done <<< "$(_demo_verdict_items "$vf" | cut -f1 | sort -u)"
  done
  # green hold-gated demos nobody has seen yet — /burn will not build past them
  printf '%s' "$demos_json" | jq -r '
    .[] | select(.status=="green" and .gate=="hold")
    | "demo \(._id) is green under gate: hold and not yet shown — /land \(._id) before burning on"'
  # demos that can never turn green
  printf '%s' "$demos_json" | jq -r '
    .[] | select((.status|IN("red","green")) and (.check|length)==0)
    | "demo \(._id) has no check command — it can never turn green"'
  # partially broken down: tasks already exist for a demo that still has open items
  local df did open_n task_n
  shopt -s nullglob
  for df in "$DEMOS_DIR"/[0-9][0-9][0-9][0-9]-*.md; do
    did="$(basename "$df")"; did="${did:0:4}"
    printf '%s' "$demos_json" | jq -e --arg id "$did" \
      'map(select(._id==$id and (.status|IN("red","green"))))|length>0' >/dev/null || continue
    open_n="$(_demo_open_items "$df" | grep -c . || true)"
    task_n="$(printf '%s' "$tasks_json" | jq -r --arg d "$did" '[.[]|select(.demos|index($d))]|length')"
    if [ "$open_n" -gt 0 ] && [ "$task_n" -gt 0 ]; then
      echo "demo $did is partially broken down: $task_n task(s) exist but $open_n item(s) are still open (/decide, then /enrich)"
    fi
  done
  # pending proof recorded without the claims it has to demonstrate
  printf '%s' "$decisions_json" | jq -r '.[]|select(.proof=="pending")|"\(._id)\t\(._file)"' \
  | while IFS=$'\t' read -r did dfile; do
      [ -n "$dfile" ] || continue
      [ -z "$(_decision_claims "$dfile")" ] \
        && echo "decision $did is proof: pending with no ## Proof claims — nothing states what a proving task must demonstrate (/decide)"
    done
  # superseded decision missing its superseded_by pointer
  printf '%s' "$decisions_json" | jq -r '
    .[] | select(.status=="superseded" and .superseded_by==null)
    | "superseded decision \(._id) has no superseded_by"'
  # proves pointing at a decision that is not (or no longer) awaiting/holding proof
  printf '%s' "$tasks_json" | jq -r --argjson ds "$decisions_json" '
    (reduce $ds[] as $d ({}; .[$d._id]=$d)) as $by
    | .[] | select(.status|IN("todo","in-progress"))
    | ._id as $t | .proves[]
    | select(($by[.] // null) as $d | $d != null and ($d.status|IN("rejected","superseded")))
    | "task \($t) proves decision \(.) which is \($by[.].status)"'
  # live task serving a demo that is no longer being built
  printf '%s' "$tasks_json" | jq -r --argjson ds "$demos_json" '
    (reduce $ds[] as $d ({}; .[$d._id]=$d.status)) as $st
    | .[] | select(.status|IN("todo","in-progress")) | ._id as $t | .demos[]
    | select(($st[.] // "")=="dropped")
    | "task \($t) serves demo \(.) which is dropped"'
}

# Run one demo's check, flip red/green, record checked_at. Prints the result
# line; returns 0 iff green.
_demo_check_one() {
  local did="$1" demo dfile dstatus dcheck head log rc new mark
  demo="$(_load demo | jq -c --arg id "$did" 'map(select(._id==$id))|.[0] // empty')"
  [ -n "$demo" ] || { echo "no such demo: $did" >&2; return 2; }
  dfile="$(printf '%s' "$demo" | jq -r '._file')"
  dstatus="$(printf '%s' "$demo" | jq -r '.status')"
  dcheck="$(printf '%s' "$demo" | jq -r '.check')"
  case "$dstatus" in
    shown|dropped) echo "$did SKIPPED ($dstatus — not re-checked)"; return 0 ;;
  esac
  head="$(_head_sha)"
  mkdir -p "$LOG_DIR"
  log="$LOG_DIR/demo-$did.log"
  if [ -z "$dcheck" ]; then
    echo "no check command in $dfile" > "$log"; rc=127
  else
    set +e
    { echo "\$ $dcheck"; echo "# at $head"; bash -c "$dcheck" 2>&1; } > "$log"
    rc=$?
    # the exit status of the brace group is that of its last command (the check)
    set -e
  fi
  if [ "$rc" -eq 0 ]; then new="green"; else new="red"; fi
  _fm_set "$dfile" status "$new"
  _fm_set "$dfile" checked_at "\"$head\""
  mark=""; [ "$new" = "$dstatus" ] || mark=" FLIPPED from $dstatus"
  if [ "$new" = "green" ]; then
    echo "$did GREEN at $head$mark — log: $log"
    return 0
  fi
  echo "$did RED at $head (exit $rc)$mark — log: $log"
  tail -n 15 "$log" | sed 's/^/    /'
  return 1
}

cmd="${1:-}"; shift || true

case "$cmd" in
  new)
    kind="${1:?usage: backlog.sh new <task|demo|decision> <slug> <title...>}"
    slug="${2:?usage: backlog.sh new <task|demo|decision> <slug> <title...>}"
    shift 2
    title="$*"
    [ -n "$title" ] || { echo "usage: backlog.sh new <kind> <slug> <title...>" >&2; exit 2; }
    dir="$(_dir_for "$kind")"
    mkdir -p "$dir"
    last="$(find "$dir" -maxdepth 1 -name '[0-9][0-9][0-9][0-9]-*.md' -exec basename {} \; | sort | tail -1 | cut -c1-4)"
    nnnn="$(_pad4 "$((10#${last:-0} + 1))")"
    file="$dir/$nnnn-$slug.md"
    [ ! -e "$file" ] || { echo "$file already exists" >&2; exit 1; }
    case "$kind" in
      task) cat > "$file" <<EOF
---
title: $title
status: todo
complexity: medium
demos: []
depends_on: []
decisions: []
proves: []
documents: []
---

## Plan

## Acceptance criteria

## Notes
EOF
      ;;
      demo) cat > "$file" <<EOF
---
title: $title
status: red
gate: flag
check: ""
checked_at: null
---

## Outcome

## Scenario

## Human check

## Decisions to make

## Needs proving

## Showing
EOF
      ;;
      decision) cat > "$file" <<EOF
---
title: $title
status: proposed
proof: none
superseded_by: null
---

## Context

## Decision

## Rationale

## Consequences

## Proof
EOF
      ;;
    esac
    echo "$file"
    ;;

  next-id)
    kind="${1:?usage: backlog.sh next-id <task|demo|decision>}"
    _load "$kind" | jq -r 'if length==0 then "0001"
      else (map(._id|tonumber)|max+1|tostring|("0000"+.)[-4:]) end'
    ;;

  ready)
    demo=""
    if [ "${1:-}" = "--demo" ]; then demo="$(_pad4 "${2:?usage: backlog.sh ready [--demo <id>]}")"; fi
    _load task | jq -r --arg demo "$demo" '
      (map({(._id): .status}) | add // {}) as $st
      | (map({(._id): .depends_on}) | add // {}) as $deps
      | (if $demo == "" then null else
          # tasks listing the demo, plus everything they transitively depend on
          [ .[] | select(.demos|index($demo)) | ._id ]
          | until(. as $s | ([ $s[], ($s[] | $deps[.] // [] | .[]) ] | unique) == ($s|unique);
                  . as $s | [ $s[], ($s[] | $deps[.] // [] | .[]) ] | unique)
         end) as $scope
      | map(select(.status=="todo"
            and (all(.depends_on[]; ($st[.] // "missing")=="done"))
            and (._id as $i | $scope == null or ($scope|index($i)) != null)))
      | sort_by(._id) | .[]._id'
    ;;

  by-status)
    kind="${1:?usage: backlog.sh by-status <kind> <status>}"
    want="${2:?usage: backlog.sh by-status <kind> <status>}"
    _load "$kind" | jq -r --arg s "$want" 'map(select(.status==$s))|sort_by(._id)|.[]._id'
    ;;

  by-demo)
    want="$(_pad4 "${1:?usage: backlog.sh by-demo <id>}")"
    _load task | jq -r --arg d "$want" 'map(select(.demos|index($d)))|sort_by(._id)|.[]._id'
    ;;

  get)
    kind="${1:?usage: backlog.sh get <kind> <id>}"
    want="$(_pad4 "${2:?usage: backlog.sh get <kind> <id>}")"
    _load "$kind" | jq --arg id "$want" 'map(select(._id==$id))|.[0] // error("no such \("item"): \($id)")'
    ;;

  blockers)
    want="$(_pad4 "${1:?usage: backlog.sh blockers <id>}")"
    _load task | jq -r --arg id "$want" '
      (map({(._id): .status}) | add // {}) as $st
      | (map(select(._id==$id))|.[0] // error("no such task: \($id)")) as $t
      | $t.depends_on[] | select(($st[.] // "missing")!="done")'
    ;;

  dependents)
    want="$(_pad4 "${1:?usage: backlog.sh dependents <id>}")"
    _load task | jq -r --arg id "$want" 'map(select(.depends_on|index($id)))|sort_by(._id)|.[]._id'
    ;;

  provers)
    want="$(_pad4 "${1:?usage: backlog.sh provers <id>}")"
    _load task | jq -r --arg id "$want" 'map(select(.proves|index($id)))|sort_by(._id)
      |.[]|"\(._id) \(.status)"'
    ;;

  set-status)
    kind="${1:?usage: backlog.sh set-status <kind> <id> <status>}"
    id="$(_pad4 "${2:?usage: backlog.sh set-status <kind> <id> <status>}")"
    new="${3:?usage: backlog.sh set-status <kind> <id> <status>}"
    case "$kind:$new" in
      task:todo | task:in-progress | task:done | task:rejected) ;;
      demo:red | demo:shown | demo:dropped) ;;
      demo:green) echo "refusing: only \`backlog.sh demo-check\` turns a demo green — run its check" >&2; exit 2 ;;
      decision:proposed | decision:accepted | decision:rejected | decision:superseded) ;;
      *) echo "invalid status '$new' for kind '$kind'" >&2; exit 2 ;;
    esac
    file="$(_load "$kind" | jq -r --arg id "$id" 'map(select(._id==$id))|.[0]._file // empty')"
    [ -n "$file" ] || { echo "no such $kind: $id" >&2; exit 1; }
    if [ "$kind:$new" = "demo:shown" ]; then
      cur="$(_load demo | jq -r --arg id "$id" 'map(select(._id==$id))|.[0].status')"
      [ "$cur" = "green" ] || { echo "refusing: demo $id is $cur — only a green demo can be shown (backlog.sh demo-check $id)" >&2; exit 1; }
    fi
    _fm_set "$file" status "$new"
    echo "$file -> status: $new"
    ;;

  set-proof)
    id="$(_pad4 "${1:?usage: backlog.sh set-proof <id> <none|pending|proven> [--force]}")"
    new="${2:?usage: backlog.sh set-proof <id> <none|pending|proven> [--force]}"
    force=0; [ "${3:-}" = "--force" ] && force=1
    case "$new" in none | pending | proven) ;; *) echo "invalid proof: $new" >&2; exit 2 ;; esac
    file="$(_load decision | jq -r --arg id "$id" 'map(select(._id==$id))|.[0]._file // empty')"
    [ -n "$file" ] || { echo "no such decision: $id" >&2; exit 1; }
    # Flipping to proven is the moment the obligation disappears — refuse while
    # any claim is unticked, so a part-proven decision cannot be closed wholesale.
    if [ "$new" = "proven" ] && [ "$force" -ne 1 ]; then
      open_claims="$(_decision_open_claims "$file")"
      if [ -n "$open_claims" ]; then
        echo "refusing: decision $id still has open proof claims —" >&2
        printf '%s\n' "$open_claims" | sed 's/^/  /' >&2
        echo "tick each claim in $file as a landed task demonstrates it, or re-run with --force" >&2
        exit 1
      fi
    fi
    _fm_set "$file" proof "$new"
    echo "$file -> proof: $new"
    ;;

  set-superseded)
    old="$(_pad4 "${1:?usage: backlog.sh set-superseded <old-id> <new-id>}")"
    new="$(_pad4 "${2:?usage: backlog.sh set-superseded <old-id> <new-id>}")"
    file="$(_load decision | jq -r --arg id "$old" 'map(select(._id==$id))|.[0]._file // empty')"
    [ -n "$file" ] || { echo "no such decision: $old" >&2; exit 1; }
    _fm_set "$file" status superseded
    _fm_set "$file" superseded_by "\"$new\""
    echo "$file -> status: superseded, superseded_by: $new"
    ;;

  demo-check)
    [ -n "${1:-}" ] || { echo "usage: backlog.sh demo-check <id>... | --all" >&2; exit 2; }
    if [ "$1" = "--all" ]; then
      ids="$(_load demo | jq -r 'map(select(.status|IN("red","green")))|sort_by(._id)|.[]._id')"
      [ -n "$ids" ] || { echo "no red or green demos to check"; exit 0; }
    else
      ids=""; for a in "$@"; do ids="$ids $(_pad4 "$a")"; done
    fi
    rc=0
    for d in $ids; do _demo_check_one "$d" || rc=1; done
    exit "$rc"
    ;;

  demo-state)
    if [ -n "${1:-}" ]; then
      _demo_state_report "$(_pad4 "$1")"
    else
      ids="$(_load demo | jq -r 'map(select(.status|IN("red","green")))|sort_by(._id)|.[]._id')"
      [ -n "$ids" ] || { echo "no red or green demos (/aim to define the next one)"; exit 0; }
      for d in $ids; do
        title="$(_load demo | jq -r --arg id "$d" 'map(select(._id==$id))|.[0].title')"
        echo "demo $d — $title"
        _demo_state_report "$d" || true
      done
      exit 0
    fi
    ;;

  waiting-on)
    want="$(_pad4 "${1:?usage: backlog.sh waiting-on <demo-id>}")"
    shopt -s nullglob
    for f in "$DEMOS_DIR"/[0-9][0-9][0-9][0-9]-*.md; do
      wid="$(basename "$f")"; wid="${wid:0:4}"
      [ "$wid" != "$want" ] || continue
      _demo_verdict_items "$f" | awk -F'\t' -v w="$want" -v id="$wid" '$1==w { print id "\t" $2 }'
    done
    ;;

  held)
    _load demo | jq -r 'map(select(.status=="green" and .gate=="hold"))|sort_by(._id)|.[]._id'
    ;;

  pending-proofs)
    tasks_json="$(_load task)"
    _load decision | jq -r 'map(select(.proof=="pending"))|sort_by(._id)|.[]
      | "\(._id)\t\(.status)\t\(._file)\t\(.title)"' \
    | while IFS=$'\t' read -r did dstatus dfile dtitle; do
        provers="$(printf '%s' "$tasks_json" | jq -r --arg d "$did" \
          '[.[]|select(.proves|index($d))|"\(._id) (\(.status))"]|join(", ")')"
        n_all="$(_decision_claims "$dfile" | grep -c . || true)"
        n_open="$(_decision_open_claims "$dfile" | grep -c . || true)"
        if [ "$n_all" -eq 0 ]; then claims="claims: NONE RECORDED"
        else claims="claims: $((n_all - n_open))/$n_all ticked"; fi
        echo "$did [$dstatus] $dtitle — proving tasks: ${provers:-NONE} — $claims"
        if [ "$n_open" -gt 0 ]; then
          _decision_open_claims "$dfile" \
            | sed -E 's/^[[:space:]]*-[[:space:]]*\[[[:space:]]?\][[:space:]]*/    open claim: /'
        fi
      done
    ;;

  proof-claims)
    want="$(_pad4 "${1:?usage: backlog.sh proof-claims <decision-id>}")"
    file="$(_load decision | jq -r --arg id "$want" 'map(select(._id==$id))|.[0]._file // empty')"
    [ -n "$file" ] || { echo "no such decision: $want" >&2; exit 1; }
    claims="$(_decision_claims "$file")"
    [ -n "$claims" ] || { echo "(no ## Proof claims recorded)"; exit 1; }
    printf '%s\n' "$claims" | sed -E \
      -e 's/^[[:space:]]*-[[:space:]]*\[[xX]\][[:space:]]*/DONE /' \
      -e 's/^[[:space:]]*-[[:space:]]*\[[[:space:]]?\][[:space:]]*/OPEN /'
    [ -z "$(_decision_open_claims "$file")" ]
    ;;

  check)
    fail=0
    # 1. canonical filenames in all three dirs (a file the loader cannot glob is
    #    invisible to every other command — never scheduled, counted, or checked)
    shopt -s nullglob
    for d in "$TASKS_DIR" "$DEMOS_DIR" "$DECISIONS_DIR"; do
      [ -d "$d" ] || continue
      for f in "$d"/*.md; do
        b="$(basename "$f")"
        [[ "$b" =~ ^[0-9][0-9][0-9][0-9]-.+\.md$ ]] \
          || { echo "FAIL malformed filename: $f (want NNNN-slug.md)"; fail=1; }
      done
    done

    tasks_json="$(_load task)"
    demos_json="$(_load demo)"
    decisions_json="$(_load decision)"

    # 2. dangling references + live deps on rejected tasks
    problems="$(printf '%s' "$tasks_json" | jq -r \
      --argjson ds "$demos_json" --argjson decs "$decisions_json" '
      (reduce .[] as $t ({}; .[$t._id]=$t.status)) as $tst
      | ([$ds[]._id]) as $demo_ids
      | ([$decs[]._id]) as $dids
      | [ .[] | ._id as $id | .status as $st |
          (.depends_on[] | select(($tst[.] // "missing")=="missing")
            | "FAIL task \($id): depends_on \(.) does not exist"),
          (select($st|IN("todo","in-progress")) | .depends_on[]
            | select(($tst[.] // "")=="rejected")
            | "FAIL live task \($id): depends_on rejected task \(.) — rewire or drop the edge"),
          (.demos[] | select(($demo_ids|index(.))|not)
            | "FAIL task \($id): demo \(.) does not exist"),
          ((.decisions + .proves)[] | select(($dids|index(.))|not)
            | "FAIL task \($id): decision \(.) does not exist")
        ] | .[]')"
    if [ -n "$problems" ]; then echo "$problems"; fail=1; fi

    # 3. demo field values
    bad="$(printf '%s' "$demos_json" | jq -r '.[]
      | (select(.status|IN("red","green","shown","dropped")|not)
          | "FAIL demo \(._id): invalid status \(.status) (want red|green|shown|dropped)"),
        (select(.gate|IN("flag","hold")|not)
          | "FAIL demo \(._id): invalid gate \(.gate) (want flag|hold)")')"
    if [ -n "$bad" ]; then echo "$bad"; fail=1; fi

    # 4. dependency cycles (Kahn peel over non-rejected tasks)
    cycle="$(printf '%s' "$tasks_json" | jq -r '
      map(select(.status!="rejected")) as $nodes
      | ($nodes|map(._id)) as $live
      | reduce range(0; ($nodes|length)) as $_ (
          {remaining: $nodes, dropped: []};
          (.dropped) as $done
          | (.remaining | map(select(all(.depends_on[];
              (. as $d | ($done|index($d)) or (($live|index($d))|not))))))
            as $ready
          | if ($ready|length)==0 then .
            else {remaining: (.remaining - $ready),
                  dropped: ($done + ($ready|map(._id)))} end)
      | if (.remaining|length) > 0
        then "FAIL dependency cycle among tasks: \(.remaining|map(._id)|join(", "))"
        else empty end')"
    if [ -n "$cycle" ]; then echo "$cycle"; fail=1; fi

    # 5. demo-body decision back-references must resolve
    for f in "$DEMOS_DIR"/[0-9][0-9][0-9][0-9]-*.md; do
      for d in $(_demo_decisions "$f"); do
        printf '%s' "$decisions_json" | jq -e --arg id "$d" 'map(select(._id==$id))|length>0' >/dev/null \
          || { echo "FAIL demo $(basename "$f"): back-references decision $d which does not exist"; fail=1; }
      done
      # verdict items must await an existing, other demo
      fid="$(basename "$f")"; fid="${fid:0:4}"
      while IFS=$'\t' read -r a _; do
        [ -n "$a" ] || continue
        if [ "$a" = "$fid" ]; then
          echo "FAIL demo $(basename "$f"): a verdict item awaits the demo itself (after: $a)"; fail=1
        elif ! printf '%s' "$demos_json" | jq -e --arg id "$a" 'map(select(._id==$id))|length>0' >/dev/null; then
          echo "FAIL demo $(basename "$f"): a verdict item awaits demo $a which does not exist"; fail=1
        fi
      done <<< "$(_demo_verdict_items "$f" | cut -f1 | sort -u)"
    done

    # 6. warnings (never fail the gate; the board repeats them)
    warns="$(_warnings)"
    if [ -n "$warns" ]; then printf '%s\n' "$warns" | sed 's/^/WARN /'; fi

    if [ "$fail" -ne 0 ]; then exit 1; fi
    echo "ok: backlog structurally sound"
    ;;

  board)
    color=0
    if [ "${1:-}" = "-c" ]; then color=1; shift || true; fi
    esc=$'\x1b'
    colorize_status() {
      if [ "$color" -ne 1 ]; then cat; return; fi
      local pre='^([^ ]+ +)' post='( )'
      sed -E \
        -e "s/${pre}(done|shown|proven)${post}/\1${esc}[32m\2${esc}[0m\3/" \
        -e "s/${pre}(todo|accepted)${post}/\1${esc}[94m\2${esc}[0m\3/" \
        -e "s/${pre}(in-progress|proposed|pending|waiting)${post}/\1${esc}[33m\2${esc}[0m\3/" \
        -e "s/${pre}(red|stalled)${post}/\1${esc}[31m\2${esc}[0m\3/" \
        -e "s/${pre}(rejected|superseded|dropped)${post}/\1${esc}[90m\2${esc}[0m\3/" \
        -e "s/${pre}(green)${post}/\1${esc}[92m\2${esc}[0m\3/"
    }

    tasks_json="$(_load task)"
    echo "TASKS"
    if [ "$(printf '%s' "$tasks_json" | jq 'length')" -eq 0 ]; then
      echo "  (none)"
    else
      {
        printf 'ID\tSTATUS\tCPLX\tDEMOS\tTITLE\tDEPS\n'
        printf '%s' "$tasks_json" | jq -r 'sort_by(._id)|.[]
          | [._id, .status, .complexity,
             (if (.demos|length)>0 then (.demos|join(",")) else "-" end),
             .title,
             (if (.depends_on|length)>0 then "["+(.depends_on|join(","))+"]" else "" end)]
          | @tsv'
      } | column -t -s "$(printf '\t')" | colorize_status
    fi

    echo
    echo "DEMOS"
    demos_json="$(_load demo)"
    ds="$(printf '%s' "$demos_json" | jq -r 'sort_by(._id)|.[]|"\(._id)\t\(.status)\t\(.gate)\t\(.checked_at // "-")\t\(.title)"')"
    if [ -z "$ds" ]; then
      echo "  (none)"
    else
      head="$(_head_sha)"
      while IFS=$'\t' read -r did dstatus dgate dchecked dtitle; do
        state="$(_demo_display_state "$did" "$dstatus" "$tasks_json" "$demos_json")"
        stale="$dchecked"
        if [ "$dchecked" != "-" ] && [ "$dchecked" != "$head" ] && [ "$state" != "shown" ] && [ "$state" != "dropped" ]; then
          stale="$dchecked(stale)"
        fi
        printf '%s\t%s\t%s\t%s\t%s\n' "$did" "$state" "$dgate" "$stale" "$dtitle"
      done <<< "$ds" | column -t -s "$(printf '\t')" | colorize_status
    fi

    echo
    echo "DECISIONS"
    ds="$(_load decision | jq -r 'sort_by(._id)|.[]
      | "\(._id)\t\(.status)\t\(if .proof=="none" then "-" else "proof: "+.proof end)\t\(.title)"')"
    if [ -z "$ds" ]; then
      echo "  (none)"
    else
      printf '%s\n' "$ds" | column -t -s "$(printf '\t')" | colorize_status
    fi

    warns="$(_warnings)"
    if [ -n "$warns" ]; then
      printf '\nWARNINGS\n'
      printf '%s\n' "$warns" | sed 's/^/  /'
    fi
    ;;

  dense)
    color=0; width=50
    while [ $# -gt 0 ]; do
      case "$1" in
        -c) color=1; shift ;;
        -w) width="${2:?usage: backlog.sh dense [-c] [-w N]}"; shift 2 ;;
        *) echo "usage: backlog.sh dense [-c] [-w N]" >&2; exit 2 ;;
      esac
    done
    case "$width" in ''|*[!0-9]*|0) echo "backlog.sh: -w wants a positive integer" >&2; exit 2 ;; esac
    esc=$'\x1b'

    # The entire visual vocabulary: token -> "glyph color".
    _tok() {
      case "$1" in
        gap)         echo '· 90' ;;
        todo)        echo '○ 94' ;;
        blocked)     echo '◦ 90' ;;
        in-progress) echo '◐ 33' ;;
        done)        echo '● 32' ;;
        rejected)    echo '✕ 31' ;;
        red)         echo '○ 31' ;;
        waiting)     echo '‖ 33' ;;
        stalled)     echo '! 31' ;;
        green)       echo '◆ 92' ;;
        shown)       echo '● 32' ;;
        dropped)     echo '✕ 90' ;;
        proposed)    echo '○ 33' ;;
        accepted)    echo '● 32' ;;
        superseded)  echo '~ 90' ;;
        none)        echo '· 90' ;;
        pending)     echo '◐ 33' ;;
        proven)      echo '✔ 32' ;;
        *)           echo '? 90' ;;
      esac
    }
    _paint() { # glyph color
      if [ "$color" -eq 1 ]; then printf '%s[%sm%s%s[0m' "$esc" "$2" "$1" "$esc"
      else printf '%s' "$1"; fi
    }

    # One kind as glyph rows. $1 = row label, $2 = "NNNN token" lines,
    # $3 = token order for the count header. Slot position IS the id, so a
    # missing id renders as a gap and columns stay id-addressable.
    _dense_kind() {
      local label="$1" lines="$2" order="$3"
      local slot=() max=0 id tok i start end g c n counts=""
      while read -r id tok; do
        [ -n "${id:-}" ] || continue
        i=$((10#$id))
        slot[$i]="$tok"
        [ "$i" -gt "$max" ] && max="$i"
      done <<< "$lines"
      if [ "$max" -eq 0 ]; then printf '%s      (none)\n' "$label"; return; fi

      for tok in $order; do
        n=0
        for i in $(seq 1 "$max"); do [ "${slot[$i]:-gap}" = "$tok" ] && n=$((n + 1)); done
        [ "$n" -gt 0 ] || continue
        set -- $(_tok "$tok"); g="$1"; c="$2"
        counts="$counts  $(_paint "$g" "$c")$n"
      done
      printf '%s%s\n' "$label" "$counts"

      start=1
      while [ "$start" -le "$max" ]; do
        end=$((start + width - 1)); [ "$end" -gt "$max" ] && end="$max"
        printf '%s %04d ' "$label" "$start"
        for i in $(seq "$start" "$end"); do
          set -- $(_tok "${slot[$i]:-gap}"); g="$1"; c="$2"
          _paint "$g" "$c"
          [ $((i % 10)) -eq 0 ] && [ "$i" -lt "$end" ] && printf ' '
        done
        printf '\n'
        start=$((end + 1))
      done
    }

    tasks_json="$(_load task)"
    # todo splits into ready (all deps done) and blocked — the distinction the
    # burn-down actually schedules on.
    task_lines="$(printf '%s' "$tasks_json" | jq -r '
      (map({(._id): .status}) | add // {}) as $st
      | sort_by(._id)[]
      | ._id + " " + (if .status=="todo"
          then (if all(.depends_on[]; ($st[.] // "missing")=="done") then "todo" else "blocked" end)
          else .status end)')"
    _dense_kind T "$task_lines" "todo blocked in-progress done rejected"

    demos_json="$(_load demo)"
    demo_lines=""
    while IFS=$'\t' read -r did dstatus; do
      [ -n "${did:-}" ] || continue
      demo_lines="$demo_lines$did $(_demo_display_state "$did" "$dstatus" "$tasks_json" "$demos_json")"$'\n'
    done <<< "$(printf '%s' "$demos_json" | jq -r 'sort_by(._id)|.[]|"\(._id)\t\(.status)"')"
    _dense_kind S "$demo_lines" "red waiting stalled green shown dropped"

    decisions_json="$(_load decision)"
    _dense_kind D \
      "$(printf '%s' "$decisions_json" | jq -r 'sort_by(._id)|.[]|"\(._id) \(.status)"')" \
      "proposed accepted rejected superseded"
    _dense_kind P \
      "$(printf '%s' "$decisions_json" | jq -r 'sort_by(._id)|.[]|"\(._id) \(.proof)"')" \
      "none pending proven"

    warns="$(_warnings)"
    if [ -n "$warns" ]; then
      printf '⚠ %s  (backlog.sh check)\n' "$(printf '%s\n' "$warns" | wc -l | tr -d ' ')"
    fi

    printf 'T ○ready ◦blocked ◐wip ●done ✕rejected | S demo ○red ‖waiting !stalled ◆green ●shown ✕dropped | D ○proposed ●accepted ✕rejected ~superseded | P proof ·none ◐pending ✔proven | ·gap\n'
    ;;

  ""|help|-h|--help)
    grep -E '^#   backlog\.sh' "$0" | sed 's/^#   //'
    ;;

  *)
    echo "backlog.sh: unknown command '$cmd' (try: backlog.sh help)" >&2
    exit 2
    ;;
esac
