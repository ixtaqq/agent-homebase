# Loop definition format

One file per loop: `loops/<name>.loop.md`. Frontmatter configures the run; the body is the prompt
sent on the first pass. Run it with `scripts/loop.ps1 -Loop <name>`.

```markdown
---
name: repo-health              # required, matches the filename
cwd: C:\path\to\repo           # required in practice; defaults to the agent-homebase root
permission_mode: acceptEdits   # plan | dontAsk | acceptEdits | auto | default
allowed_tools:                 # optional, passed to --allowedTools, e.g. Bash(npm test *)
model:                         # optional alias or model name; defaults to your Claude setting
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
- **`permission_mode`** — least permission that does the job. Nobody answers prompts in a headless
  run, so anything that would prompt is denied. `dontAsk` plus the exact commands in
  `allowed_tools` suits monitors and audits. `acceptEdits` writes files but still needs
  `allowed_tools` for most shell commands. `auto` has a classifier review each action. The runner
  refuses `bypassPermissions`.
- **`max_iterations`** is a hard stop, not a target. The loop ends early on `done` or `blocked`.
- **`interval_seconds`** matters for polling loops (a CI run, a deploy). Match it to how fast the
  thing you are watching actually changes — one 5-minute check beats five 1-minute checks.

## What each pass returns

Story mode is enabled by `story_ledger`. The runner selects one pending story by numeric priority,
forces a fresh Claude session, and owns status updates. `verification_command` is required and must
exit zero before the runner persists completion. The agent must not edit the ledger, commit, or
push. Start from `templates/story-ledger.json`; keep each story small and its acceptance criteria
observable. Do not use unattended story mode for deployment, billing, live trading, or secrets.

The runner passes `scripts/schemas/loop-status.schema.json` as `--json-schema` and reads the
`structured_output` field of `claude -p --output-format json`, so each pass ends with:

```json
{ "status": "continue|done|blocked", "summary": "...", "next_action": "..." }
```

`done` and `blocked` stop the loop. Anything unparseable is treated as `blocked` — silence is not
progress.

## Output

`logs/<name>/<timestamp>/` holds `iter-N.json` (the status object), `pass-N.out` (the CLI's JSON
result), `session-id.txt` (the session ID the runner gave pass one), and `run.log` (the
one-line-per-pass summary).

The runner needs the Claude Code CLI. It looks for `CLAUDE_EXE`, then `claude` on PATH, then
`~/.local/bin/claude.exe`.

Runner exit codes: `0` done, `2` budget exhausted, `3` blocked, `1` runner error.
