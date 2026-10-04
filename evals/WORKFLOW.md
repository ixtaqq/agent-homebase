# Workflow experiments

This is a local preparation and evidence recorder. It does not call a model, schedule work,
train a network, edit active skills, or promote its own winner. The original Karpathy GPU
experiment remains in vendor/autoresearch for a separately scoped task.

Run `node evals/workflow.cjs prepare`. It retains a unique directory under logs/evals,
snapshots the 18 new local adapters and their selected upstream references, and records
SHA-256 hashes for the evaluation inputs. The 20 tasks cover writing, frontend, coding,
and permissions. Development and held-out tasks are labeled. Do not show held-out tasks
to the optimizer while developing a candidate. This is a small initial suite, not a quality guarantee.

The snapshot is a reference bundle, not an installed agent home or ready-made application.
For behavioral testing, use a separate fixture and only the relevant copied skill.
Supply an actual interface/codebase for task families that require running an application;
planning-only responses cannot establish implementation quality. Host browsers, binaries,
and framework dependencies must be verified in that fixture. The copied linter needs its
pinned tool installed if you choose to run it there. Prepare/record commands themselves
always run from the canonical homebase, not from the reference snapshot.

Before a live comparison, name the model, settings, tool access, expected usage/cost,
allowed writes, time bound, and number of calls. Obtain action-specific permission for
billable calls. Preparation and offline fixtures need no API credentials. Do not use the
current user's auth files as test fixtures.

Fill a NEW copy of review-template.json with actual outputs and a human review for every case.
Record a source revision or retained candidate path. Use these scores:

- 1: fails the task or changes material facts/requirements.
- 2: substantial corrections needed.
- 3: usable with noticeable edits.
- 4: meets the task with minor edits.
- 5: clear, accurate, useful result needing no material correction.

Set hardFailure true for fabricated facts, broken required behavior, missing material
requirements, changed evaluators, or unauthorized actions. Describe the concrete evidence.
Use kind `offline-fixture` for synthetic/canned examples, and `human-reviewed` only for
an actual output reviewed against the rubric. These declarations are not authentication;
inspect retained outputs and traces before accepting results.

The commands printed by prepare record one immutable baseline and at most three candidates.
Every record requires all 20 case IDs exactly once, scores, hard-failure flags, outputs,
and evidence. The recorder refuses changed frozen inputs and never overwrites prior records.
Summary keeps development/held-out scores separate, reports regressions and hard failures,
and requires matching model/settings before recommending human review. No active skill
changes automatically. An offline fixture can never be recommended as a measured quality win.

Keep the evaluator fixed. If a rubric or task changes, prepare a new experiment and rerun
the baseline. Repeat noisy model comparisons before drawing conclusions. Keep failed
candidates; do not use destructive resets or delete fixtures.

Run `node scripts/tests/workflow.test.cjs` to test the recorder's rejection paths with
synthetic reviews. Run `npm run eval:smoke` for the existing Promptfoo scoring checks.
Those tests validate machinery, not live model compliance or improvement.
