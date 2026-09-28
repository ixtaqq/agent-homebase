---
name: codex-os-wiring
description: why Codex and Claude share curated skill junctions and one durable memory store
type: decision
created: 2026-07-27
---

`~/.codex/skills/<name>` are Windows directory junctions pointing into
`E:\Workspace\codex-os\skills\<name>`. `global/AGENTS.md` is the one exception — it is copied to
`~/.codex/AGENTS.md` by `scripts/sync.ps1`, because a single file cannot be junctioned.

**Why:** junctions make edits live — change a `SKILL.md` and the next thread sees it, with no
reinstall step. Copies drift silently. The plugin path (`.codex-plugin/plugin.json` +
`~/.agents/plugins/marketplace.json`) is the official distribution mechanism but requires a
cachebuster bump and reinstall on every edit, which is the wrong trade for a repo edited daily.
Junctions work across volumes (E: to C:) without admin rights, unlike symlinks and hardlinks.

The plugin manifest exists in the repo but is deliberately **not registered** in any marketplace.
Registering it while the junctions exist would load every skill twice.

**Updated 2026-09-28:** The user asked for the best setup that also works in Claude Code.
Keep codex-os as the common source, share its selected skills through both tools' personal
skill directories, and use the existing `memory/` and `knowledge/` for context intended to cross tools.
Claude imports the shared defaults through a small `CLAUDE.md` adapter. Its read-only roles and
prefixed prompt commands are copied by the same sync script with `-Target all`.

**Why this choice:** retain the user's existing personal conventions and selected ECC workflows
without introducing a second competing memory store or a duplicate full ECC installation.
Headless loops remain Codex-backed; ordinary in-session workflows use the current tool.

**Applies to:** Codex and Claude Code on this machine. See [[loop-status-contract]].
