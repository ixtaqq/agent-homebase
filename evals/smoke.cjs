const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const cases = require('./cases.json');
const grade = require('./assertion.cjs');
const root = path.resolve(__dirname, '..');
const parent = path.join(root, 'logs', 'evals');
fs.mkdirSync(parent, { recursive: true });
const run = fs.mkdtempSync(path.join(parent, 'offline-'));
const cli = path.join(root, 'node_modules', 'promptfoo', 'dist', 'src', 'entrypoint.js');
for (const answer of ['good', 'bad']) {
  for (const test of cases) assert.equal(grade(test[answer], { vars: test }).pass, answer === 'good');
  const config = {
    prompts: ['{{request}}'],
    providers: [{ id: 'file://' + path.join(__dirname, 'offline-provider.cjs').replaceAll('\\', '/'), config: { answer } }],
    tests: cases.map(test => ({ description: test.description, vars: test,
      assert: [{ type: 'javascript', value: require('./assertion.js') }] })),
  };
  const file = path.join(run, `${answer}.json`);
  const output = path.join(run, `${answer}-results.json`);
  fs.writeFileSync(file, JSON.stringify(config));
  const result = spawnSync(process.execPath, [cli, 'eval', '-c', file, '--no-cache', '--no-progress-bar', '-o', output], {
    encoding: 'utf8', env: { ...process.env, PROMPTFOO_DISABLE_TELEMETRY: '1', PROMPTFOO_DISABLE_UPDATE: '1', PROMPTFOO_CONFIG_DIR: path.join(run, 'config') },
  });
  assert.equal(result.status, answer === 'good' ? 0 : 100, result.stdout + result.stderr);
  const report = JSON.parse(fs.readFileSync(output, 'utf8'));
  assert.equal(report.results.stats[answer === 'good' ? 'successes' : 'failures'], cases.length);
}
console.log(`Offline evaluation smoke passed: ${cases.length} good answers accepted; ${cases.length} bad answers rejected. No model calls.`);
