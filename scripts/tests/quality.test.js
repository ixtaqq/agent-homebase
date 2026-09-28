const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'homebase-quality-'));
function run(script, args, expected) {
  const result = spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
    path.join(root, 'scripts', script), ...args], { encoding: 'utf8' });
  assert.equal(result.status, expected, `${script} ${args.join(' ')}\n${result.stdout}\n${result.stderr}`);
  return result;
}
const bad = path.join(fixture, 'bad.ps1');
fs.writeFileSync(bad, "Invoke-Expression 'Write-Output unsafe'\n");
assert.match(run('analyze.ps1', ['-Path', bad], 1).stdout, /PSAvoidUsingInvokeExpression/);
const clean = path.join(fixture, 'clean.ps1');
fs.writeFileSync(clean, "Write-Output 'safe'\n");
run('analyze.ps1', ['-Path', clean], 0);
const secretDir = path.join(fixture, 'secrets');
fs.mkdirSync(secretDir);
// Synthetic token assembled at runtime; never a credential for a real account.
const fake = ['ghp', 'A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8'].join('_');
fs.writeFileSync(path.join(secretDir, 'example.txt'), `token=${fake}\n`);
const result = run('scan-secrets.ps1', ['-Path', secretDir], 1);
assert.equal((result.stdout + result.stderr).includes(fake), false);
const cleanDir = path.join(fixture, 'clean');
fs.mkdirSync(cleanDir);
fs.writeFileSync(path.join(cleanDir, 'example.txt'), 'No credentials here.\n');
run('scan-secrets.ps1', ['-Path', cleanDir], 0);
console.log(`4 quality checks passed. Fixtures retained: ${fixture}`);
