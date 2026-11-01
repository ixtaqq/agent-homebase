---
name: repo-health
cwd: E:\Workspace\agent-homebase
permission_mode: dontAsk
allowed_tools: Bash(powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:/Workspace/agent-homebase/scripts/doctor.ps1)
max_iterations: 3
interval_seconds: 0
exit_when: doctor.ps1 exits 0 and every finding it reports is OK or WARN
---

Check the health of this agent-homebase installation.

Run exactly this with the Bash tool. It is the only command this loop is allowed to run:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:/Workspace/agent-homebase/scripts/doctor.ps1

Read the table it prints. If every row is OK or WARN and the exit code is 0, the loop is done —
report the row count and any WARN rows in your summary.

If any row is MISSING, DRIFT, CONFLICT, ORPHAN, or FAIL, this pass should diagnose exactly one of
them: name the row, explain the cause, and put the specific fix in `next_action`. Do not apply the
fix — this loop runs read-only, and repairs that touch `~/.claude` are the user's call.
