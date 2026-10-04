---
name: frontend-direction
description: Choose visual direction and route skills for a new interface or an explicitly requested redesign.
---

Read the product brief, existing interface, brand, intended audience, real content, device targets, and acceptance conditions. Preserve the existing design system unless redesign is requested. Resolve only choices that materially change the result.

Choose one visual lead. Use a relevant existing Taste profile for a requested aesthetic; use [visual-critique](../visual-critique/SKILL.md) to evaluate an existing draft. Do not load several competing aesthetic skills. Familiar fonts, cards, gradients, and rounded corners are valid when justified by the product.

Write a compact design brief with layout/hierarchy, typography, spacing, color, content, interaction, and responsive decisions. For an open consequential direction choice, use small distinct prototypes before building the full app. Skip that ceremony for a targeted component fix.

Route only the current need:
- Interaction details: [emil-design-eng](../emil-design-eng/SKILL.md).
- Motion: [animate](../animate/SKILL.md) or [review-animations](../review-animations/SKILL.md).
- Mobile web: [mobile-native](../mobile-native/SKILL.md).
- Difficult content: [break-ui](../break-ui/SKILL.md).
- Component-library choice: [pick-ui-library](../pick-ui-library/SKILL.md).
- UI exploration: [ui-prototype](../ui-prototype/SKILL.md).
- React implementation: existing frontend-ui-engineering, then the relevant [Vercel React rules](E:/Workspace/agent-homebase/vendor/vercel-agent-skills/skills/react-best-practices/SKILL.md) or [composition rules](E:/Workspace/agent-homebase/vendor/vercel-agent-skills/skills/composition-patterns/SKILL.md). Read only applicable rules and verify the project's actual framework version.
- Product text: [write-in-my-voice](../write-in-my-voice/SKILL.md).

Inspect the actual rendered result using the available browser tool, then verify the changed flow. Check keyboard/focus, narrow/wide widths, zoom, realistic text, and relevant loading/empty/error states. Use project tests and accessibility/performance tools where available and appropriate. Separate observed results from code-only inferences. Do not report a screen-reader or real-device check you did not perform. Do not install another browser driver when the host already supplies one.
