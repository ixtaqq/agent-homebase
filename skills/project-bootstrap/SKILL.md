---
name: project-bootstrap
description: Set up a repository for Claude Code with verified project instructions. Use when the user asks to bootstrap, onboard, or set up a repository for coding agents.
metadata:
  short-description: Wire a repo into the personal Agent Homebase
---

# Project Bootstrap

Templates live in `E:\Workspace\agent-homebase\templates\project\`. They are a starting point, not the
deliverable — a copied template with placeholders left in is worse than no file at all.

## Steps

1. **Read the repo first.** Package manifest, existing scripts, test config, CI workflow, directory
   layout. The whole value of `AGENTS.md` is the commands and conventions that are actually true
   here.

2. **Write `<repo>/AGENTS.md`** from `templates/project/AGENTS.md`. Fill in, from evidence:
   - stack and language versions,
   - the real build / test / lint commands (verify each one runs),
   - layout: where source, tests, and config live,
   - conventions the code already follows — naming, error handling, test style,
   - the verification bar for this repo.

   Keep the template's pointer to `PROJECT-WORKFLOW.md`; `projects-doctor.ps1` checks for it.
   Delete every section you could not fill with something specific. Aim for under 50 lines.
   If `AGENTS.md` already exists, extend it — never overwrite — and add the pointer if missing.

3. **Add `<repo>/CLAUDE.md`** containing `@AGENTS.md` from `templates/project/CLAUDE.md`. If it
   already exists, preserve its instructions and add the import only if missing. Claude Code
   manages workspace trust in its own interface.

4. **For a repo under `E:\workspace\Projects`**, add its row to that folder's `README.md`, then run
   `powershell -NoProfile -ExecutionPolicy Bypass -File E:\Workspace\agent-homebase\scripts\projects-doctor.ps1`
   and resolve what it reports for this project.

5. **Report** which files were created, which commands you verified, and anything you could not
   determine and left out.

## Do not

- Do not invent commands you did not run.
- Do not restate global defaults (`E:\Workspace\agent-homebase\global\AGENTS.md`) in the project file.
  Project `AGENTS.md` is for what is *different* here.
- Do not add tooling, CI, or dependencies the user did not ask for.
