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
function check(name, fn) { if (fn() === 'skip') return; console.log(`PASS ${name}`); passed++; }
// The runner starts claude through a .cmd shim here, the same way an npm install is launched.
const mock = path.join(fixture, 'mock-claude.js');
const shim = path.join(fixture, 'claude.cmd');
const calls = path.join(fixture, 'calls.jsonl');
fs.writeFileSync(mock, `
const fs = require('node:fs');
const args = process.argv.slice(2);
const stdin = fs.readFileSync(0, 'utf8');
fs.appendFileSync(process.env.TEST_CALLS, JSON.stringify({ args, stdin }) + '\\n');
JSON.parse(args[args.indexOf('--json-schema') + 1]);
const status = args.includes('--resume') || process.env.TEST_FAIL === '1' ? 'done' : 'continue';
console.log(JSON.stringify({ type: 'result', is_error: false, result: 'fixture',
  structured_output: { status, summary: 'fixture \\u2014 ok', next_action: 'next' } }));
process.exit(process.env.TEST_FAIL === '1' ? 7 : 0);
`);
fs.writeFileSync(shim, `@node "%~dp0mock-claude.js" %*\r\n`);
env.CLAUDE_EXE = shim;
env.TEST_CALLS = calls;
const loop = path.join(fixture, 'test.loop.md');
fs.writeFileSync(loop, `---\nname: reliability-${path.basename(fixture)}\ncwd: ${fixture}\npermission_mode: dontAsk\nallowed_tools: Bash(git status *)\nmax_iterations: 2\nexit_when: fixture completes\n---\nExercise the runner — "quoted" text.\n`);
try {
  check('runner executes two passes and resumes its own session', () => {
    run('loop.ps1', ['-Loop', loop]);
    const recorded = fs.readFileSync(calls, 'utf8').trim().split(/\r?\n/).map(JSON.parse);
    assert.equal(recorded.length, 2);
    const [first, second] = recorded.map(call => call.args);
    const session = first[first.indexOf('--session-id') + 1];
    assert.match(session, /^[0-9a-f-]{36}$/);
    assert.equal(second[second.indexOf('--resume') + 1], session);
    assert.equal(first[first.indexOf('--permission-mode') + 1], 'dontAsk');
    assert.equal(first[first.indexOf('--allowedTools') + 1], 'Bash(git status *)');
    assert.ok(recorded[0].stdin.includes('Exercise the runner — "quoted" text.'));
  });
  check('installed CLI accepts both generated commands without model execution', () => {
    const recorded = fs.readFileSync(calls, 'utf8').trim().split(/\r?\n/).map(JSON.parse);
    const find = spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command',
      `. '${root.replace(/'/g, "''")}\\scripts\\_common.ps1'; $env:CLAUDE_EXE = ''; Get-ClaudeExe`], { env, encoding: 'utf8' });
    // Prefer the CLI pinned in package.json; npm's PATH entry is a .cmd shim that spawnSync cannot quote.
    const pinned = path.join(root, 'node_modules', '@anthropic-ai', 'claude-code', 'bin', 'claude.exe');
    const binary = fs.existsSync(pinned) ? pinned : find.stdout.trim();
    if (!/\.exe$/i.test(binary)) {
      console.log(`SKIP no claude.exe found (${binary || 'not installed'}); generated commands were not checked against it`);
      return 'skip';
    }
    // --help rejects bad values but not unknown flag names, so check the names against its text.
    const help = spawnSync(binary, ['--help'], { env, encoding: 'utf8' }).stdout;
    for (const { args } of recorded) {
      const result = spawnSync(binary, [...args, '--help'], { env, encoding: 'utf8' });
      assert.equal(result.status, 0, result.stdout + result.stderr);
      for (const flag of args.filter(arg => arg.startsWith('--'))) assert.ok(help.includes(flag), `unknown flag ${flag}`);
    }
  });
  check('nonzero CLI exit cannot report completion even with a done status', () => {
    env.TEST_FAIL = '1';
    assert.match(run('loop.ps1', ['-Loop', loop], 3), /claude exited 7; treating as blocked/);
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
