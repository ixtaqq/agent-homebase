# Conventions for editing agent-homebase

This repo is the source of truth for the Claude Code setup.
`~/.claude/skills/<name>` are junctions pointing back here.

## Rules

- Never edit anything under `~/.claude/skills/` directly — edit here instead, then run `sync.ps1`
  and `doctor.ps1` when a change is structural.
- Every skill folder needs `SKILL.md` with YAML frontmatter containing `name` and `description`.
  `name` must equal the folder name. `description` is the trigger — write it as *when to use this*,
  since it is the only body text Claude reads before deciding.
- Keep `global/AGENTS.md` short. It is loaded into every session; every line costs context.
- PowerShell scripts target Windows PowerShell 5.1. No `&&`, no ternary, no `??`.
- **Keep `.ps1` files ASCII-only.** They have no BOM, so PowerShell 5.1 decodes them as
  Windows-1252 — an em dash becomes a smart quote that the parser accepts as a string delimiter, and
  the whole script fails to parse. Use `--` and `-` in scripts; markdown is unaffected.
- Scripts must be idempotent and support `-DryRun` where they mutate anything outside this repo.
- `logs/` is generated output — never commit it.
- **Never edit anything under `vendor/`.** It is upstream code; edits are lost on the next pull. To
  customize a vendored skill, copy the folder into `skills/`.

## After changing things

| Changed | Do this |
| --- | --- |
| a skill's `SKILL.md` | nothing — junction is live, open a new thread |
| a new skill folder | `powershell -NoProfile -File scripts/sync.ps1` |
| `vendor/enabled.txt` | `powershell -NoProfile -File scripts/sync.ps1 -Force` (`-Force` to unlink disabled ones) |
| `global/AGENTS.md` | nothing — `~/.claude/CLAUDE.md` imports it live |
| `global/CLAUDE.md`, roles, or commands | `powershell -NoProfile -File scripts/sync.ps1` (they are copied, not linked) |
| anything structural | `powershell -NoProfile -File scripts/doctor.ps1` |

New Claude sessions run `sync.ps1` automatically through a `SessionStart` hook, so the sync rows
above also happen on their own the next time a session starts.

For sync changes, run `node scripts/tests/sync.test.js` and
`powershell -NoProfile -File scripts/validate.ps1`. The integration test uses an isolated home,
checks dry runs, idempotence, drift, and conflict preservation, and retains its fixtures.
