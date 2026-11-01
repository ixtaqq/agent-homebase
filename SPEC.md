# Agent Homebase specification

## Purpose

Agent Homebase is a personal Windows-first operating layer for Claude Code: reusable skills,
explicit workflows, bounded loops, durable memory, and safe installation wiring.

## Required behavior

- Keep this repository as the source of truth for skills, global guidance, loops,
  commands, templates, and memory.
- Keep agent runtime state, credentials, sessions, caches, and logs out of Git.
- Make installation idempotent and previewable before changing `~/.claude`.
- Never silently overwrite a changed installed global guidance file.
- Give loops explicit exit conditions, budgets, and resumable session identity.
- Validate skill metadata, loop definitions, vendor selections, and repository shape.
- Preserve project-specific instructions instead of replacing them with global defaults.
- Treat vendored upstream skills as reviewable dependencies; enable only selected skills whose
  harness assumptions match the current tool or clearly identify required integrations.
- Link skill sources and copy guidance, commands, and read-only agent roles into Claude Code.

## Boundaries

This repository targets Windows PowerShell 5.1 and Claude Code installations that use
`~/.claude`. Cross-platform support is a future portability concern, not a reason
to weaken the current Windows wiring. Codex support was removed on 1 November 2026.

It does not manage credentials, session history, runtime databases, downloaded
plugin state, or third-party source contents under `vendor/`.

Headless loops use the Claude Code CLI (`claude -p`). Authentication and live model execution are
separate from installation checks.

## Acceptance criteria

- `scripts/validate.ps1` exits 0 on a structurally healthy checkout.
- `scripts/doctor.ps1` reports the installed profile as healthy.
- `node scripts/tests/sync.test.js` verifies dry runs, repeat installation, and user-file preservation.
- Sync and loop dry-runs make no changes and show their planned actions.
- Pester regression tests pass when Pester is available.
- Every skill has valid frontmatter whose `name` matches its directory.
