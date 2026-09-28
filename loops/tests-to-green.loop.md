---
name: tests-to-green
cwd: E:\Workspace\agent-homebase
sandbox: workspace-write
max_iterations: 8
interval_seconds: 0
exit_when: the project's full test command exits 0
---

Drive this repository's test suite to green.

Pass one: find the real test command (package manifest scripts, Makefile, CI workflow, the repo's
AGENTS.md) and run it. State which command you chose.

Every pass after that: take the single most-informative failure, fix its actual cause, and re-run
the suite. One failure per pass.

Rules:

- Fix the cause, never the assertion. Do not delete, skip, or `xfail` a test to make it pass.
- Do not change unrelated code, add dependencies, or reformat files.
- If two consecutive passes produce the same failure with no new information, report `blocked` with
  the failure output and what you would need in order to proceed.

Before reporting `done`, run the full suite once more and quote its final line.

Edit the `cwd` in this file's frontmatter, or pass `-Loop tests-to-green` from a copy, to point it
at a real project.
