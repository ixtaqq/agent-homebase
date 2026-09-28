# Vendor

Third-party skill repos, cloned as-is. Everything here is upstream code — **never edit it**; your
changes would be lost on the next pull, and the diff would be invisible. If you want a modified
version, copy the folder into `skills/` and make it yours.

Vendored repos are not tracked by this repo's git (`.gitignore` keeps only `README.md` and
`enabled.txt`). This file plus `enabled.txt` is enough to reproduce the whole directory.

## Sources

| Folder | Upstream | Skills | Notes |
| --- | --- | --- | --- |
| `mattpocock-skills/` | https://github.com/mattpocock/skills | 41 | `engineering/` + `productivity/` enabled; `deprecated/`, `in-progress/`, `personal/`, `misc/` left off |
| `andrej-karpathy-skills/` | https://github.com/multica-ai/andrej-karpathy-skills | 1 | enabled |
| `davidondrej-skills/` | https://github.com/davidondrej/skills | 1 | `ask-then-build` enabled; retired `brain-to-docs` and `next-decision` retained under local `skills/` with pinned provenance |
| `addyosmani-agent-skills/` | https://github.com/addyosmani/agent-skills | 5 | selected source-driven, doubt-driven, simplification, frontend, and performance workflows enabled; browser testing left off until Chrome DevTools MCP is configured |
| `taste-skill/` | https://github.com/leonxlnx/taste-skill | 13 | all enabled; design/UI taste and imagegen |
| `hyperframes/` | https://github.com/heygen-com/hyperframes | 19 | **all disabled.** Sparse checkout of `skills/` only (30 MB of an 808 MB repo). Needs the hyperframes CLI + Remotion toolchain to be useful |
| `ecc/` | https://github.com/affaan-m/ECC | 6 | curated Codex-compatible skills enabled; unified-memory, Claude hooks, and full catalog left off |

## Enabling and disabling

`enabled.txt` is the switch. One path per line, relative to this folder; `#` comments a line out.
The link name comes from the SKILL.md frontmatter `name`, not the folder — several taste-skill
folders disagree with their own frontmatter (`soft-skill` declares `high-end-visual-design`), and
the frontmatter wins.

After editing, apply it:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Workspace\codex-os\scripts\sync.ps1 -Force
```

`-Force` is needed because disabling a skill means removing a junction sync previously created.
Without it, disabled entries are reported and left alone.

## Updating

```powershell
git -C E:\Workspace\codex-os\vendor\mattpocock-skills pull
```

Same for the others. Junctions are live, so a pull takes effect in the next thread — but new skills
upstream are **not** enabled automatically; add them to `enabled.txt` yourself. Review what changed
before pulling: these files become instructions in your sessions.

## Re-cloning from scratch

```bash
git clone --depth 1 https://github.com/mattpocock/skills mattpocock-skills
git clone --depth 1 https://github.com/multica-ai/andrej-karpathy-skills andrej-karpathy-skills
git clone --depth 1 https://github.com/davidondrej/skills davidondrej-skills
git clone --depth 1 https://github.com/addyosmani/agent-skills addyosmani-agent-skills
git clone --depth 1 https://github.com/leonxlnx/taste-skill taste-skill
git clone --depth 1 --filter=blob:none --sparse https://github.com/heygen-com/hyperframes hyperframes
git -C hyperframes sparse-checkout set skills
git clone --depth 1 https://github.com/affaan-m/ECC.git ecc
```
