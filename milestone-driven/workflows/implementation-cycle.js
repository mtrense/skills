export const meta = {
  name: 'implementation-cycle',
  description: 'Drive PLAN.md to completion — one task-worker + doc-updater subagent per task, sequentially, with independent git/PLAN.md verification between iterations',
  whenToUse: 'Burn down PLAN.md tasks unattended, keeping the main session lean',
  model: 'sonnet',
  phases: [
    { title: 'Gate', detail: 'preflight clean-tree check + pick next [ ] task' },
    { title: 'Implement', detail: 'task-worker: task-implementation + commit' },
    { title: 'Verify', detail: 'independent post-flight: PLAN moved, tree clean, hash matches' },
    { title: 'Docs', detail: 'doc-updater: sync reference docs/examples if surface-visible' },
  ],
}

// ---------------------------------------------------------------------------
// Structured-output schemas. These REPLACE the prose "```report``` block that
// the orchestrator parses" — validation happens at the tool-call layer, so the
// model retries on mismatch and agent() returns a validated object. No parsing.
// ---------------------------------------------------------------------------

// The gate agent stands in for the parts of the skill the script itself cannot
// do: a workflow script has NO filesystem and NO bash. So `git status
// --porcelain` and reading PLAN.md become an agent() call that returns state.
const GATE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['treeClean', 'nextTaskTitle', 'remaining'],
  properties: {
    treeClean: { type: 'boolean', description: 'true iff `git status --porcelain` is empty' },
    dirtyDetail: { type: 'string', description: 'porcelain output if dirty, else ""' },
    nextTaskTitle: {
      type: ['string', 'null'],
      description: 'title of the first `[ ]` task in PLAN.md, or null if none remain',
    },
    remaining: { type: 'integer', description: 'count of `[ ]` tasks in PLAN.md' },
  },
}

// task-worker's success/HALTED report block, as a schema.
const WORKER_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['status'],
  properties: {
    status: { type: 'string', enum: ['success', 'halted'] },
    tests: { type: 'string', description: 'e.g. "42 passing, 0 failing"' },
    commitHash: { type: 'string', description: '7-40 hex chars, real commit; required on success' },
    commitSubject: { type: 'string' },
    remaining: { type: 'integer' },
    notes: { type: 'string' },
    haltReason: { type: 'string', description: 'verbatim reason + on-disk state; required when halted' },
  },
}

// Independent post-flight. The skill is emphatic: "The subagent's self-report is
// a hint, not the ground truth." So a FRESH agent re-reads git + PLAN.md and
// confirms the worker's claims rather than trusting WORKER_SCHEMA's return.
const VERIFY_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['ok', 'planMoved', 'treeClean', 'hashMatches'],
  properties: {
    ok: { type: 'boolean', description: 'true iff all three checks below pass' },
    planMoved: { type: 'boolean', description: 'sent-in task is now [x] (or [~] if legitimately postponed)' },
    treeClean: { type: 'boolean', description: '`git status --porcelain` empty' },
    hashMatches: { type: 'boolean', description: '`git log -1 --format=%H` prefix-matches the claimed hash' },
    reason: { type: 'string', description: 'which check failed and how, else ""' },
  },
}

// doc-updater's three report variants.
const DOC_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['outcome'],
  properties: {
    outcome: { type: 'string', enum: ['UPDATED', 'NO-CHANGES', 'HALTED'] },
    files: { type: 'string', description: 'comma-separated doc/example files, if UPDATED' },
    commitHash: { type: 'string', description: 'docs(...) commit hash, if UPDATED' },
    commitSubject: { type: 'string' },
    reason: { type: 'string', description: 'why NO-CHANGES / HALTED' },
    notes: { type: 'string' },
  },
}

// ---------------------------------------------------------------------------
// The loop. Sequential by construction — no parallel()/pipeline(). Tasks depend
// on each other; concurrency would scramble PLAN.md and the git index.
// ---------------------------------------------------------------------------

// args is the skill's `[max-tasks]` argument (integer) or undefined/null.
const cap = Number.isInteger(args) && args > 0 ? args : null

const completed = [] // { title, commit, subject, docs }
let haltReason = null
let n = 0

while (true) {
  // --- Step 1+2: pre-flight clean check + pick next task -------------------
  // This single gate also serves as the PREVIOUS iteration's post-doc
  // clean-tree check: we always re-enter the gate before exiting on "no task
  // left", so a dirty tree left by the last doc-updater is caught here too.
  phase(`Task ${n + 1} · Gate`)
  const gate = await agent(
    `You are the pre-flight gate for an implementation cycle over PLAN.md, run in the repo's working directory.
1. Run \`git status --porcelain\` (plain form — never \`git -C\`). Report treeClean=true iff output is empty; put the output in dirtyDetail if not.
2. Read PLAN.md. nextTaskTitle = the title of the FIRST task whose checkbox is \`[ ]\` (verbatim, no checkbox), or null if none remain. remaining = count of \`[ ]\` tasks.
Do not edit anything. Do not run tests. Return the structured result only.`,
    { label: `gate:${n + 1}`, phase: `Task ${n + 1} · Gate`, agentType: 'general-purpose', schema: GATE_SCHEMA },
  )

  if (!gate || !gate.treeClean) {
    haltReason = `Working tree dirty at pre-flight: ${gate ? gate.dirtyDetail || '(no detail)' : 'gate agent failed'}`
    break
  }
  if (gate.nextTaskTitle == null) {
    log(`No [ ] tasks remain — clean exit.`)
    break // success path
  }
  if (cap != null && n >= cap) {
    log(`Reached max-tasks cap (${cap}) — stopping.`)
    break
  }

  n += 1
  const title = gate.nextTaskTitle
  log(`▶ Task ${n}${cap ? `/${cap}` : ''}: ${title}  (${gate.remaining} remaining)`)

  // --- Step 3: spawn the task-worker (real custom agent) ------------------
  phase(`Task ${n} · Implement`)
  const report = await agent(
    `The next [ ] task in PLAN.md is: "${title}"

Run your standard contract: invoke \`task-implementation\`, then \`commit\`, then
report. Halt instead of asking questions — the orchestrator will surface anything
you halt on. Return the structured report (status "success" with a real commitHash,
or "halted" with haltReason).`,
    { label: `task-worker:${n}`, phase: `Task ${n} · Implement`, agentType: 'task-worker', schema: WORKER_SCHEMA },
  )

  if (!report) {
    haltReason = `task-worker for "${title}" returned nothing (subagent died / omitted required output).`
    break
  }
  if (report.status === 'halted') {
    haltReason = `task-worker HALTED on "${title}": ${report.haltReason || '(no reason given)'}`
    break
  }
  if (!report.commitHash || !/^[0-9a-f]{7,40}$/.test(report.commitHash)) {
    haltReason = `task-worker for "${title}" reported success but no valid commit hash — commit step likely skipped.`
    break
  }

  // --- Step 4: independent post-flight verification -----------------------
  // Do NOT trust the worker's report. A fresh agent re-derives ground truth.
  phase(`Task ${n} · Verify`)
  const v = await agent(
    `Independently verify that a PLAN.md task landed correctly. Do not trust any prior report.
Task title: "${title}"
Claimed commit hash: ${report.commitHash}
Checks (all via plain git / reading PLAN.md — never \`git -C\`):
1. planMoved: re-read PLAN.md; the task above must now be \`[x]\` (or \`[~]\` if legitimately postponed). false if still \`[ ]\`.
2. treeClean: \`git status --porcelain\` must be empty.
3. hashMatches: \`git log -1 --format=%H\` must prefix-match the claimed hash.
ok = all three true. If any fail, set ok=false and explain in reason. Edit nothing.`,
    { label: `verify:${n}`, phase: `Task ${n} · Verify`, agentType: 'general-purpose', schema: VERIFY_SCHEMA },
  )

  if (!v || !v.ok) {
    haltReason = `Post-flight verification failed for "${title}": ${v ? v.reason || `planMoved=${v.planMoved} treeClean=${v.treeClean} hashMatches=${v.hashMatches}` : 'verify agent failed'}`
    break
  }

  // --- Step 4.5: sync documentation (non-fatal on halt) -------------------
  phase(`Task ${n} · Docs`)
  const doc = await agent(
    `The task just completed is: "${title}"
Its commit hash is: ${report.commitHash}

Run your standard contract: inspect that commit's diff, update reference docs and
examples ONLY if the change is surface-visible, commit them separately as docs(...),
and return your structured report. Default to NO-CHANGES for internal-only changes.
Leave the tree clean either way.`,
    { label: `doc-updater:${n}`, phase: `Task ${n} · Docs`, agentType: 'doc-updater', schema: DOC_SCHEMA },
  )

  // doc-updater HALTED is non-fatal: the code already landed. A dirty tree it
  // may have left is caught by the NEXT iteration's gate (Step 1) before any
  // further work — so no separate clean-check agent is needed here.
  const docNote =
    !doc ? 'docs: (worker returned nothing)'
    : doc.outcome === 'UPDATED' ? `docs: ${doc.commitHash || '?'} (${doc.files || ''})`
    : doc.outcome === 'HALTED' ? `docs: HALTED — ${doc.reason || ''} (non-fatal)`
    : 'docs: none'

  completed.push({
    title,
    commit: report.commitHash,
    subject: report.commitSubject || '',
    docs: doc && doc.outcome === 'UPDATED' ? doc.commitHash : null,
  })
  log(`✓ Task ${n} done — ${report.commitSubject || title} (${report.commitHash.slice(0, 7)}) · ${docNote}`)
}

// ---------------------------------------------------------------------------
// Step 5: final summary — returned to the orchestrating skill, which prints it.
// The workflow itself writes nothing to disk; all writes happened via subagents.
// ---------------------------------------------------------------------------
return {
  tasksCompleted: completed.length,
  completed,
  halted: haltReason != null,
  haltReason,
  // The wrapper skill re-reads PLAN.md to report remaining count + whether to
  // suggest /milestone-closing; the last gate's `remaining` is a close proxy.
}
