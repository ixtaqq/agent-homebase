@E:/Workspace/agent-homebase/global/AGENTS.md

# Claude Code integration

- Shared skills, durable facts, and knowledge live in `E:\Workspace\agent-homebase`.
  Use `memory-keeper` for durable facts and `retrieve-knowledge` for longer notes.
- Edit skill sources in that repository. The personal skill directories are managed
  junctions, and a `SessionStart` hook runs `scripts/sync.ps1` so new skills link on their own.
- Claude's Bash tool uses Git Bash on Windows. Run PowerShell scripts through
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:/Workspace/agent-homebase/scripts/<script>.ps1`.
  Do not send PowerShell syntax directly to Bash.
- Use the current session for ordinary work. The separate headless `loop.ps1` runner
  launches `claude -p` and needs the Claude Code CLI installed.
- When bootstrapping a project, keep its conventions in `AGENTS.md` and import them
  with `@AGENTS.md` in the project's `CLAUDE.md`.
- Shared commands are `/os-review`, `/os-debug`, and `/os-ship-it`.
