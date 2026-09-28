# Personal defaults

These apply to every repo unless a project's own `AGENTS.md` says otherwise.
Source of truth: `E:\Workspace\agent-homebase\global\AGENTS.md` — edit there, then run `scripts/sync.ps1`.

## Environment

- Windows 11, PowerShell 5.1 is the default shell. No `&&`, no ternary, no `??`.
  Chain with `;` or `A; if ($?) { B }`. Bash is available but is not the default.
- Use `New-Item -ItemType Directory -Force` instead of `mkdir -p`; never `New-Item -Force` on an
  existing file (it truncates).
- Prefer absolute paths in scripts. Quote paths containing spaces.

## Working style

- Act when the request is clear; ask only when two readings lead to materially different work.
- Deliver the whole scope. If part is blocked, finish the rest and say plainly what was skipped.
- Match the surrounding code's naming, comment density, and idiom. Do not add explanatory comments
  the file's own style wouldn't have.
- Prefer reusing an existing function over writing a parallel one. Search before adding.
- No defensive scaffolding that wasn't asked for: no speculative config flags, no unused abstraction
  layers, no try/catch that swallows errors.

## Verification bar

Before saying something works:

1. Run it — build, test, or execute the actual path that changed.
2. Report failures verbatim, including the command and its output.
3. If verification was skipped or impossible, say so explicitly instead of hedging.

Never claim a test passed without having seen it pass.

## Durable context

- Decisions worth remembering across sessions go in `E:\Workspace\agent-homebase\memory\entries\`,
  one fact per file, indexed in `memory/INDEX.md`. Use the `memory-keeper` skill.
- Repo-specific conventions belong in that repo's `AGENTS.md`, not here.

## Safety

- **Never delete a file without asking first.** This includes overwrites that destroy content,
  `Remove-Item -Recurse`, `git reset --hard`, force pushes, dropping tables, and cleaning up
  "temporary" files I did not ask you to remove. Propose it, name what it affects, wait for a yes.
- **Never take an action involving real money without asking first** — purchases, subscriptions,
  paid API calls, anything billable. Same rule: propose, state the cost, wait.
- Approval is per-action, not standing. One yes does not cover the next one.
- Never commit or push unless asked. Never `--no-verify`.
- Secrets stay out of the repo and out of command lines.
