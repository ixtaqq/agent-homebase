# Commands

Reusable prompt bodies. Invoke one as a slash command, or feed it straight to the Claude CLI:

```powershell
Get-Content E:\Workspace\agent-homebase\commands\review.md -Raw | claude -p
```

These are prompts, not skills: a skill triggers on its own when the situation matches, a command
runs when you invoke it. Anything you find yourself typing twice belongs here; anything Claude
should reach for unprompted belongs in `skills/`.

`scripts/sync.ps1` copies these prompts into Claude Code as `/os-review`,
`/os-debug`, and `/os-ship-it`. The prefix avoids replacing Claude's built-in commands.
Re-run sync when prompt files change; changed personal copies are reported as drift and preserved.
