---
name: build-iterated-agentic-loop
description: Implement a scoped improvement loop after its evaluator, allowed edits, and stopping conditions are defined.
---

Read [HumanLayer's pinned builder](E:/Workspace/agent-homebase/vendor/humanlayer-skills/plugins/build-iterated-agentic-loop/skills/build-iterated-agentic-loop/SKILL.md) and only the selected runner reference. Resolve references relative to that source directory.

Adapt the mechanism to the chosen host and existing homebase runner; do not assume Claude-specific tools exist in Codex. Begin with manual local execution. The upstream generated commit/push/PR and scheduling instructions are replaced by the user's per-action permissions. Do not install hooks, schedule jobs, launch billable models, or publish as a side effect of creating the loop.

Implement an explicit iteration/time bound, a fixed evaluator, retained candidate outputs, and a stop on missing authorization or repeated unchanged failure. Use [workflow-experiment](../workflow-experiment/SKILL.md) for the local comparison record. Verify the runner offline before offering an authorized live run.
