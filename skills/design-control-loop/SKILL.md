---
name: design-control-loop
description: Design a bounded recurring improvement process with an observable target and fixed evaluation.
---

Consult [HumanLayer's pinned design method](E:/Workspace/agent-homebase/vendor/humanlayer-skills/plugins/design-control-loop/skills/design-control-loop/SKILL.md). Define the defect class, observable measurement, permitted edits, evaluator, stop condition, and review artifact before proposing a runner.

Reuse homebase's existing loop and evaluation infrastructure. Start with a local manual trial and one small change per iteration. Preserve rejected candidates. Treat evaluator changes as a separate task. Loop design does not authorize scheduling, spending, commits, pushes, deletion, or external messages.

Use [workflow-experiment](../workflow-experiment/SKILL.md) for comparisons. A broad goal such as 'improve everything' needs concrete criteria before an unattended loop can be implemented. Once the design is concrete, implement only the execution mode the user actually requested.
