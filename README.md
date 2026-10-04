# agent-homebase

A personal operating system for Codex and Claude Code, as a folder. Skills, standards, templates,
and memory live here; both tools point back at them so projects share one maintained setup.

The [frontend and writing workflow](WORKFLOW-SETUP.md) adds 18 local adapters, a pinned offline
prose linter, and a 20-case experiment recorder. Upstream sources stay untouched; the adapters
replace provider-specific tools and automatic external actions with this setup's rules.

## How it is wired

`scripts/sync.ps1 -Target all` creates Windows **directory junctions** at
`~/.codex/skills/<name>` and `~/.claude/skills/<name>` for local and enabled vendor skills.
Edit a source `SKILL.md` here and new sessions in both tools see it, with no reinstall.
Codex's global `AGENTS.md` is copied. Claude's global `CLAUDE.md` is a small adapter that imports
the shared `global/AGENTS.md`. Agent roles and Claude commands are copied; re-run sync after editing them.

Use `-Target codex`, `-Target claude`, or `-Target all` for sync and doctor. The default is
`codex` for compatibility with existing loops. `CODEX_HOME` and `CLAUDE_CONFIG_DIR` override
the corresponding configuration directories. Sync never changes credentials, model settings,
workspace trust, hooks, or plugin registrations.

## Setup and checks

Restore missing vendor repositories at the revisions in `vendor-lock.json` before syncing a fresh
checkout:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap-vendor.ps1 -DryRun
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap-vendor.ps1
```

Existing vendor folders are never changed. `-Check` verifies their origin, revision, and clean
working tree; drift must be reviewed explicitly. The lock records the installed revisions, not an
upstream security audit. `-Destination` supports restoring into a separate directory for review.

Wire everything up (idempotent, safe to re-run):

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Workspace\agent-homebase\scripts\sync.ps1 -Target all
```

Check the wiring:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Workspace\agent-homebase\scripts\doctor.ps1 -Target all
```

Validate the repository itself:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Workspace\agent-homebase\scripts\validate.ps1
```

Run a loop:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Workspace\agent-homebase\scripts\loop.ps1 -Loop repo-health
```

`sync.ps1` takes `-DryRun` and `-Force`. `loop.ps1` takes `-DryRun`, `-MaxIterations`, and
`-IntervalSeconds`. Each loop run records its Codex session ID and resumes that exact session on
later passes, so concurrent Codex work cannot be picked up by accident.

Optional story-ledger mode uses one fresh context per story and requires an independent verification
command before persisting completion. See `loops/_schema.md` and `templates/story-ledger.json`.

## Using Claude Code

Claude Code discovers the same skill sources through `~/.claude/skills`. Use `/memory-keeper`,
`/retrieve-knowledge`, `/project-bootstrap`, or `/ship-check`, or describe the task naturally.
The shared prompt commands are `/os-review`, `/os-debug`, and `/os-ship-it`. Three read-only roles
are installed as `os-explorer`, `os-reviewer`, and `os-docs-researcher`.

Start a new Claude Code session after syncing. If `claude auth status` reports `loggedIn: false`,
run `claude auth login` yourself. A structural doctor check does not verify authentication or a
live model response. In Claude, `/memory` shows loaded instruction files; type `/` to browse commands.

Use `AGENTS.md` for shared project conventions and import it from a project `CLAUDE.md` with
`@AGENTS.md`; the bootstrap skill and template support this. Both tools use this repository's
`memory/` and `knowledge/`. Keep that as the canonical store for facts intended to be shared.

The in-session loop workflow works in either tool. The separate PowerShell headless loop runner
continues to launch **Codex CLI**, including when invoked from Claude; no Claude execution backend
or scheduled job is installed. Vendor workflows that mention a provider-specific tool still need
that tool or an equivalent supported by the current agent.

This setup selects six ECC skills rather than installing ECC's entire runtime. Adding a full ECC
plugin later requires resolving overlapping skills and choosing a canonical memory workflow.
References: [Claude skills](https://code.claude.com/docs/en/skills),
[shared instructions](https://code.claude.com/docs/en/memory#share-one-file-with-other-coding-tools).

## Layout

| Path | What it is |
| --- | --- |
| `global/AGENTS.md` | Personal defaults loaded into every session, everywhere |
| `global/CLAUDE.md` | Claude adapter importing the shared personal defaults |
| `skills/` | Reusable workflows Codex triggers on its own — one folder each, junctioned into `~/.codex/skills` |
| `commands/` | Prompt bodies you invoke by hand (`review`, `debug`, `ship-it`) |
| `loops/` | Loop definitions (`*.loop.md`) for headless, repeating work |
| `scripts/` | `sync`, `doctor`, `loop`, `story-ledger`, `schedule-loop`, plus the loop status schema |
| `SPEC.md`, `ROADMAP.md`, `TASKS.md` | Requirements, phase boundaries, and validated work |
| `codex-home/agents/` | Read-only Codex role layers copied into `~/.codex/agents/` |
| `claude-home/agents/` | Read-only Claude roles copied into `~/.claude/agents/` |
| `templates/` | Starters: project `AGENTS.md`, project `.codex/config.toml`, new skill |
| `vendor/` | Third-party skill repos, cloned as-is. `enabled.txt` picks which ones go live |
| `memory/` | Durable decisions — one fact per file, `INDEX.md` on top |
| `logs/` | Loop run output. Generated, gitignored |
| `.codex-plugin/` | Packaging manifest. Dormant — see below |

## Skills that ship with it

| Skill | Fires when |
| --- | --- |
| `loop-runner` | Work needs repeated passes — "keep going until", polling, grinding tests green |
| `project-bootstrap` | A repo needs an `AGENTS.md` and Codex settings |
| `memory-keeper` | Something is worth remembering across sessions |
| `ship-check` | Before calling a change done, committing, or deploying |
| `retrieve-knowledge` | Retrieve or organize substantial shared notes |
| `brain-to-docs` | Turn project vision and decisions into documentation |
| `next-decision` | Work through unresolved decisions one at a time |

## Vendored skills

`vendor/` holds upstream skill repos; `vendor/enabled.txt` decides which are junctioned into
both tools' personal skill folders. **48 vendor skills plus 25 local skills are available** — mattpocock's `engineering/` + `productivity/`,
karpathy's guidelines, selected planning/documentation workflows from David Ondrej, selected
engineering workflows from Addy Osmani, all of taste-skill, and six curated ECC skills for
verification, loops, GitHub operations, security, repository scanning, and skill audits. ECC's
unified-memory skill is vendored but off because `memory-keeper` remains the canonical memory system
here. Hyperframes is vendored but off; every skill in it needs the Hyperframes CLI and Remotion.

`brain-to-docs` and `next-decision` were removed from their upstream catalog. Their pinned,
MIT-licensed copies live in `skills/`, with provenance in each `SOURCE.md`; the old vendor
entries are commented out. Upstream pulls cannot silently remove these local copies.

Enable or disable by editing `enabled.txt`, then:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Workspace\agent-homebase\scripts\sync.ps1 -Target all -Force
```

`-Force` is required to unlink a disabled skill; without it sync reports it as `STALE` and leaves it.
It is also required before sync overwrites a changed `~/.codex/AGENTS.md`; sync saves its previous
contents as `~/.codex/AGENTS.md.<unique-id>.bak`. Roles and commands use unique backups too, so
repeated forced syncs preserve earlier versions. Unlinking removes the junction only — the vendored files are never touched. Details and update
commands: [vendor/README.md](vendor/README.md).

Those upstream clone/pull commands are unpinned. Use `bootstrap-vendor.ps1` for reproducible installs;
after deliberately reviewing an upstream update, record its new commit in `vendor-lock.json`.

Never edit anything under `vendor/`. To customize an upstream skill, copy it into `skills/`.

## Adding things

**A skill** — copy `templates/skill/SKILL.md` into `skills/<name>/SKILL.md`, set frontmatter `name`
to the folder name, write the `description` as *when to use this* (it is the only text Codex reads
before deciding), then run `sync.ps1`.

**A loop** — copy a file in `loops/`, set `cwd` and a checkable `exit_when`, run
`loop.ps1 -Loop <name> -DryRun` first. Format: `loops/_schema.md`.

**A command** — drop a markdown prompt in `commands/`.

**A memory** — ask Codex to remember it; the `memory-keeper` skill handles the file and the index.

## Scheduling

```bash
powershell -NoProfile -File E:\Workspace\agent-homebase\scripts\schedule-loop.ps1 -Loop repo-health -Daily 09:00
```

Tasks land under `\AgentHomebase\` in Task Scheduler. `-List` shows them, `-Remove` unregisters one.
Use `-DryRun` to preview registration or removal. Replacing an existing task requires `-Force`.
Registering may need an elevated shell.

## The plugin manifest

`.codex-plugin/plugin.json` is valid and passes the bundled validator, so this folder can be
published as a Codex plugin later without restructuring. It is deliberately **not** registered in
any marketplace — junctions plus an installed plugin would load every skill twice. Register it only
if you drop the junctions first.

## Requirements

Windows PowerShell 5.1 (no `pwsh` needed), Git, Codex CLI installed. Junctions work across volumes
without admin rights; only `schedule-loop.ps1` may require elevation.

Claude support additionally needs Claude Code on `PATH`; it can be configured before sign-in.
Node.js is needed for the integration tests, which use isolated folders and retain fixtures
for inspection:

```powershell
node scripts/tests/sync.test.js
node scripts/tests/reliability.test.js
```

The reliability checks use a mock model process, validate the generated commands against the
installed CLI's help parser, preview scheduling, and restore a vendor fixture from a local source.
They make no model calls or scheduled-task changes. Pester fixtures are also retained for inspection.
Validation checks tracked and non-ignored files for runtime artifacts, PowerShell ASCII encoding
and syntax, and pinned vendor drift.

## Quality checks

Install the pinned development dependencies and checksum-verified Windows tools:

```powershell
npm ci
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup-check-tools.ps1
```

Tools stay under ignored `logs/tools/`; setup also supports `-DryRun`. Versions and archive
SHA-256 hashes live in `tools-lock.json`. Nothing is installed into your global PowerShell modules.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/analyze.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/scan-secrets.ps1
npm test
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Pester -Script .\scripts\tests -EnableExit"
npm run eval:smoke
```

PSScriptAnalyzer enforces a focused baseline: PowerShell 5.1 syntax, automatic-variable assignment,
plaintext password handling, dynamic expression execution, and broken hash algorithms. Its rule
selection is explicit in `PSScriptAnalyzerSettings.psd1`; this is not a claim that every upstream
style rule passes. Gitleaks scans Git history and a snapshot of tracked/non-ignored source files,
with detected values redacted. Source snapshots and test fixtures are retained under `logs/` or
the OS temporary directory. The scanner does not traverse ignored vendor clones or dependencies.

`.github/workflows/checks.yml` runs these checks on Windows for pushes and pull requests.
It maps the existing `E:\Workspace\agent-homebase` convention to the checkout for the personal
guidance and loop fixtures. This verifies the current Windows setup, not arbitrary-path portability.
CI has read-only repository permissions and does not call a model, deploy, or modify your profiles.

`writing-for-agents` is enabled for maintaining skill descriptions and shared instructions.
Optional model-backed evaluations are documented in [evals/README.md](evals/README.md).
