# Skill evaluations

The three starter cases cover memory recall, preserving project conventions during bootstrap
planning, and refusing to report readiness when a real test fails. These are read-only cases;
they do not yet verify memory writes or bootstrap edits.

## Offline checks

After `npm ci`, run `npm run eval:smoke`. It runs the real Promptfoo evaluator against a local
provider with canned answers. All three correct answers must pass and all three incorrect answers
must fail. This proves the scoring plumbing works; it does not prove that a model follows a skill.
There are no model calls or model-graded assertions in this command. CI runs it automatically.

## Prepare a live evaluation

Run `npm run eval:prepare`. This creates a new retained fixture under `logs/evals/` and prints
the generated configuration path. It copies the three current skills into `.agents/skills/`,
redirects only the copied memory skill's hardcoded store to a synthetic fixture, and creates a
separate Codex home with no copied credentials. The test project has an intentionally failing test.
Source skills and real memory are untouched. The provider uses a read-only sandbox and serial runs.

The generated configuration checks both evidence in the response and Promptfoo's `skill-used`
signal. For Codex, that signal infers invocation from successful reads of the skill file; it is not
proof that every instruction was followed. The text checks are a starter regression signal, not
an exhaustive quality judgment. Inspect traces and outputs before accepting a skill revision.

Preparation does not run the model. The default model is `gpt-5.5`; set `EVAL_MODEL` before
preparation to choose another supported model. After explicit approval of model usage and its
cost, set `CODEX_API_KEY` in the process environment through your usual secret mechanism and run
the exact command printed by preparation. Never put keys in config files or command arguments.
Three cases mean at least three agent runs; actual billing depends on model and token usage and
is not capped by these assertions. No live evaluation runs in CI.

Fixtures are unique per preparation. Keep a generated directory as the baseline snapshot before
editing source skills, then prepare another snapshot for the candidate. Compare results using
the same model and cases; repeat runs before interpreting small differences. Results stay local
unless you explicitly use a sharing feature.

Sources: [Promptfoo skill evaluation guide](https://www.promptfoo.dev/docs/guides/test-agent-skills/)
and [Codex SDK provider](https://www.promptfoo.dev/docs/providers/openai-codex-sdk/).
