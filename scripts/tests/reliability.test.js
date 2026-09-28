// No model calls, task registration, deletion, or edits to installed profiles.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const scratch = process.argv[2] || path.join(os.tmpdir(), 'agent-homebase-tests');
fs.mkdirSync(scratch, { recursive: true });
const fixture = fs.mkdtempSync(path.join(scratch, 'reliability-'));
const env = { ...process.env };
for (const key of Object.keys(env)) if (key.toLowerCase() === 'psmodulepath') delete env[key];
let passed = 0;
function run(script, args = [], expected = 0) {
  const result = spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass',
    '-File', path.join(root, 'scripts', script), ...args], { env, encoding: 'utf8' });
  assert.equal(result.status, expected, `${script} ${args.join(' ')}\n${result.stdout}\n${result.stderr}`);
  return result.stdout;
}
function check(name, fn) { fn(); console.log(`PASS ${name}`); passed++; }
const mock = path.join(fixture, 'mock-codex.ps1');
const calls = path.join(fixture, 'calls.jsonl');
fs.writeFileSync(mock, `
ConvertTo-Json -InputObject @($args) -Compress | Add-Content -LiteralPath $env:TEST_CALLS
$output = $args[[array]::IndexOf($args, '-o') + 1]
$status = 'continue'
if ($args -contains 'resume' -or $env:TEST_FAIL -eq '1') { $status = 'done' }
@{status=$status;summary='fixture';next_action='next'} | ConvertTo-Json | Set-Content -LiteralPath $output
Write-Output '{"type":"thread.started","thread_id":"00000000-0000-0000-0000-000000000001"}'
if ($env:TEST_FAIL -eq '1') { exit 7 }
exit 0
`);
env.CODEX_EXE = mock;
env.TEST_CALLS = calls;
const loop = path.join(fixture, 'test.loop.md');
fs.writeFileSync(loop, `---\nname: reliability-${path.basename(fixture)}\ncwd: ${fixture}\nsandbox: read-only\nmax_iterations: 2\nexit_when: fixture completes\n---\nExercise the runner.\n`);
try {
  check('runner executes two passes and resumes its own session', () => {
    run('loop.ps1', ['-Loop', loop]);
    const recorded = fs.readFileSync(calls, 'utf8').trim().split(/\r?\n/).map(JSON.parse);
    assert.equal(recorded.length, 2);
    assert.equal(recorded[1][recorded[1].indexOf('resume') + 1], '00000000-0000-0000-0000-000000000001');
    assert.ok(recorded[1].indexOf('-C') < recorded[1].indexOf('resume'));
    assert.ok(recorded[1].indexOf('-s') < recorded[1].indexOf('resume'));
  });
  check('installed CLI accepts both generated commands without model execution', () => {
    const recorded = fs.readFileSync(calls, 'utf8').trim().split(/\r?\n/).map(JSON.parse);
    const find = spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command',
      `. '${root.replace(/'/g, "''")}\\scripts\\_common.ps1'; $env:CODEX_EXE = ''; Get-CodexExe`], { env, encoding: 'utf8' });
    assert.equal(find.status, 0, find.stderr);
    const helpScript = path.join(fixture, 'cli-help.ps1');
    fs.writeFileSync(helpScript, 'param($Binary, $ArgumentsFile)\n$cliArguments = Get-Content -LiteralPath $ArgumentsFile -Raw | ConvertFrom-Json\n& $Binary @cliArguments\nexit $LASTEXITCODE\n');
    for (const [index, args] of recorded.entries()) {
      const argsFile = path.join(fixture, `help-${index}.json`);
      fs.writeFileSync(argsFile, JSON.stringify([...args.slice(0, -1), '--help']));
      const result = spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
        helpScript, find.stdout.trim(), argsFile], { env, encoding: 'utf8' });
      assert.equal(result.status, 0, result.stdout + result.stderr);
    }
  });
  check('nonzero CLI exit cannot report completion even with a done status file', () => {
    env.TEST_FAIL = '1';
    assert.match(run('loop.ps1', ['-Loop', loop], 3), /codex exited 7; treating as blocked/);
    delete env.TEST_FAIL;
  });
  check('scheduling and removal can be previewed without Task Scheduler writes', () => {
    assert.match(run('schedule-loop.ps1', ['-Loop', 'repo-health', '-Daily', '09:00', '-DryRun']), /Would schedule/);
    assert.match(run('schedule-loop.ps1', ['-Loop', 'repo-health', '-Remove', '-DryRun']), /Would remove/);
  });
  check('vendor bootstrap previews, restores and verifies a pinned local checkout', () => {
    const lock = JSON.parse(fs.readFileSync(path.join(root, 'vendor-lock.json'), 'utf8'));
    const repo = lock.repositories.find(repo => repo.name === 'andrej-karpathy-skills');
    const manifest = path.join(fixture, 'vendor-lock.json');
    fs.writeFileSync(manifest, JSON.stringify({ version: 1, repositories: [{ ...repo, url: path.join(root, 'vendor', repo.name) }] }));
    const dest = path.join(fixture, 'vendor');
    const args = ['-Manifest', manifest, '-Destination', dest];
    run('bootstrap-vendor.ps1', [...args, '-DryRun']);
    assert.equal(fs.existsSync(dest), false);
    run('bootstrap-vendor.ps1', args);
    run('bootstrap-vendor.ps1', [...args, '-Check']);
    run('bootstrap-vendor.ps1', args);
    const personal = path.join(dest, repo.name, 'personal.txt');
    fs.writeFileSync(personal, 'preserve');
    run('bootstrap-vendor.ps1', args, 1);
    assert.equal(fs.readFileSync(personal, 'utf8'), 'preserve');
  });
  check('validation rejects runtime database variants, non-ASCII scripts and syntax errors', () => {
    const checkout = path.join(fixture, 'validation');
    fs.mkdirSync(checkout);
    const files = spawnSync('git', ['-C', root, 'ls-files', '--cached', '--others', '--exclude-standard'], { encoding: 'utf8' });
    assert.equal(files.status, 0, files.stderr);
    for (const file of new Set(files.stdout.trim().split(/\r?\n/))) {
      if (file.startsWith('vendor/')) continue;
      const dest = path.join(checkout, file);
      fs.mkdirSync(path.dirname(dest), { recursive: true });
      fs.copyFileSync(path.join(root, file), dest);
    }
    fs.symlinkSync(path.join(root, 'vendor'), path.join(checkout, 'vendor'), 'junction');
    const init = spawnSync('git', ['init', checkout], { encoding: 'utf8' });
    assert.equal(init.status, 0, init.stderr);
    const validate = () => spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass',
      '-File', path.join(checkout, 'scripts/validate.ps1')], { env, encoding: 'utf8' });
    const baseline = validate();
    assert.equal(baseline.status, 0, baseline.stdout + baseline.stderr);
    fs.writeFileSync(path.join(checkout, 'state_99.sqlite-wal'), 'fixture');
    fs.writeFileSync(path.join(checkout, 'bad.ps1'), '# \u2014\nif (');
    const result = validate();
    assert.equal(result.status, 1, result.stdout + result.stderr);
    assert.match(result.stderr, /runtime or credential file must not be tracked: state_99.sqlite-wal/);
    assert.match(result.stderr, /PowerShell script must be ASCII-only: bad.ps1/);
    assert.match(result.stderr, /Missing condition/);
  });
  console.log(`${passed} passed / 0 failed. Fixtures: ${fixture}`);
} catch (error) {
  console.error(error.stack);
  console.error(`Fixtures retained: ${fixture}`);
  process.exitCode = 1;
}
