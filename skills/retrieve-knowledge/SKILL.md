---
name: retrieve-knowledge
description: Retrieve focused long-form notes from the Agent Homebase knowledge library. Use when the user asks what they have saved or learned about a topic, asks to consult their personal knowledge, or wants an answer grounded in notes under E:\Workspace\agent-homebase\knowledge. Also use when the user asks to add, organize, or update durable research, references, or playbooks that are too substantial for a single memory fact.
---

# Retrieve Knowledge

Use `E:\Workspace\agent-homebase\knowledge` as the source of truth for the user's durable research and reference material. Keep retrieval focused so unrelated notes do not consume context.

## Retrieve knowledge

1. Read `E:\Workspace\agent-homebase\knowledge\INDEX.md` first.
2. Follow only the topic index whose description matches the request.
3. Open only the entries likely to answer the question. Do not load the entire library.
4. Distinguish saved knowledge from inference or current external information.
5. If the library has no relevant entry, say so plainly. Do not invent a saved position.
6. If accuracy depends on recent information, verify it with current primary sources and label the update separately from the saved notes.

## Add or update knowledge

1. Use knowledge for substantial, reusable material such as research syntheses, technical references, decision frameworks, and playbooks.
2. Use the `memory-keeper` skill instead for a short atomic fact, preference, decision, constraint, goal, or pointer.
3. Choose the closest topic folder. Create a new topic only when the existing categories are a poor fit.
4. Start from `E:\Workspace\agent-homebase\knowledge\_template.md`.
5. Keep one coherent subject per entry and use a descriptive kebab-case filename.
6. Preserve source links and access dates. Separate sourced facts from conclusions or opinions.
7. Update the topic `INDEX.md`, then ensure the main `INDEX.md` still routes to that topic.
8. Search for an existing entry before creating one. Update the existing entry when it covers the same subject.

## Boundaries

- Never store passwords, API keys, private keys, recovery codes, tokens, or other secrets.
- Keep project-specific operating conventions in that project's `AGENTS.md`.
- Do not copy transient task state or raw chat logs into knowledge.
- Do not silently overwrite a user's judgment; preserve meaningful disagreement and date changed conclusions.
