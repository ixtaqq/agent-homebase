# Agent Homebase tasks

## Current phase: Validation and portability boundary

- [x] Add repository specification and acceptance criteria.
- [x] Add roadmap and phase exit criteria.
- [x] Add structural repository validator.
- [x] Add regression coverage for loop session selection and sync overwrite safety.
- [x] Vendor ECC and enable a curated set of Codex-compatible skills.
- [x] Port three read-only ECC agent roles into the managed Codex config.
- [x] Leave ECC Claude-only hooks and unattended PR automation disabled.
- [x] Share curated skill sources and memory with Claude Code using `-Target all`.
- [x] Add Claude guidance, project import template, read-only roles, and prefixed commands.
- [x] Restore two retired vendor skills as pinned local copies with licenses and provenance.
- [x] Verify both installed profiles and seven isolated sync integration checks.
- [x] Remove Codex: Claude-only sync, doctor, and validation; `loop.ps1` ported to `claude -p`.
- [ ] Run one live `loop.ps1` pass after installing the Claude Code CLI on PATH.
- [x] Enable writing-for-agents and verify both installed profiles.
- [x] Add pinned PowerShell analysis and secret scanning with negative regression cases.
- [ ] Confirm the new Windows CI workflow passes on GitHub (workflow prepared locally).
- [ ] Run the prepared skill evaluations with an approved model-usage budget.

## Completion rule

Only mark a task complete after the relevant command has run successfully and
its result is recorded in the handoff.
