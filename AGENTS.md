# Conventions for editing agent-homebase

This repo is the source of truth for the shared Codex and Claude Code setup.
`~/.codex/skills/<name>` and `~/.claude/skills/<name>` are junctions pointing back here.

## Rules

- Never edit anything under `~/.codex/skills/` directly — edit here instead.
- Never touch `~/.codex/skills/.system/` (vendor-owned, overwritten on update).
- Never edit `~/.claude/skills/` directly either. Use `sync.ps1 -Target all` and
  `doctor.ps1 -Target all` when a change affects both tools. Default target remains Codex.
- Every skill folder needs `SKILL.md` with YAML frontmatter containing `name` and `description`.
  `name` must equal the folder name. `description` is the trigger — write it as *when to use this*,
  since it is the only body text Codex reads before deciding.
- Keep `global/AGENTS.md` short. It is loaded into every session; every line costs context.
- PowerShell scripts target Windows PowerShell 5.1. No `&&`, no ternary, no `??`.
- **Keep `.ps1` files ASCII-only.** They have no BOM, so PowerShell 5.1 decodes them as
  Windows-1252 — an em dash becomes a smart quote that the parser accepts as a string delimiter, and
  the whole script fails to parse. Use `--` and `-` in scripts; markdown is unaffected.
- Scripts callable from inside a loop must use the call operator (`& 'path.ps1'`) and avoid .NET
  type literals and dot-sourcing — see `memory/entries/constrained-language-in-loops.md`.
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
| `global/AGENTS.md` | `powershell -NoProfile -File scripts/sync.ps1` (it is copied, not linked) |
| anything structural | `powershell -NoProfile -File scripts/doctor.ps1` |

For shared sync changes, run `node scripts/tests/sync.test.js` and
`powershell -NoProfile -File scripts/validate.ps1`. The integration test uses isolated homes,
checks dry runs, idempotence, drift, and conflict preservation, and retains its fixtures.
