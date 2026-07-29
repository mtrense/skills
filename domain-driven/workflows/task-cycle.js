export const meta = {
  name: 'task-cycle-run',
  description: 'Drive ready todo tasks to done in the background — task-worker fan-out in git worktrees, serial integrator merge-back, a single scribe agent owning every status write',
  whenToUse: 'Burn down the domain-driven backlog unattended while the main session stays free for /task-append and /task-refine',
  model: 'sonnet',
  phases: [
    { title: 'Preflight', detail: 'locate tasks.sh, check-dag, resolve model map, base branch' },
    { title: 'Gate', detail: 'per pass: ready-set + complexities from tasks.sh' },
    { title: 'Claim', detail: 'scribe: todo → in progress (pathspec commit) + worktrees' },
    { title: 'Implement', detail: 'task-worker per task in its worktree, model per complexity, one escalation retry' },
    { title: 'Integrate', detail: 'integrator: serial merge-back, bounce-on-conflict' },
    { title: 'Record', detail: 'scribe: done/todo flips + closing records, worktree cleanup' },
  ],
}

// ---------------------------------------------------------------------------
// Workflow-backed twin of the /task-cycle skill (same task-worker + integrator
// contract), redesigned for BACKGROUND operation: the human keeps using the
// main session (/task-append, /task-refine) while this runs. Two deliberate
// departures from the prose skill follow from that:
//
//   1. ALWAYS worktree mode, even for one worker. Workers commit on isolated
//      task/NNNN branches and the integrator merges serially, so a worker's
//      Skill(commit) can never sweep the human's uncommitted drafts in the
//      main checkout into a code commit.
//   2. No blanket dirty-tree refusal. The human's in-flight edits are expected.
//      Instead, every main-checkout write goes through a serial "scribe" agent
//      that commits with an explicit pathspec (`git commit -m … -- <file>`),
//      touching only the one task file — and a ready task whose file itself
//      has uncommitted edits is skipped for the pass, never swept up.
//
// The skill's single-writer invariant survives one indirection deeper: a
// workflow script has no filesystem/bash, so "the orchestrator owns every
// status write" becomes "one scribe agent at a time, invoked only between
// batches, is the sole status writer". Workers still never touch the file.
// ---------------------------------------------------------------------------

const PREFLIGHT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['tasksSh', 'baseBranch', 'dagOk'],
  properties: {
    tasksSh: { type: ['string', 'null'], description: 'resolved path to tasks.sh, or null if not found' },
    baseBranch: { type: 'string', description: 'current branch name (`git branch --show-current`)' },
    dagOk: { type: 'boolean', description: 'true iff `tasks.sh check-dag` exited 0' },
    dagDetail: { type: 'string', description: 'check-dag output when it failed, else ""' },
    modelMapRaw: { type: ['string', 'null'], description: 'contents of .workflow-overrides/model-map, or null if absent' },
    inProgress: { type: 'string', description: 'space-separated ids already `in progress` (stale claims from a crashed run), else ""' },
  },
}

const GATE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['ready', 'todoCount', 'board'],
  properties: {
    ready: {
      type: 'array',
      description: 'the tasks.sh ready-set, ascending id',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['id', 'file', 'complexity', 'dirty'],
        properties: {
          id: { type: 'string', description: '4-digit task id' },
          file: { type: 'string', description: 'repo-relative task file path (tasks.sh get → _file)' },
          complexity: { type: 'string', description: 'frontmatter complexity: low | medium | high, "" if unset' },
          dirty: { type: 'boolean', description: 'true iff this task file has uncommitted changes (`git status --porcelain -- <file>` non-empty)' },
        },
      },
    },
    todoCount: { type: 'integer', description: 'count of tasks with status todo (ready or not)' },
    stallDetail: { type: 'string', description: 'when ready is empty but todoCount > 0: per-task `tasks.sh blockers` summary, else ""' },
    board: { type: 'string', description: '`tasks.sh board` output, verbatim' },
  },
}

const CLAIM_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['claimed'],
  properties: {
    claimed: {
      type: 'array',
      description: 'tasks successfully claimed + worktree\'d, in input order',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['id', 'branch', 'worktree'],
        properties: {
          id: { type: 'string' },
          branch: { type: 'string', description: 'task/NNNN' },
          worktree: { type: 'string', description: 'absolute path of the created worktree' },
        },
      },
    },
    failed: { type: 'string', description: 'ids that could not be claimed and why, else ""' },
  },
}

// task-worker's parser-friendly report block, as a schema. manualTesting and
// deviations are written VERBATIM into the task's ## Closing by the scribe.
const WORKER_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['result', 'commit', 'summary', 'manualTesting', 'deviations'],
  properties: {
    result: { type: 'string', enum: ['ok', 'failed'] },
    commit: { type: 'string', description: 'commit sha, or "none" on failure' },
    summary: { type: 'string', description: 'one or two lines on what was done, or why it failed' },
    tests: { type: 'string', description: 'what was run and the outcome' },
    manualTesting: { type: 'string', description: 'the MANUAL_TESTING block: how a human verifies the outcome by hand' },
    deviations: { type: 'string', description: 'the DEVIATIONS block: departures from the plan, or "none"' },
  },
}

const INTEGRATE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['integrated', 'bounced', 'baseSha'],
  properties: {
    integrated: { type: 'array', items: { type: 'string' }, description: 'task ids that merged cleanly, in merge order' },
    bounced: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['id', 'paths'],
        properties: {
          id: { type: 'string' },
          paths: { type: 'string', description: 'conflicting paths' },
        },
      },
    },
    baseSha: { type: 'string', description: 'base branch HEAD after integration' },
  },
}

const RECORD_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['done', 'reset', 'board'],
  properties: {
    done: { type: 'array', items: { type: 'string' }, description: 'ids flipped to done + committed' },
    reset: { type: 'array', items: { type: 'string' }, description: 'ids reset to todo + committed' },
    board: { type: 'string', description: '`tasks.sh board` after the writes' },
    notes: { type: 'string', description: 'anything that went wrong (cleanup failures, etc.), else ""' },
  },
}

// ---------------------------------------------------------------------------
// Argument parsing: `[<limit>|all][@<workers>]` as a string ("all@4", "3", "@2"),
// or {limit, workers}. Default all@1.
// ---------------------------------------------------------------------------

let limit = null // null = all
let workers = 1
{
  const spec =
    typeof args === 'string' ? args.trim()
    : args && typeof args === 'object' ? `${args.limit ?? 'all'}@${args.workers ?? 1}`
    : ''
  const m = spec.match(/^(all|\d+)?(?:@(\d+))?$/i)
  if (spec && !m) throw new Error(`Unparseable argument "${spec}" — expected [<limit>|all][@<workers>]`)
  if (m && m[1] && m[1].toLowerCase() !== 'all') limit = parseInt(m[1], 10)
  if (m && m[2]) workers = Math.max(1, parseInt(m[2], 10))
}

// The effective complexity → model map: .workflow-overrides/model-map when
// present, the documented default otherwise. The escalation ladder is the
// map's distinct models ordered low → medium → high.
function parseModelMap(raw) {
  const map = { low: 'sonnet', medium: 'sonnet', high: 'opus' }
  if (raw) {
    for (const part of raw.split(',')) {
      const kv = part.trim().match(/^(low|medium|high)\s*=\s*([a-z][a-z0-9.-]*)$/i)
      if (kv) map[kv[1].toLowerCase()] = kv[2].toLowerCase()
    }
  }
  return map
}

// ---------------------------------------------------------------------------
// Preflight — one agent stands in for the skill's Step 0 (no fs/bash here).
// ---------------------------------------------------------------------------

phase('Preflight')
const pre = await agent(
  `You are the preflight gate for a domain-driven task-cycle run, working in the repo's working directory. Do not edit anything.
1. Locate the backlog helper: try \`.claude/skills/task-status/tasks.sh\`, then \`~/.claude/skills/task-status/tasks.sh\` (expand ~). tasksSh = the first existing path, else null.
2. baseBranch = \`git branch --show-current\` (plain form — never \`git -C\`).
3. Run \`bash <tasksSh> check-dag\`. dagOk = exit 0; on failure put its output in dagDetail.
4. modelMapRaw = contents of \`.workflow-overrides/model-map\` if that file exists, else null.
5. inProgress = space-separated ids from \`bash <tasksSh> by-status "in progress"\` (stale claims from a crashed run), "" if none.
Return the structured result only.`,
  { label: 'preflight', phase: 'Preflight', agentType: 'general-purpose', schema: PREFLIGHT_SCHEMA },
)

if (!pre) throw new Error('Preflight agent failed.')
if (!pre.tasksSh) throw new Error('tasks.sh not found under .claude/skills/task-status/ or ~/.claude/skills/task-status/ — is the domain-driven workflow installed here?')
if (!pre.dagOk) throw new Error(`check-dag failed — backlog unschedulable until /task-refine fixes it:\n${pre.dagDetail}`)

const tasksSh = pre.tasksSh
const baseBranch = pre.baseBranch
const modelMap = parseModelMap(pre.modelMapRaw)
const ladder = [...new Set([modelMap.low, modelMap.medium, modelMap.high])]
log(`Model map: low=${modelMap.low}, medium=${modelMap.medium}, high=${modelMap.high}${pre.modelMapRaw ? ' (project override)' : ' (default)'} · base branch: ${baseBranch}`)
if (pre.inProgress) log(`⚠ Stale \`in progress\` claims left by a previous run: ${pre.inProgress} — not touching them; reset to todo by hand (or via /task-cycle) to include them.`)

// ---------------------------------------------------------------------------
// The scheduling loop. Sequential passes; parallel workers within a pass.
// `excluded` guards against infinite loops in `all` mode: a task that failed
// (post-escalation) or bounced twice this run is left in todo for a later run.
// ---------------------------------------------------------------------------

const completed = [] // { id, commit, escalated }
const skipped = []   // { id, reason } — excluded or dirty-file tasks, reported at the end
const bounceCount = {}
const excluded = new Set()
let stall = null
let finalBoard = ''
let pass = 0

while (true) {
  if (limit != null && completed.length >= limit) {
    log(`Reached limit (${limit}) — stopping.`)
    break
  }

  pass += 1
  const P = `Pass ${pass}`

  // --- Gate: re-derive the ready-set from disk (resumable/idempotent) -------
  const gate = await agent(
    `You are the per-pass gate for a domain-driven task-cycle run. The backlog helper is at: ${tasksSh}. Do not edit anything.
1. Run \`bash ${tasksSh} ready\` → the ready ids, ascending.
2. For EACH ready id, run \`bash ${tasksSh} get <id>\` and report: id, file (the _file field), complexity (frontmatter complexity, "" if unset).
3. For each ready task file, dirty = true iff \`git status --porcelain -- <file>\` is non-empty (the human may be mid-edit; plain git — never \`git -C\`).
4. todoCount = count of ids from \`bash ${tasksSh} by-status todo\`.
5. If ready is empty but todoCount > 0, build stallDetail: for each todo id, \`bash ${tasksSh} blockers <id>\` → "NNNN blocked on: …" lines.
6. board = \`bash ${tasksSh} board\` verbatim.
Return the structured result only.`,
    { label: `gate:${pass}`, phase: `${P} · Gate`, agentType: 'general-purpose', schema: GATE_SCHEMA },
  )
  if (!gate) throw new Error(`Gate agent failed on pass ${pass}.`)
  finalBoard = gate.board

  const dispatchable = gate.ready.filter(t => {
    if (excluded.has(t.id)) return false
    if (t.dirty) {
      if (!skipped.some(s => s.id === t.id)) skipped.push({ id: t.id, reason: 'task file has uncommitted edits in the main checkout' })
      return false
    }
    return true
  })

  if (dispatchable.length === 0) {
    if (gate.ready.length === 0 && gate.todoCount > 0) stall = gate.stallDetail || `${gate.todoCount} todo task(s) blocked on unmet dependencies.`
    break // drained, stalled, or everything left is excluded/dirty — reported below
  }

  const remaining = limit == null ? Infinity : limit - completed.length
  const batch = dispatchable.slice(0, Math.min(workers, remaining))
  log(`▶ ${P}: dispatching ${batch.map(t => t.id).join(', ')} (${gate.ready.length} ready)`)

  // --- Claim: scribe flips todo → in progress and creates worktrees ---------
  // Claim commits land BEFORE the worktrees branch off, so every worker sees
  // its task as claimed. Pathspec commits only — the human's other uncommitted
  // files must never be swept up.
  const claim = await agent(
    `You are the claiming scribe for a domain-driven task-cycle run, working in the repo's working directory. You are the ONLY writer of task files. For each of these tasks, in order:
${batch.map(t => `- id ${t.id}, file ${t.file}`).join('\n')}
1. Edit ONLY the frontmatter line \`status: todo\` → \`status: in progress\` in that file.
2. Commit ONLY that file with an explicit pathspec: \`git commit -m "chore(tasks): claim <id> for task-cycle-run" -- <file>\` (plain git — never \`git -C\`, never \`git add\`, never a bare \`git commit\`).
3. Create its worktree: \`git worktree add ../.dd-worktrees/task-<id> -b task/<id>\`.
Report each successfully claimed task with its branch and the worktree's ABSOLUTE path. If a step fails for a task, undo what you did for that task (restore the file, remove a half-made worktree) and list it in failed instead. Touch nothing else.`,
    { label: `claim:${pass}`, phase: `${P} · Claim`, agentType: 'general-purpose', schema: CLAIM_SCHEMA },
  )
  if (!claim || claim.claimed.length === 0) {
    throw new Error(`Claiming scribe failed on pass ${pass}${claim && claim.failed ? `: ${claim.failed}` : ''}.`)
  }
  if (claim.failed) log(`⚠ Could not claim: ${claim.failed}`)

  // --- Implement: one task-worker per claimed task, in parallel -------------
  // Tasks in one ready-batch never depend on each other, so order is free.
  // Model per the task's complexity; one escalation retry at the next tier up
  // on a worker FAILURE (never on a merge bounce).
  const results = await parallel(
    claim.claimed.map(c => async () => {
      const t = batch.find(b => b.id === c.id)
      const tier = ['low', 'medium', 'high'].includes(t.complexity) ? t.complexity : 'medium'
      const model = modelMap[tier]
      const prompt = `Your working directory is the git worktree at: ${c.worktree} — work there and nowhere else.
The task to implement is ${t.file} (relative to that worktree), already claimed \`in progress\` for you.
Run your standard contract: read the task fully (including related_documents and related_adrs), implement with strict TDD, verify, commit via Skill(commit) on the current branch (${c.branch}), and return the structured report. Never edit the task file itself — the orchestrator writes status and closing records. Halt with result "failed" instead of asking questions, leaving the worktree clean.`

      let report = await agent(prompt, {
        label: `task-worker:${c.id}`, phase: `${P} · Implement`,
        agentType: 'task-worker', model, schema: WORKER_SCHEMA,
      })
      let escalated = null
      if ((!report || report.result === 'failed') && ladder.indexOf(model) < ladder.length - 1) {
        const next = ladder[ladder.indexOf(model) + 1]
        log(`↗ ${c.id} failed at ${model} — one escalation retry at ${next}`)
        report = await agent(prompt, {
          label: `task-worker:${c.id}@${next}`, phase: `${P} · Implement`,
          agentType: 'task-worker', model: next, schema: WORKER_SCHEMA,
        })
        if (report && report.result === 'ok') escalated = `${model} → ${next}`
      }
      return { id: c.id, branch: c.branch, worktree: c.worktree, file: t.file, report, escalated }
    }),
  )

  const ok = results.filter(r => r && r.report && r.report.result === 'ok')
  const failed = results.filter(r => r && (!r.report || r.report.result === 'failed'))

  // --- Integrate: serial merge-back onto base, bounce-on-conflict -----------
  let integrated = [], bounced = []
  if (ok.length > 0) {
    const integ = await agent(
      `Base branch: ${baseBranch}. You are working in the repo's main checkout.
Completed task branches to integrate, in order:
${ok.map(r => `- task ${r.id}, branch ${r.branch}, worktree ${r.worktree}`).join('\n')}
Run your standard contract: merge each onto ${baseBranch} one at a time (\`git merge --no-ff --no-edit <branch>\`), abort-and-bounce on any conflict, never resolve one. Do not delete worktrees or branches. Return the structured report.`,
      { label: `integrate:${pass}`, phase: `${P} · Integrate`, agentType: 'integrator', schema: INTEGRATE_SCHEMA },
    )
    if (!integ) throw new Error(`Integrator failed on pass ${pass} — worktrees ${ok.map(r => r.worktree).join(', ')} left in place for inspection.`)
    integrated = integ.integrated
    bounced = integ.bounced
  }

  for (const b of bounced) {
    bounceCount[b.id] = (bounceCount[b.id] || 0) + 1
    if (bounceCount[b.id] >= 2) {
      excluded.add(b.id)
      skipped.push({ id: b.id, reason: `bounced ${bounceCount[b.id]}× on merge conflicts (${b.paths}) — left in todo for a later run` })
    }
  }
  for (const f of failed) {
    excluded.add(f.id)
    skipped.push({ id: f.id, reason: `worker failed${f.escalated === null && ladder.length > 1 ? ' (incl. escalation retry)' : ''}: ${f.report ? f.report.summary : 'worker returned nothing'}` })
  }

  // --- Record: scribe writes the outcomes back into the task files ----------
  const landed = ok.filter(r => integrated.includes(r.id))
  const toReset = [
    ...ok.filter(r => !integrated.includes(r.id)).map(r => ({ ...r, why: `merge bounced on: ${(bounced.find(b => b.id === r.id) || {}).paths || '?'}` })),
    ...failed.map(r => ({ ...r, why: `worker failed: ${r.report ? r.report.summary : 'worker returned nothing'}` })),
  ]

  const rec = await agent(
    `You are the recording scribe for a domain-driven task-cycle run, working in the repo's main checkout on branch ${baseBranch}. You are the ONLY writer of task files. The backlog helper is at: ${tasksSh}.

COMPLETED tasks — for each, in its task file:
${landed.length ? landed.map(r => `--- task ${r.id} (${r.file}), code already merged, worker commit ${r.report.commit}${r.escalated ? `, escalated ${r.escalated}` : ''} ---
MANUAL_TESTING block (write verbatim into the \`### Manual testing\` subsection under \`## Closing\`, replacing its placeholder):
${r.report.manualTesting}
MANUAL_TESTING END. DEVIATIONS block (write verbatim into \`### Deviations from plan\`, replacing its placeholder):
${r.report.deviations}
DEVIATIONS END.`).join('\n') : '(none this pass)'}
For each completed task: set frontmatter \`status: done\` and \`completed: <output of date -u +%Y-%m-%dT%H:%M:%SZ>\`; write the two blocks as given; if its DEVIATIONS block is non-trivial (anything beyond "none"/"as planned"), also set \`deviated: true\` in the frontmatter; if it was escalated, append a line \`escalated: <from> → <to> on failure\` to its \`## Notes\`.

RESET tasks — for each, set frontmatter \`status: in progress\` back to \`status: todo\` and append the reason to its \`## Notes\`:
${toReset.length ? toReset.map(r => `- task ${r.id} (${r.file}): ${r.why}`).join('\n') : '(none this pass)'}

Commit EACH task file separately with an explicit pathspec: \`git commit -m "chore(tasks): <done|reset> NNNN" -- <file>\` (plain git — never \`git -C\`, never \`git add\`, never a bare \`git commit\` — the human may have unrelated uncommitted work).

Then clean up every handled task's worktree and branch: \`git worktree remove ../.dd-worktrees/task-NNNN --force && git branch -D task/NNNN\` for:
${[...landed, ...toReset].map(r => r.id).join(', ') || '(none)'}

Finally report board = \`bash ${tasksSh} board\`. Touch nothing beyond the listed task files and worktrees.`,
    { label: `record:${pass}`, phase: `${P} · Record`, agentType: 'general-purpose', schema: RECORD_SCHEMA },
  )
  if (!rec) throw new Error(`Recording scribe failed on pass ${pass} — task statuses may be inconsistent; inspect with tasks.sh board.`)
  if (rec.notes) log(`⚠ record:${pass}: ${rec.notes}`)
  finalBoard = rec.board

  for (const r of landed) completed.push({ id: r.id, commit: r.report.commit, escalated: r.escalated })
  log(`✓ ${P}: ${landed.length ? `landed ${landed.map(r => r.id).join(', ')}` : 'nothing landed'}${toReset.length ? ` · reset ${toReset.map(r => r.id).join(', ')}` : ''} · ${rec.board}`)
}

// ---------------------------------------------------------------------------
// Final tally — returned to the invoking session, which relays it.
// ---------------------------------------------------------------------------

return {
  tasksCompleted: completed.length,
  completed,
  skipped,          // failed / repeatedly-bounced / dirty-file tasks left in todo, with reasons
  stalled: stall != null,
  stallDetail: stall,
  staleInProgress: pre.inProgress || null,
  board: finalBoard,
}
