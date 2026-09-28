# Commands

Reusable prompt bodies. Paste one into a thread, or feed it straight to Codex:

```powershell
Get-Content E:\Workspace\agent-homebase\commands\review.md -Raw | codex exec -
```

These are prompts, not skills: a skill triggers on its own when the situation matches, a command
runs when you invoke it. Anything you find yourself typing twice belongs here; anything Codex
should reach for unprompted belongs in `skills/`.

`scripts/sync.ps1 -Target claude` copies these prompts into Claude Code as `/os-review`,
`/os-debug`, and `/os-ship-it`. The prefix avoids replacing Claude's built-in commands.
Re-run sync when prompt files change; changed personal copies are reported as drift and preserved.
