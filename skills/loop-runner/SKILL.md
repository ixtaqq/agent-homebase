---
name: loop-runner
description: Run a task as an iterative loop that repeats until an explicit exit condition is met. Use when the work needs repeated passes rather than one shot — polling a build or deploy, grinding a test suite to green, sweeping a codebase file by file, monitoring something on an interval, or any request phrased as "keep going until", "every N minutes", "repeat until it passes". Also use when the user asks to schedule or inspect a headless loop defined in agent-homebase/loops/.
metadata:
  short-description: Iterate until an exit condition is met
---

# Loop Runner

Two modes. Pick by whether the loop must survive outside this thread.

| Mode | Use when | Mechanism |
| --- | --- | --- |
| In-thread | The user is present and the work fits one session | The protocol below |
| Headless | It runs unattended, on an interval, or scheduled | `scripts/loop.ps1` |

OS root: `E:\Workspace\agent-homebase`.

The in-thread protocol works in both Codex and Claude Code. Headless mode always launches
`codex exec`; Claude Code can invoke that runner when Codex execution is intended. Do not
describe the headless runner as a Claude backend or start a second CLI for ordinary in-thread work.

## In-thread protocol

Before pass 1, state three things in one short block and get them right — a loop with a vague exit
condition burns tokens forever:

- **Goal** — what must be true at the end.
- **Exit condition** — the observable check that ends the loop. Must be verifiable by running
  something, not by feeling done.
- **Budget** — max passes, and what to do when it runs out.

Then each pass:

1. Do exactly one increment of work.
2. Run the check.
3. Emit one status line: `pass N/M — status=continue|done|blocked — <what changed> — <next action>`.

Stop rules, in order:

- `done` — the exit condition verifiably holds. Say so and stop.
- `blocked` — the same failure repeated twice with no new information, a missing credential, or a
  decision only the user can make. Stop and report what is needed. Do not keep retrying a command
  that failed the same way twice.
- Budget exhausted — stop, summarize progress, state what remains.

Never silently extend the budget. Never report `done` without having run the check.

## Headless loops

Loop definitions live in `loops/*.loop.md` — frontmatter config plus a prompt body. Format is
documented in `loops/_schema.md`.

Run one:

```powershell
powershell -NoProfile -File E:\Workspace\agent-homebase\scripts\loop.ps1 -Loop repo-health
```

Useful flags: `-MaxIterations <n>` to override the file and `-DryRun` to print the exact `codex exec`
commands without running them.

The runner drives `codex exec` with `--output-schema scripts/schemas/loop-status.schema.json`, so
every pass returns `{status, summary, next_action}` as JSON. The runner reads `status` and stops on
`done`, `blocked`, or `max_iterations`. Per-pass output lands in
`logs/<loop>/<run-timestamp>/iter-N.json`, with a human log alongside it. It records the session ID
emitted by the first pass and resumes that exact session; it never uses a global last-session selector.

For multi-story implementation work, add `story_ledger` and `verification_command` to the loop
definition. Story mode selects one pending story per pass, forces a fresh Codex context, and marks
the story complete only after the runner's verification command exits zero. The model cannot mark
its own work complete, edit the ledger, commit, or push. Start from `templates/story-ledger.json`.

To schedule a loop:

```powershell
powershell -NoProfile -File E:\Workspace\agent-homebase\scripts\schedule-loop.ps1 -Loop repo-health -Daily 09:00
```

`-List` shows registered loops, `-Remove <loop>` unregisters one.

## Writing a new loop

Copy an existing `.loop.md`, then check three things:

- `cwd` points at a directory that exists.
- `exit_when` is checkable by a command, and the prompt body says which command.
- `sandbox` is the least permission the work needs — `read-only` for monitors, `workspace-write`
  for anything that edits files. Never bypass approvals.

Keep the prompt body outcome-shaped: what should be true when it ends, what evidence proves it.

In story mode, keep one small story per pass, write explicit acceptance criteria, and configure a
deterministic `verification_command`. Do not use it for deployment, billing, live trading, or secrets.

**Calling a `.ps1` from inside a loop:** use the call operator, not `-File`.

```powershell
& 'E:\Workspace\agent-homebase\scripts\doctor.ps1'
```

Codex runs sandboxed commands through a nested `powershell -Command`, and the outer shell is in
ConstrainedLanguage mode. `-File` across that boundary is treated as dot-sourcing and fails with
"Cannot dot-source this command because it was defined in a different language mode." Scripts a loop
calls must also avoid .NET type literals and method calls, which ConstrainedLanguage blocks —
`scripts/doctor.ps1` is written that way on purpose and is the working reference.
