const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const write = (file, value) => fs.writeFileSync(file, JSON.stringify(value, null, 2) + '\n', { flag: 'wx' });
const digest = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');

function inventory(directory) {
  const result = {};
  function visit(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const file = path.join(dir, entry.name);
      if (entry.isSymbolicLink()) throw new Error(`Unexpected link in frozen inputs: ${file}`);
      if (entry.isDirectory()) visit(file);
      else result[path.relative(directory, file).replaceAll('\\', '/')] = digest(file);
    }
  }
  visit(directory);
  return result;
}

function prepare() {
  const parent = path.join(root, 'logs', 'evals');
  fs.mkdirSync(parent, { recursive: true });
  const run = fs.mkdtempSync(path.join(parent, 'workflow-'));
  const inputs = path.join(run, 'inputs');
  const profile = read(path.join(root, 'workflow-profile.json'));
  const sources = [...profile.skills.map(name => `skills/${name}`), ...profile.references,
    'workflow-profile.json', 'vendor-lock.json', 'tools-lock.json', 'evals/workflow-cases.json', 'evals/WORKFLOW.md',
    'evals/workflow.cjs', 'scripts/lint-prose.ps1', 'scripts/setup-check-tools.ps1', 'writing-quality'];
  for (const source of sources) {
    const target = path.join(inputs, source);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.cpSync(path.join(root, source), target, { recursive: true, errorOnExist: true, force: false,
      filter: item => !['.git', 'node_modules'].includes(path.basename(item)) });
  }
  // Snapshot references resolve inside the experiment, never to mutable source instructions.
  for (const relative of Object.keys(inventory(inputs)).filter(file => file.endsWith('.md'))) {
    const file = path.join(inputs, relative);
    const content = fs.readFileSync(file, 'utf8');
    const updated = content.replace(/E:[\\/]Workspace[\\/]agent-homebase/gi, () => inputs.replaceAll('\\', '/'));
    if (content !== updated) fs.writeFileSync(file, updated);
  }
  write(path.join(run, 'manifest.json'), { version: 1, created: new Date().toISOString(), maxCandidates: 3,
    files: inventory(inputs), evaluationKind: 'manual evidence; no model calls' });
  const cases = read(path.join(inputs, 'evals/workflow-cases.json'));
  write(path.join(run, 'review-template.json'), { label: 'Name this run', kind: 'human-reviewed',
    model: 'Record actual model or no-model', settings: 'Record settings and tool access',
    candidateRevision: 'Record the candidate source revision or retained path',
    cases: cases.map(test => ({ id: test.id, score: null, hardFailure: null, output: '', evidence: '' })) });
  return run;
}

function verify(run) {
  const manifest = read(path.join(run, 'manifest.json'));
  if (manifest.version !== 1 || manifest.maxCandidates !== 3) throw new Error('Unsupported experiment manifest');
  if (JSON.stringify(inventory(path.join(run, 'inputs'))) !== JSON.stringify(manifest.files)) {
    throw new Error('Frozen evaluation inputs changed; prepare a separate experiment');
  }
  return read(path.join(run, 'inputs/evals/workflow-cases.json'));
}

function validateReview(review, cases) {
  for (const field of ['label', 'model', 'settings', 'candidateRevision']) {
    if (typeof review[field] !== 'string' || !review[field].trim()) throw new Error(`Missing ${field}`);
  }
  if (!['human-reviewed', 'offline-fixture'].includes(review.kind)) throw new Error('Review kind must identify human-reviewed or offline-fixture evidence');
  if (!Array.isArray(review.cases) || review.cases.length !== cases.length) throw new Error('Every frozen case needs a review');
  const ids = new Set(cases.map(test => test.id));
  for (const grade of review.cases) {
    if (!ids.delete(grade.id)) throw new Error(`Unknown or duplicate case: ${grade.id}`);
    if (!Number.isInteger(grade.score) || grade.score < 1 || grade.score > 5) throw new Error(`Invalid score: ${grade.id}`);
    if (typeof grade.hardFailure !== 'boolean') throw new Error(`Missing hardFailure: ${grade.id}`);
    if (typeof grade.output !== 'string' || !grade.output.trim() || typeof grade.evidence !== 'string' || !grade.evidence.trim()) {
      throw new Error(`Output and evidence required: ${grade.id}`);
    }
  }
}

function record(run, file, baseline = false) {
  const cases = verify(run);
  const review = read(file);
  validateReview(review, cases);
  const existing = fs.readdirSync(run).filter(name => /^candidate-\d+\.json$/.test(name));
  if (!baseline && !fs.existsSync(path.join(run, 'baseline.json'))) throw new Error('Record a baseline first');
  if (!baseline && existing.length >= 3) throw new Error('Candidate budget exhausted: 3');
  const target = path.join(run, baseline ? 'baseline.json' : `candidate-${existing.length + 1}.json`);
  write(target, { ...review, recorded: new Date().toISOString() });
  return target;
}

function summarize(run) {
  const cases = verify(run);
  const baseline = read(path.join(run, 'baseline.json'));
  const mean = (review, split) => {
    const ids = new Set(cases.filter(test => test.split === split).map(test => test.id));
    const selected = review.cases.filter(grade => ids.has(grade.id));
    return selected.reduce((sum, grade) => sum + grade.score, 0) / selected.length;
  };
  return fs.readdirSync(run).filter(name => /^candidate-\d+\.json$/.test(name)).sort().map(file => {
    const candidate = read(path.join(run, file));
    const sameConditions = candidate.model === baseline.model && candidate.settings === baseline.settings && candidate.kind === baseline.kind;
    const failures = candidate.cases.filter(grade => grade.hardFailure).map(grade => grade.id);
    const gains = Object.fromEntries(['development', 'heldout'].map(split => [split, mean(candidate, split) - mean(baseline, split)]));
    const baseById = new Map(baseline.cases.map(grade => [grade.id, grade]));
    const regressions = candidate.cases.filter(grade => grade.score < baseById.get(grade.id).score).map(grade => grade.id);
    const eligible = sameConditions && !failures.length && !regressions.length && gains.development > 0 && gains.heldout >= 0;
    return { file, label: candidate.label, kind: candidate.kind, sameConditions, hardFailures: failures, regressions, gains,
      verdict: eligible ? (candidate.kind === 'offline-fixture' ? 'offline scoring example only' : 'eligible for human review; no automatic promotion') : 'retain baseline' };
  });
}

if (require.main === module) {
  const [command, run, file] = process.argv.slice(2);
  try {
    if (command === 'prepare') {
      const directory = prepare();
      console.log(`Prepared only; no model calls. Experiment: ${directory}`);
      console.log(`Fill a new copy of review-template.json; preserve outputs and source revision. Then run:`);
      console.log(`node "${__filename}" baseline "${directory}" "<completed baseline review.json>"`);
      console.log(`node "${__filename}" candidate "${directory}" "<completed candidate review.json>"`);
      console.log(`node "${__filename}" summary "${directory}"`);
    } else if (command === 'baseline' || command === 'candidate') {
      if (!run || !file) throw new Error('Provide experiment directory and completed review JSON');
      console.log(record(path.resolve(run), path.resolve(file), command === 'baseline'));
    } else if (command === 'summary' && run) console.log(JSON.stringify(summarize(path.resolve(run)), null, 2));
    else throw new Error('Usage: workflow.cjs prepare | baseline <run> <review> | candidate <run> <review> | summary <run>');
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
module.exports = { prepare, verify, record, summarize };
