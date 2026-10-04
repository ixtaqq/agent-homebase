---
name: mobile-native
description: Fix mobile-web viewport, touch, scroll, safe-area, and browser interaction problems.
---

Read [Emil's mobile-native guidance](E:/Workspace/agent-homebase/vendor/emilkowalski-skills/skills/mobile-native/SKILL.md) and its relevant linked references. Resolve links relative to that upstream directory.

This local adapter controls host behavior: use available Codex or Claude tools, continue the user's concrete task without an introductory waiting response, and follow the user's scope and permission rules. Preserve native browser behaviors that users rely on. Distinguish emulation from physical-device testing and report the latter as untested if unavailable.

A broad design task uses [frontend-direction](../frontend-direction/SKILL.md) to select one visual direction. Apply only the relevant upstream guidance; do not load every animation or aesthetic skill. Verify changes with the real browser or project checks and state which observations were actually made.
