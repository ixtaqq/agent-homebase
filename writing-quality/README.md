# Local prose checks

Run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lint-prose.ps1 -Path <absolute-file-or-directory>`.
The wrapper uses the checksum-pinned Vale binary from `scripts/setup-check-tools.ps1`.
It runs offline, produces JSON, and never edits the target. Nothing is installed globally.

The small Homebase style flags empty promotional phrases and filler as suggestions.
Suggestions do not make the command fail. A runtime/configuration error still fails.
The model or author decides whether a phrase is appropriate in context. Quoted terms,
intentional voice, facts, uncertainty, code, and URLs must survive editing.
These rules do not detect AI authorship or establish factual accuracy.

Run `node scripts/tests/writing.test.cjs` for positive, negative, and markup-preservation cases.
Style references: https://docs.vale.sh/styles and https://github.com/vale-cli/vale.
