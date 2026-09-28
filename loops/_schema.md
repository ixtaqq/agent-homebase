# Loop definition format

One file per loop: `loops/<name>.loop.md`. Frontmatter configures the run; the body is the prompt
sent on the first pass. Run it with `scripts/loop.ps1 -Loop <name>`.

```markdown
---
name: repo-health              # required, matches the filename
cwd: C:\path\to\repo           # required in practice; defaults to the agent-homebase root
sandbox: workspace-write       # read-only | workspace-write | danger-full-access
model:                         # optional, defaults to your config.toml model
profile:                       # optional, layers $CODEX_HOME/<name>.config.toml
max_iterations: 5              # hard budget — the loop always stops here
interval_seconds: 0            # pause between passes; 0 for back-to-back
exit_when: <the observable condition that ends the loop>
# Optional story mode:
story_ledger: tasks/stories.json
verification_command: npm.cmd test
fresh_context_per_iteration: true
---

The prompt for pass one. Say what to do, and name the exact command that proves progress.
```

## Field notes

- **`exit_when`** is injected into every pass. It must be checkable by running something. "tests
  pass" is checkable; "the code is clean" is not — a loop with a vague exit condition burns its
  whole budget every time.
- **`sandbox`** — least permission that does the job. `read-only` for monitors and audits,
  `workspace-write` for anything that edits files. The runner refuses to bypass approvals.
- **`max_iterations`** is a hard stop, not a target. The loop ends early on `done` or `blocked`.
- **`interval_seconds`** matters for polling loops (a CI run, a deploy). Match it to how fast the
  thing you are watching actually changes — one 5-minute check beats five 1-minute checks.

## What each pass returns

Story mode is enabled by `story_ledger`. The runner selects one pending story by numeric priority,
forces a fresh Codex context, and owns status updates. `verification_command` is required and must
exit zero before the runner persists completion. The agent must not edit the ledger, commit, or
push. Start from `templates/story-ledger.json`; keep each story small and its acceptance criteria
observable. Do not use unattended story mode for deployment, billing, live trading, or secrets.

The runner passes `scripts/schemas/loop-status.schema.json` as `--output-schema`, so each pass ends
with:

```json
{ "status": "continue|done|blocked", "summary": "...", "next_action": "..." }
```

`done` and `blocked` stop the loop. Anything unparseable is treated as `blocked` — silence is not
progress.

## Output

`logs/<name>/<timestamp>/` holds `iter-N.json` (the status object), `pass-N.out` (full transcript),
`session-id.txt` (the session started by pass one), and `run.log` (the one-line-per-pass summary).

Runner exit codes: `0` done, `2` budget exhausted, `3` blocked, `1` runner error.
