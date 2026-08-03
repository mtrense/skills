#!/usr/bin/env bash
# Deterministic query-and-bookkeeping surface over a trajectory project's backlog.
#
# The backlog is three directories of markdown files whose YAML frontmatter is the
# query index: tasks/NNNN-slug.md, milestones/NNNN-slug.md, and
# documentation/decisions/NNNN-slug.md. The backlog can grow large, so NO skill or
# subagent ever scans the file bodies — every mechanical question is answered here
# and returns only ids / paths / small JSON. Prose bodies are read only by the one
# agent working that one item.
#
# ── Identity ──────────────────────────────────────────────────────────────────
# An item's canonical id is the 4-digit `NNNN` filename prefix — it is NEVER
# duplicated into frontmatter (two sources of truth drift, and YAML parses bare
# 0042 as octal). Each kind (task/milestone/decision) has its own id sequence.
# List references (`depends_on`, `milestones`, `decisions`, `proves`) are
# normalized to 4-digit strings however the frontmatter wrote them.
#
# ── Frontmatter fields ────────────────────────────────────────────────────────
#   all kinds     title
#   task          status (todo|in-progress|done|rejected), complexity (low|medium|high),
#                 milestones [], depends_on [], decisions [], proves [], documents []
#   milestone     status (open|landed)
#   decision      status (proposed|accepted|rejected|superseded),
#                 proof (none|pending|proven), superseded_by (id or null)
#
# ── Derived state ─────────────────────────────────────────────────────────────
# A milestone is READY to land when at least one task lists it, every task listing
# it is done or rejected, and every `proof: pending` decision back-referenced from
# its body (the `decision: NNNN` markers /decide writes) is proven by a done task.
# A pending proof whose only live proving task sits in another milestone is
# reported as "blocked on proof: task NNNN (milestone MMMM)".
#
# ── Commands ──────────────────────────────────────────────────────────────────
#   backlog.sh new <task|milestone|decision> <slug> <title...>
#                                mint the next id, write the frontmatter + body
#                                skeleton, print the created path
#   backlog.sh next-id <kind>    next free 4-digit id for that kind
#   backlog.sh ready             todo tasks whose every depends_on is done
#                                (the burn-down's available set), ascending id
#   backlog.sh by-status <kind> <s>   ids of <kind> whose status is <s>
#   backlog.sh by-milestone <id> task ids listing milestone <id>
#   backlog.sh get <kind> <id>   that item's frontmatter as JSON (+ _id, _file)
#   backlog.sh blockers <id>     task <id>'s depends_on that are NOT yet done
#   backlog.sh dependents <id>   tasks that depend_on task <id> (reverse edges)
#   backlog.sh provers <id>      tasks whose `proves` lists decision <id>
#   backlog.sh set-status <kind> <id> <status>    flip a status (validated per kind)
#   backlog.sh set-proof <id> <none|pending|proven>   flip a decision's proof field
#   backlog.sh set-superseded <old-id> <new-id>   old decision -> status: superseded
#                                + superseded_by: <new-id>
#   backlog.sh milestone-ready [<id>]   readiness report for one milestone (exit 0
#                                iff ready) or, with no id, for every open one
#   backlog.sh pending-proofs    every proof:pending decision with its proving
#                                tasks and their statuses
#   backlog.sh check             structural gate: canonical filenames, dangling
#                                references, live deps on rejected tasks,
#                                dependency cycles -> non-zero exit; plus warnings
#                                (pending proof without a live proving task, ...)
#   backlog.sh board [-c]        human board: tasks table, milestones with derived
#                                state, decisions, warnings (-c colors the status
#                                column)
#
# All commands accept optional trailing `--tasks-dir D` / `--milestones-dir D` /
# `--decisions-dir D` (defaults: ./tasks ./milestones ./documentation/decisions).
#
# Requires: yj (YAML->JSON, invoked as `yj -yj`) and jq.
set -euo pipefail

TASKS_DIR="tasks"
MILESTONES_DIR="milestones"
DECISIONS_DIR="documentation/decisions"

args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --tasks-dir) TASKS_DIR="$2"; shift 2 ;;
    --milestones-dir) MILESTONES_DIR="$2"; shift 2 ;;
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
    milestone) echo "$MILESTONES_DIR" ;;
    decision) echo "$DECISIONS_DIR" ;;
    *) echo "backlog.sh: unknown kind '$1' (want task|milestone|decision)" >&2; exit 2 ;;
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
           milestones: ids("milestones"),
           depends_on: ids("depends_on"),
           decisions: ids("decisions"),
           proves: ids("proves"),
           documents: ((.documents // []) | if type=="array" then . else [.] end)}
        elif $kind=="milestone" then
          {status: (.status // "open")}
        else
          {status: (.status // "proposed"),
           proof: (.proof // "none"),
           superseded_by: (if .superseded_by == null then null else (.superseded_by|pad4) end)}
        end)'
  done
  printf ']'
}

# Decision ids back-referenced from a milestone body via the `decision: NNNN`
# markers /decide writes (the milestone->decision edge lives in prose, so this
# one bounded grep is the sanctioned way to read it).
_milestone_decisions() {
  local file="$1"
  # Skip the frontmatter block so a stray frontmatter field never matches.
  awk 'NR==1&&$0=="---"{f=1;next} f==1&&$0=="---"{f=2;next} f!=1{print}' "$file" \
    | grep -oE 'decision: [0-9]{4}' | grep -oE '[0-9]{4}' | sort -u || true
}

# Readiness of one milestone. Prints detail lines; last line is the verdict:
# READY | OPEN | LANDED. Returns 0 iff READY.
_milestone_ready_report() {
  local mid="$1" mfile mstatus tasks_json verdict="READY" d
  mfile="$(_load milestone | jq -r --arg id "$mid" 'map(select(._id==$id))|.[0]._file // empty')"
  [ -n "$mfile" ] || { echo "no such milestone: $mid" >&2; return 2; }
  mstatus="$(_load milestone | jq -r --arg id "$mid" 'map(select(._id==$id))|.[0].status')"
  if [ "$mstatus" = "landed" ]; then echo "LANDED"; return 1; fi

  tasks_json="$(_load task)"
  local open_tasks total
  total="$(printf '%s' "$tasks_json" | jq -r --arg m "$mid" '[.[]|select(.milestones|index($m))]|length')"
  open_tasks="$(printf '%s' "$tasks_json" | jq -r --arg m "$mid" '
    [.[]|select((.milestones|index($m)) and (.status|IN("done","rejected")|not))|._id]|join(", ")')"
  if [ "$total" -eq 0 ]; then
    echo "  no tasks list milestone $mid yet (run /enrich)"
    verdict="OPEN"
  elif [ -n "$open_tasks" ]; then
    echo "  open tasks: $open_tasks"
    verdict="OPEN"
  fi

  local decisions_json; decisions_json="$(_load decision)"
  for d in $(_milestone_decisions "$mfile"); do
    local dproof
    dproof="$(printf '%s' "$decisions_json" | jq -r --arg id "$d" 'map(select(._id==$id))|.[0].proof // "missing"')"
    [ "$dproof" = "pending" ] || continue
    # pending: proven iff some non-rejected proving task is done
    local prover_done prover_live
    prover_done="$(printf '%s' "$tasks_json" | jq -r --arg d "$d" '
      [.[]|select((.proves|index($d)) and .status=="done")|._id]|join(", ")')"
    if [ -n "$prover_done" ]; then continue; fi
    prover_live="$(printf '%s' "$tasks_json" | jq -r --arg d "$d" '
      [.[]|select((.proves|index($d)) and (.status|IN("todo","in-progress")))]')"
    if [ "$(printf '%s' "$prover_live" | jq 'length')" -gt 0 ]; then
      printf '%s' "$prover_live" | jq -r --arg d "$d" --arg m "$mid" '.[]
        | "  blocked on proof: task \(._id) (milestone \(if (.milestones|index($m)) then $m else (.milestones[0] // "none") end)) proves decision \($d)"'
    else
      echo "  pending proof: decision $d has NO live proving task (re-home via /enrich or revisit via /decide)"
    fi
    verdict="OPEN"
  done

  echo "$verdict"
  [ "$verdict" = "READY" ]
}

# Warning lines shared by `check` and `board`.
_warnings() {
  local tasks_json decisions_json
  tasks_json="$(_load task)"
  decisions_json="$(_load decision)"
  # proof:pending decision with no live (todo|in-progress|done) proving task
  printf '%s' "$decisions_json" | jq -r --argjson tasks "$tasks_json" '
    .[] | select(.proof=="pending" and (.status|IN("rejected","superseded")|not))
    | ._id as $d
    | ([$tasks[]|select((.proves|index($d)) and (.status|IN("todo","in-progress","done")))]) as $provers
    | select(($provers|length)==0)
    | "pending proof with no live proving task: decision \(._id) (\(.title))"'
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
}

cmd="${1:-}"; shift || true

case "$cmd" in
  new)
    kind="${1:?usage: backlog.sh new <task|milestone|decision> <slug> <title...>}"
    slug="${2:?usage: backlog.sh new <task|milestone|decision> <slug> <title...>}"
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
milestones: []
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
      milestone) cat > "$file" <<EOF
---
title: $title
status: open
---

## Outcome

## Decisions to make

## Needs proving

## Landing
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
EOF
      ;;
    esac
    echo "$file"
    ;;

  next-id)
    kind="${1:?usage: backlog.sh next-id <task|milestone|decision>}"
    _load "$kind" | jq -r 'if length==0 then "0001"
      else (map(._id|tonumber)|max+1|tostring|("0000"+.)[-4:]) end'
    ;;

  ready)
    _load task | jq -r '
      (map({(._id): .status}) | add // {}) as $st
      | map(select(.status=="todo"
            and (all(.depends_on[]; ($st[.] // "missing")=="done"))))
      | sort_by(._id) | .[]._id'
    ;;

  by-status)
    kind="${1:?usage: backlog.sh by-status <kind> <status>}"
    want="${2:?usage: backlog.sh by-status <kind> <status>}"
    _load "$kind" | jq -r --arg s "$want" 'map(select(.status==$s))|sort_by(._id)|.[]._id'
    ;;

  by-milestone)
    want="$(_pad4 "${1:?usage: backlog.sh by-milestone <id>}")"
    _load task | jq -r --arg m "$want" 'map(select(.milestones|index($m)))|sort_by(._id)|.[]._id'
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
      milestone:open | milestone:landed) ;;
      decision:proposed | decision:accepted | decision:rejected | decision:superseded) ;;
      *) echo "invalid status '$new' for kind '$kind'" >&2; exit 2 ;;
    esac
    file="$(_load "$kind" | jq -r --arg id "$id" 'map(select(._id==$id))|.[0]._file // empty')"
    [ -n "$file" ] || { echo "no such $kind: $id" >&2; exit 1; }
    sed -i.bak "1,/^status:/s/^status:.*/status: $new/" "$file" && rm -f "$file.bak"
    echo "$file -> status: $new"
    ;;

  set-proof)
    id="$(_pad4 "${1:?usage: backlog.sh set-proof <id> <none|pending|proven>}")"
    new="${2:?usage: backlog.sh set-proof <id> <none|pending|proven>}"
    case "$new" in none | pending | proven) ;; *) echo "invalid proof: $new" >&2; exit 2 ;; esac
    file="$(_load decision | jq -r --arg id "$id" 'map(select(._id==$id))|.[0]._file // empty')"
    [ -n "$file" ] || { echo "no such decision: $id" >&2; exit 1; }
    sed -i.bak "1,/^proof:/s/^proof:.*/proof: $new/" "$file" && rm -f "$file.bak"
    echo "$file -> proof: $new"
    ;;

  set-superseded)
    old="$(_pad4 "${1:?usage: backlog.sh set-superseded <old-id> <new-id>}")"
    new="$(_pad4 "${2:?usage: backlog.sh set-superseded <old-id> <new-id>}")"
    file="$(_load decision | jq -r --arg id "$old" 'map(select(._id==$id))|.[0]._file // empty')"
    [ -n "$file" ] || { echo "no such decision: $old" >&2; exit 1; }
    sed -i.bak \
      -e "1,/^status:/s/^status:.*/status: superseded/" \
      -e "1,/^superseded_by:/s/^superseded_by:.*/superseded_by: \"$new\"/" \
      "$file" && rm -f "$file.bak"
    echo "$file -> status: superseded, superseded_by: $new"
    ;;

  milestone-ready)
    if [ -n "${1:-}" ]; then
      _milestone_ready_report "$(_pad4 "$1")"
    else
      rc=0
      for m in $(_load milestone | jq -r 'map(select(.status=="open"))|sort_by(._id)|.[]._id'); do
        title="$(_load milestone | jq -r --arg id "$m" 'map(select(._id==$id))|.[0].title')"
        echo "milestone $m — $title"
        _milestone_ready_report "$m" || rc=$?
      done
      exit 0
    fi
    ;;

  pending-proofs)
    tasks_json="$(_load task)"
    _load decision | jq -r --argjson tasks "$tasks_json" '
      .[] | select(.proof=="pending")
      | ._id as $d
      | ([$tasks[]|select(.proves|index($d))|"\(._id) (\(.status))"]|join(", ")) as $p
      | "\(._id) [\(.status)] \(.title) — proving tasks: \(if $p=="" then "NONE" else $p end)"'
    ;;

  check)
    fail=0
    # 1. canonical filenames in all three dirs (a file the loader cannot glob is
    #    invisible to every other command — never scheduled, counted, or checked)
    shopt -s nullglob
    for d in "$TASKS_DIR" "$MILESTONES_DIR" "$DECISIONS_DIR"; do
      [ -d "$d" ] || continue
      for f in "$d"/*.md; do
        b="$(basename "$f")"
        [[ "$b" =~ ^[0-9][0-9][0-9][0-9]-.+\.md$ ]] \
          || { echo "FAIL malformed filename: $f (want NNNN-slug.md)"; fail=1; }
      done
    done

    tasks_json="$(_load task)"
    milestones_json="$(_load milestone)"
    decisions_json="$(_load decision)"

    # 2. dangling references + live deps on rejected tasks
    problems="$(printf '%s' "$tasks_json" | jq -r \
      --argjson ms "$milestones_json" --argjson ds "$decisions_json" '
      (reduce .[] as $t ({}; .[$t._id]=$t.status)) as $tst
      | ([$ms[]._id]) as $mids
      | ([$ds[]._id]) as $dids
      | [ .[] | ._id as $id | .status as $st |
          (.depends_on[] | select(($tst[.] // "missing")=="missing")
            | "FAIL task \($id): depends_on \(.) does not exist"),
          (select($st|IN("todo","in-progress")) | .depends_on[]
            | select(($tst[.] // "")=="rejected")
            | "FAIL live task \($id): depends_on rejected task \(.) — rewire or drop the edge"),
          (.milestones[] | select(($mids|index(.))|not)
            | "FAIL task \($id): milestone \(.) does not exist"),
          ((.decisions + .proves)[] | select(($dids|index(.))|not)
            | "FAIL task \($id): decision \(.) does not exist")
        ] | .[]')"
    if [ -n "$problems" ]; then echo "$problems"; fail=1; fi

    # 3. dependency cycles (Kahn peel over non-rejected tasks)
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

    # 4. milestone-body decision back-references must resolve
    for f in "$MILESTONES_DIR"/[0-9][0-9][0-9][0-9]-*.md; do
      for d in $(_milestone_decisions "$f"); do
        printf '%s' "$decisions_json" | jq -e --arg id "$d" 'map(select(._id==$id))|length>0' >/dev/null \
          || { echo "FAIL milestone $(basename "$f"): back-references decision $d which does not exist"; fail=1; }
      done
    done

    # 5. warnings (never fail the gate; the board repeats them)
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
        -e "s/${pre}(done|landed|proven)${post}/\1${esc}[32m\2${esc}[0m\3/" \
        -e "s/${pre}(todo|open|accepted)${post}/\1${esc}[94m\2${esc}[0m\3/" \
        -e "s/${pre}(in-progress|proposed|pending)${post}/\1${esc}[33m\2${esc}[0m\3/" \
        -e "s/${pre}(rejected|superseded)${post}/\1${esc}[90m\2${esc}[0m\3/" \
        -e "s/${pre}(READY)${post}/\1${esc}[92m\2${esc}[0m\3/"
    }

    tasks_json="$(_load task)"
    echo "TASKS"
    if [ "$(printf '%s' "$tasks_json" | jq 'length')" -eq 0 ]; then
      echo "  (none)"
    else
      {
        printf 'ID\tSTATUS\tCPLX\tMILESTONES\tTITLE\tDEPS\n'
        printf '%s' "$tasks_json" | jq -r 'sort_by(._id)|.[]
          | [._id, .status, .complexity,
             (if (.milestones|length)>0 then (.milestones|join(",")) else "-" end),
             .title,
             (if (.depends_on|length)>0 then "["+(.depends_on|join(","))+"]" else "" end)]
          | @tsv'
      } | column -t -s "$(printf '\t')" | colorize_status
    fi

    echo
    echo "MILESTONES"
    ms="$(_load milestone | jq -r 'sort_by(._id)|.[]|"\(._id)\t\(.status)\t\(.title)"')"
    if [ -z "$ms" ]; then
      echo "  (none)"
    else
      while IFS=$'\t' read -r mid mstatus mtitle; do
        state="$mstatus"
        if [ "$mstatus" = "open" ]; then
          if _milestone_ready_report "$mid" >/dev/null 2>&1; then state="READY"; fi
        fi
        printf '%s\t%s\t%s\n' "$mid" "$state" "$mtitle"
      done <<< "$ms" | column -t -s "$(printf '\t')" | colorize_status
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

  ""|help|-h|--help)
    grep -E '^#   backlog\.sh' "$0" | sed 's/^#   //'
    ;;

  *)
    echo "backlog.sh: unknown command '$cmd' (try: backlog.sh help)" >&2
    exit 2
    ;;
esac
