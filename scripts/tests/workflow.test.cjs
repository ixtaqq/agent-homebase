const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const workflow = require('../../evals/workflow.cjs');
const run = workflow.prepare();
const cases = workflow.verify(run);
const profile = JSON.parse(fs.readFileSync(path.join(run, 'inputs/workflow-profile.json'), 'utf8'));
for (const name of profile.skills) {
  const file = path.join(run, 'inputs/skills', name, 'SKILL.md');
  const content = fs.readFileSync(file, 'utf8');
  for (const match of content.matchAll(/\]\(([^)]+)\)/g)) {
    const target = match[1];
    if (/^https?:/.test(target)) continue;
    const resolved = path.resolve(path.dirname(file), target);
    assert.ok(resolved.startsWith(path.join(run, 'inputs') + path.sep), `Reference escaped snapshot: ${resolved}`);
    assert.ok(fs.existsSync(resolved), `Missing snapshot reference: ${resolved}`);
  }
}
const save = (name, value) => {
  const file = path.join(run, name);
  fs.writeFileSync(file, JSON.stringify(value), { flag: 'wx' });
  return file;
};
const review = score => ({ label: 'Synthetic test only', kind: 'offline-fixture', model: 'no-model', settings: 'offline', candidateRevision: 'synthetic',
  cases: cases.map(test => ({ id: test.id, score, hardFailure: false, output: 'Synthetic fixture output', evidence: 'Recorder test only; not a behavioral evaluation' })) });
const baseline = save('baseline-input.json', review(3));
const better = save('better-input.json', review(4));
assert.throws(() => workflow.record(run, better), /baseline first/);
workflow.record(run, baseline, true);
assert.throws(() => workflow.record(run, baseline, true), /EEXIST/);
const incomplete = review(4);
incomplete.cases.pop();
assert.throws(() => workflow.record(run, save('incomplete.json', incomplete)), /Every frozen case/);
const duplicate = review(4);
duplicate.cases[0].id = duplicate.cases[1].id;
assert.throws(() => workflow.record(run, save('duplicate.json', duplicate)), /duplicate case/);
workflow.record(run, better);
assert.equal(workflow.summarize(run)[0].verdict, 'offline scoring example only');
const failed = review(5);
failed.cases[0].hardFailure = true;
workflow.record(run, save('failure-input.json', failed));
assert.equal(workflow.summarize(run)[1].verdict, 'retain baseline');
const mismatched = review(5);
mismatched.model = 'different-model';
workflow.record(run, save('mismatch-input.json', mismatched));
assert.equal(workflow.summarize(run)[2].sameConditions, false);
assert.throws(() => workflow.record(run, better), /budget exhausted/);
// An added input must invalidate the snapshot even if all original files are untouched.
fs.writeFileSync(path.join(run, 'inputs', 'unexpected.txt'), 'tampered fixture', { flag: 'wx' });
assert.throws(() => workflow.verify(run), /Frozen evaluation inputs changed/);
console.log(`Workflow recorder passed: baseline preservation, complete cases, duplicates, hard failures, conditions, budget and input integrity. ${cases.length} cases. Retained: ${run}`);
