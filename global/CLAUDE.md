@E:/Workspace/codex-os/global/AGENTS.md

# Claude Code integration

- Shared skills, durable facts, and knowledge live in `E:\Workspace\codex-os`.
  Use `memory-keeper` for durable facts and `retrieve-knowledge` for longer notes.
- Edit skill sources in that repository, then run `scripts/sync.ps1 -Target all`
  after adding skills. The personal skill directories are managed junctions.
- Claude's Bash tool uses Git Bash on Windows. Run PowerShell scripts through
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:/Workspace/codex-os/scripts/<script>.ps1`.
  Do not send PowerShell syntax directly to Bash.
- Use the current agent for ordinary in-session work. The separate headless
  `loop.ps1` runner launches Codex CLI; it does not launch Claude.
- When bootstrapping a project for both tools, keep shared conventions in `AGENTS.md`
  and import them with `@AGENTS.md` in the project's `CLAUDE.md`.
- Shared commands are `/os-review`, `/os-debug`, and `/os-ship-it`.
