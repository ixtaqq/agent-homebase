---
name: visual-pr
description: Prepare a concise change description with a useful structural diagram for review.
---

Read the actual diff and relevant surrounding code. Lead with the problem and resulting behavior. Show a focused component tree, call flow, data-contract diff, or file-responsibility sketch only when it helps reviewers. Include material constraints and the checks actually run.

Use the [HumanLayer template](E:/Workspace/agent-homebase/vendor/humanlayer-skills/plugins/visual-pr/skills/visual-pr/references/pr_description_template.md) as a structural reference and follow the target repository's template when one exists.

Prepare a local description by default. This adapter replaces the upstream automatic commit, push, PR creation, and PR-edit steps. Perform those external actions only when the user's current scope explicitly authorizes the particular action. Do not change source code merely to produce a description. Do not manufacture screenshots or test evidence.
