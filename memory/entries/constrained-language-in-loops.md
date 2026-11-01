---
name: constrained-language-in-loops
description: RETIRED 2026-11-01 with Codex -- why scripts called from a Codex sandbox avoided -File and .NET type literals
type: constraint
created: 2026-07-27
---

**Retired 2026-11-01:** Codex was removed from this setup and `loop.ps1` now launches `claude -p`,
whose Bash tool is not in ConstrainedLanguage mode. The rule below no longer binds new scripts; it is
kept as history and in case Codex returns.

Codex executes sandboxed shell commands through a nested `powershell -Command "..."` whose outer
shell is in **ConstrainedLanguage** mode. Two consequences for any `.ps1` a loop or agent calls:

1. Invoke with the call operator — `& 'C:\path\script.ps1'`. Using `-File` across the language-mode
   boundary fails with *"Cannot dot-source this command because it was defined in a different
   language mode."*
2. The script itself must avoid .NET type literals and method calls (`[System.IO.Directory]::…`,
   `[IO.FileAttributes]`) and must not dot-source helper scripts. Cmdlets, `[pscustomobject]`,
   string methods, and property access are all fine.

**Why:** hit while smoke-testing the `repo-health` loop — the loop reported `blocked` twice before
the cause was clear. `scripts/doctor.ps1` was rewritten standalone to satisfy both rules and is the
working reference; `sync.ps1` and `loop.ps1` still dot-source `_common.ps1` because they only ever
run from a normal shell.

**Applies to:** any agent-homebase script meant to be called from inside a loop or agent session.
See [[agent-homebase-wiring]].
