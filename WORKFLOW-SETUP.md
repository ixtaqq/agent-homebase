# Frontend, writing, and measured improvement

Implemented 4 October 2026 in the existing shared homebase. Both agents use the same 18 new
local adapters. Seven additional upstream repositories are pinned in vendor-lock.json;
none of their files are edited. Existing vendor activation remains unchanged.

## Use the skills

In a fresh Codex chat use `$write-in-my-voice`, `$frontend-direction`, or another skill name.
In a fresh Claude Code session use `/write-in-my-voice`, `/frontend-direction`, or another
skill name. Natural-language requests can also select the focused descriptions. The shared
sync creates the personal skill directories; a structural check is not a model-quality test.

| Task | Skill route |
| --- | --- |
| Draft/edit prose | write-in-my-voice; technical-writing for documentation |
| New UI or requested redesign | frontend-direction; one appropriate existing Taste profile |
| Interaction polish | emil-design-eng |
| Motion | animate or review-animations |
| Mobile web | mobile-native |
| Extreme content and layout | break-ui |
| Dependency choice | pick-ui-library |
| Small UI exploration | ui-prototype (distinct from existing prototype) |
| Rendered design review | visual-critique |
| Explain structure | show-me |
| Prepare a change description | visual-pr; local draft until publication is authorized |
| Improve shared instructions | improve-agent-instructions |
| React type cleanup | narrow-react-prop-types |
| Design/implement a bounded loop | design-control-loop, build-iterated-agentic-loop |
| Compare skill candidates | workflow-experiment |

The writing route uses Humanizer and pstack as references, preserves claims and uncertainty,
and returns finished prose. No personal writing corpus was supplied, so its defaults come
from existing preferences and explicit task context. Voice samples can be added later through
the established memory process. Vale findings are advisory; they cannot establish truth.

The frontend route uses existing engineering skills plus focused Emil guidance and selected
Vercel references. It preserves an existing brand. The Impeccable-inspired visual-critique is
a lightweight local adapter: its launcher, detector, hooks, and mandatory orchestration are
not installed. Browser/keyboard/real-device evidence must be reported honestly. Project-specific
Playwright, axe-core, and framework dependencies belong in the actual application when needed,
not in this configuration repository merely to inflate its tool count.

## Sources and changes from upstream

The exact revisions are recorded in vendor-lock.json. Local adapters link to source files;
their factual/editorial constraints and side-effect limits take precedence over upstream flows.

| Upstream | Local adaptation |
| --- | --- |
| cursor/plugins, pstack | unslop and technical-writing references; no Cursor orchestration, automatic commits, or blanket punctuation bans |
| humanlayer/skills at ca7c8088db69e315a8b2deea43820270457f8f3c | six workflows adapted for shared tools; visual-pr drafts locally; loop execution requires concrete bounds and permissions |
| emilkowalski/skills | seven focused adapters; no waiting introduction, redundant fix-all gate, debug production toggle by default, or invented device testing |
| blader/humanizer | embedded editorial reference; no extra draft/rewrite report unless requested; no added personal opinions |
| pbakaus/impeccable | design-criteria reference only; lightweight visual-critique clearly identifies itself |
| karpathy/autoresearch | original source available; GPU training not installed or launched; workflow-experiment adapts the fixed-evaluator method |
| vercel-labs/agent-skills | React/composition/writing/web-design references loaded only when relevant; no new deployment flows |

Upstream license files stay with their repositories. This setup points to those sources and
does not claim their code is covered by homebase's packaging license. Inspect the applicable
license before copying or redistributing upstream material. Source paths are personal-installation
paths under E:/Workspace/agent-homebase, consistent with the existing repository convention.

## Local checks and experiments

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap-vendor.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup-check-tools.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/sync.ps1 -Target all -DryRun
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/sync.ps1 -Target all
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1 -Target all
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lint-prose.ps1 -Path 'C:\path\draft.md'
npm run test:workflow
npm run eval:workflow
```

The new Vale 3.24.0 binary is checksum-verified and lives under ignored logs/tools.
The linter writes nothing to its input. No global PATH or PowerShell policy is changed.

The experiment command only freezes inputs and prepares review records. Its 20 tasks have
development/held-out splits. It preserves one baseline and up to three candidate records,
rejects modified inputs, and never runs a model or promotes changes automatically.
See [evals/WORKFLOW.md](evals/WORKFLOW.md). The existing Promptfoo checks remain available.

Live paid comparisons, original GPU autoresearch training, recurring jobs, commits, pushes,
deletion, and publication have not been enabled by this setup. Each still follows the user's
action-specific permissions. All candidate and test artifacts are retained.
