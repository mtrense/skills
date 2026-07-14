#!/usr/bin/env bash
# Deterministic query surface over the domain-driven task backlog.
#
# The backlog is a directory of markdown files (`tasks/NNNN-slug.md`), one task
# each, whose YAML frontmatter is the query index. The backlog can grow large, so
# NO skill or subagent ever scans the task files themselves — every question about
# the corpus is answered here and returns only ids / paths / small JSON, never the
# prose bodies. This is the single source of truth for "what is the state of the
# backlog"; every domain-driven skill shells out to it.
#
# ── Task identity ─────────────────────────────────────────────────────────────
# A task's canonical id is the 4-digit `NNNN` prefix of its filename — NOT the
# frontmatter `id:` field (which is redundant documentation). Deriving id from the
# filename dodges YAML octal parsing of leading-zero numbers. `depends_on` /
# `split_into` references are normalized to the same 4-digit form regardless of
# whether the frontmatter wrote them as `0003`, `3`, or `"0003"`.
#
# ── Frontmatter fields consulted ──────────────────────────────────────────────
#   status         draft | todo | in progress | done | split
#   context        context-map context name (may be empty until refine)
#   depends_on     list of task ids this task waits on
#   split_into     list of child ids (only on a `split` tombstone)
#   related_adrs   list of ADR numbers (reported, not used for scheduling)
#
# ── Commands ──────────────────────────────────────────────────────────────────
#   tasks.sh ready              todo tasks whose every depends_on is `done`
#                               (the scheduler's ready-set), ascending id
#   tasks.sh next-id            next free 4-digit id (max existing + 1)
#   tasks.sh by-status <s>      ids whose status is <s>
#   tasks.sh by-context <c>     ids whose context is <c>
#   tasks.sh get <id>           that task's frontmatter as JSON (+ _file, _id)
#   tasks.sh blockers <id>      <id>'s depends_on that are NOT yet `done`
#   tasks.sh dependents <id>    tasks that depend_on <id> (reverse edges)
#   tasks.sh check-dag          exit 0 iff the depends_on graph over non-terminal
#                               tasks is acyclic and has no dangling references;
#                               otherwise prints the problem and exits non-zero
#   tasks.sh board              one summary line of counts per status
#   tasks.sh list               full JSON array of the loaded model (debug)
#
# All commands accept an optional trailing `--dir <tasks-dir>` (default ./tasks).
#
# Requires: yj (YAML->JSON, invoked as `yj -yj`) and jq.
set -euo pipefail

TASKS_DIR="tasks"
# Pull an optional `--dir X` from anywhere in the argument list.
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) TASKS_DIR="$2"; shift 2 ;;
    *) args+=("$1"); shift ;;
  esac
done
set -- "${args[@]:-}"

command -v jq >/dev/null 2>&1 || { echo "tasks.sh: jq not found on PATH" >&2; exit 3; }
command -v yj >/dev/null 2>&1 || { echo "tasks.sh: yj not found on PATH" >&2; exit 3; }

# ── _load ─────────────────────────────────────────────────────────────────────
# Emit the whole backlog as one normalized JSON array. Each element:
#   {_id, _file, status, context, depends_on:[ids], split_into:[ids],
#    related_adrs:[...], title}
# ids everywhere are 4-digit strings. Missing list fields default to [].
_load() {
  local f fm json id
  local first=1
  printf '['
  # Nullglob so an empty backlog yields an empty array, not a literal glob.
  shopt -s nullglob
  for f in "$TASKS_DIR"/[0-9][0-9][0-9][0-9]-*.md; do
    id="$(basename "$f")"; id="${id:0:4}"
    # Extract the frontmatter block: everything between the first pair of `---`.
    fm="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f{print}' "$f")"
    if [ -z "$fm" ]; then
      json='{}'
    else
      json="$(printf '%s\n' "$fm" | yj -yj 2>/dev/null || echo '{}')"
    fi
    [ $first -eq 1 ] || printf ','
    first=0
    # Normalize inside jq: 4-digit ids, list defaults, filename-derived _id.
    printf '%s' "$json" | jq -c --arg id "$id" --arg file "$f" '
      def pad4: if . == null then empty
                elif (.|type)=="number" then (.|floor|tostring|("0000"+.)[-4:])
                else (tostring|gsub("[^0-9]";"")|("0000"+.)[-4:]) end;
      def ids(k): (.[k] // []) | (if type=="array" then . else [.] end)
                  | map(pad4) | map(select(length>0));
      {
        _id: $id,
        _file: $file,
        title: (.title // ""),
        status: (.status // "draft"),
        context: (.context // ""),
        depends_on: ids("depends_on"),
        split_into: ids("split_into"),
        related_adrs: (.related_adrs // [])
      }'
  done
  printf ']'
}

cmd="${1:-}"; shift || true

case "$cmd" in
  ready)
    _load | jq -r '
      (map({(._id): .status}) | add) as $st
      | map(select(.status=="todo"
            and (all(.depends_on[]; ($st[.] // "missing")=="done"))))
      | sort_by(._id) | .[]._id'
    ;;

  next-id)
    _load | jq -r 'if length==0 then "0001"
      else (map(._id|tonumber)|max+1|tostring|("0000"+.)[-4:]) end'
    ;;

  by-status)
    want="${1:?usage: tasks.sh by-status <status>}"
    _load | jq -r --arg s "$want" 'map(select(.status==$s))|sort_by(._id)|.[]._id'
    ;;

  by-context)
    want="${1:?usage: tasks.sh by-context <context>}"
    _load | jq -r --arg c "$want" 'map(select(.context==$c))|sort_by(._id)|.[]._id'
    ;;

  get)
    want="${1:?usage: tasks.sh get <id>}"
    want="$(printf '%04d' "$((10#${want}))" 2>/dev/null || echo "$want")"
    _load | jq --arg id "$want" 'map(select(._id==$id))|.[0] // error("no such task: \($id)")'
    ;;

  blockers)
    want="${1:?usage: tasks.sh blockers <id>}"
    want="$(printf '%04d' "$((10#${want}))" 2>/dev/null || echo "$want")"
    _load | jq -r --arg id "$want" '
      (map({(._id): .status}) | add) as $st
      | (map(select(._id==$id))|.[0] // error("no such task: \($id)")) as $t
      | $t.depends_on[] | select(($st[.] // "missing")!="done")'
    ;;

  dependents)
    want="${1:?usage: tasks.sh dependents <id>}"
    want="$(printf '%04d' "$((10#${want}))" 2>/dev/null || echo "$want")"
    _load | jq -r --arg id "$want" 'map(select(.depends_on|index($id)))|sort_by(._id)|.[]._id'
    ;;

  check-dag)
    # First guard: every task file must be named canonically `NNNN-slug.md`. A
    # file the loader can't glob (e.g. a split that suffixed an id — `0007a-...`)
    # is INVISIBLE to every other command here, so it would silently vanish from
    # the backlog: never scheduled, never counted, never checked. Catch it loudly.
    shopt -s nullglob
    stray=()
    for f in "$TASKS_DIR"/*.md; do
      b="$(basename "$f")"
      [[ "$b" =~ ^[0-9][0-9][0-9][0-9]-.+\.md$ ]] || stray+=("$b")
    done
    if [ "${#stray[@]}" -gt 0 ]; then
      echo "MALFORMED task filename(s): ${stray[*]}" >&2
      echo "Task files must be NNNN-slug.md. A split mints fresh top-level ids via 'tasks.sh next-id' — never id suffixes like 0007a/0007b or 0007-1. Rename these to fresh ids and repoint any dependents." >&2
      exit 3
    fi
    # Consider only non-terminal tasks (a `split` tombstone is inert). Report the
    # first structural problem found; exit 0 only when the graph is clean.
    _load | jq -e '
      map(select(.status!="split")) as $nodes
      | ($nodes | map(._id)) as $live
      | # dangling: a depends_on that names no live task
        ([ $nodes[] | ._id as $from | .depends_on[]
           | select((. as $d | $live | index($d)) | not)
           | "\($from) -> \(.)" ]) as $dangling
      | if ($dangling|length) > 0
        then "DANGLING depends_on (target missing or split): \($dangling|join(", "))\n" | halt_error(1)
        else . end
      | # cycle: Kahn peel. Repeatedly drop nodes whose deps are all already dropped.
        reduce range(0; ($nodes|length)) as $_ (
          {remaining: $nodes, dropped: []};
          (.dropped) as $done
          | (.remaining | map(select(all(.depends_on[]; . as $d | $done | index($d))))) as $ready
          | if ($ready|length)==0 then .
            else {remaining: (.remaining - $ready),
                  dropped: ($done + ($ready|map(._id)))} end
        )
      | if (.remaining|length) > 0
        then "CYCLE among tasks: \(.remaining|map(._id)|join(", "))\n" | halt_error(2)
        else "ok: \($live|length) live tasks, acyclic" end' -r
    ;;

  board)
    _load | jq -r '
      (map(.status) | group_by(.) | map({(.[0]): length}) | add // {}) as $c
      | "draft=\($c.draft//0) todo=\($c.todo//0) in_progress=\($c["in progress"]//0) done=\($c.done//0) split=\($c.split//0) total=\(length)"'
    ;;

  list)
    _load | jq '.'
    ;;

  ""|help|-h|--help)
    grep -E '^#   tasks\.sh' "$0" | sed 's/^#   //'
    ;;

  *)
    echo "tasks.sh: unknown command '$cmd' (try: tasks.sh help)" >&2
    exit 2
    ;;
esac
