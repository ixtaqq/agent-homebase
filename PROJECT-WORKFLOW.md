# Shared project workflow

For local projects using Agent Homebase on this machine.
Project instructions and the user's current request determine the task scope.

## Use the shared setup

- Skills are installed globally for Codex and Claude Code. Use the skills exposed
  by the current session; do not copy them into projects or assume a slash command exists.
- Read project and directory-specific instructions before changing files.
- Clarify only when missing information materially changes the implementation.
- Use relevant skills for planning, diagnosis, implementation, and review; skip
  steps that add no value to the task. A skill name is not a requirement to use it.
- Before calling work complete, use `ship-check` when available and run the
  project's own applicable checks. Agent Homebase's tests validate the shared
  tooling, not the application being changed.
- Use `memory-keeper` for durable cross-project decisions and `retrieve-knowledge`
  for relevant stored notes. Keep project conventions in that project's AGENTS.md.
- Preserve existing work. Follow the user's approval rules for destructive actions,
  paid calls, external communications, commits, and pushes.

## Keep it working

The source of truth is `E:\workspace\agent-homebase`.
Update shared skills there. Existing junctions expose edits to both tools;
open a fresh session to refresh skill discovery and project instructions.
When adding skills or changing global instructions, follow that repository's
AGENTS.md sync and doctor requirements.

For a new project, use `project-bootstrap` to inspect its stack and add verified
project instructions plus a CLAUDE.md import. Global skills are already available;
project-specific commands still need to be discovered and verified.
