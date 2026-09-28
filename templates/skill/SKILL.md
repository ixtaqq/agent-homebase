---
name: <folder-name>
description: <What it does, then WHEN to use it — the phrasings and situations that should trigger it. This is the only text Codex reads before deciding, so name the trigger words out loud.>
metadata:
  short-description: <under 40 chars, shown in skill lists>
---

# <Title>

<One or two lines: what this skill is for. Assume the reader is already a strong engineer — only
add what they could not know, such as your conventions, paths, and commands.>

## <The procedure>

1. <Step — concrete and checkable.>
2. <Step.>
3. <Step.>

## <Rules / do not>

- <A constraint that prevents a specific known failure.>
- <Another.>

---

Guidance for writing the skill itself (delete this section):

- Keep it short. Every line competes for context with the actual task.
- Match freedom to fragility: prose for judgment calls, exact commands for fragile sequences.
- Put long reference material in `references/` and load it only when needed; put runnable code in
  `scripts/`; put output templates in `assets/`.
- `name` must equal the folder name. Folder goes in `E:\Workspace\agent-homebase\skills\`, then run
  `scripts\sync.ps1`.
