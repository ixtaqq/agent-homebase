---
name: agent-homebase-wiring
description: why Codex and Claude share curated skill junctions and one durable memory store
type: decision
created: 2026-07-27
---

`~/.codex/skills/<name>` are Windows directory junctions pointing into
`E:\Workspace\agent-homebase\skills\<name>`. `global/AGENTS.md` is the one exception — it is copied to
`~/.codex/AGENTS.md` by `scripts/sync.ps1`, because a single file cannot be junctioned.

**Why:** junctions make edits live — change a `SKILL.md` and the next thread sees it, with no
reinstall step. Copies drift silently. The plugin path (`.codex-plugin/plugin.json` +
`~/.agents/plugins/marketplace.json`) is the official distribution mechanism but requires a
cachebuster bump and reinstall on every edit, which is the wrong trade for a repo edited daily.
Junctions work across volumes (E: to C:) without admin rights, unlike symlinks and hardlinks.

The plugin manifest exists in the repo but is deliberately **not registered** in any marketplace.
Registering it while the junctions exist would load every skill twice.

**Updated 2026-09-28:** The user asked for the best setup that also works in Claude Code.
Keep agent-homebase as the common source, share its selected skills through both tools' personal
skill directories, and use the existing `memory/` and `knowledge/` for context intended to cross tools.
Claude imports the shared defaults through a small `CLAUDE.md` adapter. Its read-only roles and
prefixed prompt commands are copied by the same sync script with `-Target all`.

**Why this choice:** retain the user's existing personal conventions and selected ECC workflows
without introducing a second competing memory store or a duplicate full ECC installation.
Headless loops remain Codex-backed; ordinary in-session workflows use the current tool.

**Applies to:** Codex and Claude Code on this machine. See [[constrained-language-in-loops]]; the loop status contract is
documented in `loops/_schema.md`.

**Updated 2026-11-01:** The user wanted every project to pick up changes here automatically.
A user-level `SessionStart` hook in `~/.claude/settings.json` (matcher `startup`) runs
`sync.ps1` silently on every new Claude session, logging to `logs/session-sync.log`
(UTF-16). It never passes `-Force`, so drift is reported in the log rather than overwritten.
The hook is hand-installed; `sync.ps1` still never edits hooks.

**Codex removed 2026-11-01:** The user cancelled their Codex subscription and asked for it to be
removed. `~/.codex` was deleted (junctions unlinked first; sources untouched). sync, doctor, and
projects-doctor lost `-Target` and the Codex trust check; `codex-home/`, `.codex-plugin/`, and the
project `.codex/config.toml` template were deleted. `loop.ps1` was ported to `claude -p` with
`--session-id`/`--resume`, `--json-schema`, and loop `permission_mode`/`allowed_tools` replacing
`sandbox`. It starts the CLI through `System.Diagnostics.Process` because PowerShell 5.1 splits
JSON arguments at their spaces, and it pipes the prompt on stdin because a multi-line argument does
not survive a `claude.cmd` shim. The Junction/plugin reasoning above is history for the Codex side.

**Renamed 2026-09-28:** The user chose `agent-homebase` for the local directory,
GitHub repository, and shared setup. The same junction and memory design continues
at `E:\Workspace\agent-homebase`.
