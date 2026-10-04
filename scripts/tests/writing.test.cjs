const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const parent = path.join(root, 'logs', 'evals');
fs.mkdirSync(parent, { recursive: true });
const run = fs.mkdtempSync(path.join(parent, 'writing-'));
const cases = [
  ['hype', 'Supercharge your productivity with our revolutionary solution.', 2],
  ['filler', 'It is important to note that exports contain selected rows.', 1],
  ['concrete', 'The export contains only the rows you selected.', 0],
  ['uncertainty', 'We measured 180 ms on the test laptop; production latency may differ.', 0],
  ['technical', 'The gradient is computed from a vector of partial derivatives.', 0],
  ['code', '```text\nsupercharge your productivity\n```\nUse `revolutionary solution` as the test input.', 0],
];
for (const [name, prose, count] of cases) {
  const file = path.join(run, name + '.md');
  fs.writeFileSync(file, prose, { flag: 'wx' });
  const result = spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(root, 'scripts/lint-prose.ps1'), '-Path', file], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  const findings = Object.values(JSON.parse(result.stdout)).flat();
  assert.equal(findings.length, count, `${name}: ${result.stdout}`);
  assert.equal(fs.readFileSync(file, 'utf8'), prose, 'The linter modified its input');
}
console.log(`Writing checks passed: ${cases.length} cases. Fixtures retained: ${run}`);
