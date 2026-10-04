---
name: workflow-experiment
description: Compare a proposed skill or prompt change against a fixed baseline and held-out tasks.
---

Use a bounded experiment with a fixed evaluator. Read [the evaluation workflow](E:/Workspace/agent-homebase/evals/WORKFLOW.md). Prepare a snapshot with:
```powershell
node 'E:/Workspace/agent-homebase/evals/workflow.cjs' prepare
```
Preparation makes no model calls. It freezes the tasks and relevant local skills/references, creates an immutable baseline slot, and allows up to three recorded candidates. Keep development and held-out results separate.

Select the same model/settings/tool access for baseline and candidate. Change one variable. Capture outputs and obtain per-case human grades against the frozen rubric. Record baseline and candidates with the commands printed by preparation. Never present hand-entered grades or canned outputs as a live model benchmark.

Hard failures include invented facts, broken required flows, lost material requirements, changed evaluation inputs, and unauthorized actions. Average quality cannot cancel them. Promote only after held-out review; the recorder recommends and never edits active skills.

The experiment method is inspired by [Karpathy autoresearch](E:/Workspace/agent-homebase/vendor/autoresearch/README.md); its original GPU training and [program](E:/Workspace/agent-homebase/vendor/autoresearch/program.md) are separate. Do not run its infinite loop, commits, resets, training, or cloud/API calls unchanged. Obtain the required action-specific permission and cost agreement before any billable execution. Preserve artifacts instead of deleting failed candidates.
