---
name: narrow-react-prop-types
description: Tighten React prop types to the states actually supported by a component and its callers.
---

Read [HumanLayer's pinned instructions](E:/Workspace/agent-homebase/vendor/humanlayer-skills/plugins/narrow-react-prop-types/skills/narrow-react-prop-types/SKILL.md). Trace production callers, public exports, runtime data, and tests before narrowing. A missing test case is not evidence a state is impossible.

Preserve supported behavior and downstream API compatibility. Use unions or concrete element/value types where they describe reality; avoid casts that hide invalid states. Run the relevant typecheck and behavior tests. Do not commit changes or discard existing work as part of cleanup.
