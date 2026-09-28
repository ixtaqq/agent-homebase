---
name: memory-keeper
description: Record or look up durable cross-session facts — decisions, preferences, constraints, gotchas, and external references — in agent-homebase/memory. Use when the user says remember this, note that for later, why did we decide X, what did we choose for Y, or when a decision is made that would otherwise have to be re-explained in a future session.
metadata:
  short-description: Keep durable decisions and preferences
---

# Memory Keeper

Store: `E:\Workspace\agent-homebase\memory\` — one fact per file in `entries/`, one line per fact in
`INDEX.md`. Read `INDEX.md` first; open an entry only when its line looks relevant.

## What belongs here

Yes: decisions and the reasoning behind them, stable preferences, hard-won gotchas, constraints
that are not visible in code, pointers to external resources.

No: anything the repo already records (structure, git history, what a function does), facts that
only matter inside the current conversation, or anything that will be stale next week. Secrets and
credentials never go here.

If asked to remember something the repo already says, ask what was non-obvious about it and record
that instead.

## Entry format

`memory/entries/<kebab-case-slug>.md`:

```markdown
---
name: <kebab-case-slug>
description: <one line — this is what gets scanned during recall>
type: decision | preference | constraint | reference
created: YYYY-MM-DD
---

<The fact, stated plainly in a sentence or two.>

**Why:** <the reasoning, so future-you can tell if it still applies>
**Applies to:** <repos, tools, or contexts — "all" is valid>
```

Convert relative dates to absolute ("last week" → the actual date). Link related entries with
`[[slug]]`; a link to an entry that does not exist yet is fine — it marks something worth writing.

## Writing an entry

1. Scan `INDEX.md` for something that already covers it. **Update that file rather than adding a
   near-duplicate.**
2. Write the entry file.
3. Add one line to `INDEX.md`: `- [<slug>](entries/<slug>.md) — <hook>`. Never put the fact itself
   in `INDEX.md`.

## Maintenance

- When a decision is reversed, edit the entry to state the new decision and why it changed. Do not
  leave both versions implying both are current.
- Delete entries that turned out to be wrong. A wrong memory is worse than a missing one.
- Entries reflect what was true when written. If one names a file, flag, or command, verify it still
  exists before acting on it.
