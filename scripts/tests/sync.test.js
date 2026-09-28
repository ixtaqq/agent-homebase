// Integration checks use isolated config homes and retain fixtures for inspection.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const scratch = process.argv[2] || path.join(os.tmpdir(), 'agent-homebase-tests');
fs.mkdirSync(scratch, { recursive: true });
const fixture = fs.mkdtempSync(path.join(scratch, 'sync-'));
const codex = path.join(fixture, 'codex');
const claude = path.join(fixture, 'claude');
fs.mkdirSync(codex);
const env = { ...process.env, CODEX_HOME: codex, CLAUDE_CONFIG_DIR: claude };
// Node does not sanitize a PowerShell 7 module path when launching Windows PowerShell 5.1.
for (const key of Object.keys(env)) {
  if (key.toLowerCase() === 'psmodulepath') delete env[key];
}
let passed = 0;

function run(script, args, expected = 0) {
  const result = spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass',
    '-File', path.join(root, 'scripts', script), ...args], { env, encoding: 'utf8' });
  assert.equal(result.status, expected, `${script} ${args.join(' ')}\n${result.stdout}\n${result.stderr}`);
  return result.stdout;
}
function check(label, test) {
  test();
  passed += 1;
  console.log(`PASS ${label}`);
}
function snapshot(dir) {
  const result = {};
  for (const name of fs.readdirSync(dir).sort()) {
    const file = path.join(dir, name);
    const stat = fs.lstatSync(file);
    result[name] = stat.isSymbolicLink() ? fs.readlinkSync(file)
      : stat.isDirectory() ? snapshot(file)
      : { content: fs.readFileSync(file, 'utf8'), modified: stat.mtimeMs };
  }
  return result;
}
function assertSharedSkills() {
  const first = fs.readdirSync(path.join(codex, 'skills')).sort();
  const second = fs.readdirSync(path.join(claude, 'skills')).sort();
  assert.deepEqual(first, second);
  assert.ok(first.length >= 54);
  for (const name of first) {
    const a = path.join(codex, 'skills', name);
    const b = path.join(claude, 'skills', name);
    assert.equal(fs.realpathSync(a), fs.realpathSync(b));
    assert.ok(fs.existsSync(path.join(b, 'SKILL.md')));
  }
}

try {
  check('dry run makes no config directories or files', () => {
    run('sync.ps1', ['-Target', 'all', '-DryRun']);
    assert.deepEqual(fs.readdirSync(codex), []);
    assert.equal(fs.existsSync(claude), false);
  });
  check('both targets load the same skill sources, with separate roles and guidance', () => {
    run('sync.ps1', ['-Target', 'all']);
    assertSharedSkills();
    for (const [dest, source] of [[path.join(codex, 'AGENTS.md'), 'global/AGENTS.md'],
      [path.join(claude, 'CLAUDE.md'), 'global/CLAUDE.md'],
      [path.join(claude, 'commands/os-debug.md'), 'commands/debug.md'],
      [path.join(claude, 'agents/os-reviewer.md'), 'claude-home/agents/os-reviewer.md']]) {
      assert.deepEqual(fs.readFileSync(dest), fs.readFileSync(path.join(root, source)));
    }
    assert.equal(fs.existsSync(path.join(claude, 'agents/reviewer.toml')), false);
  });
  check('second sync is idempotent', () => {
    const before = snapshot(fixture);
    run('sync.ps1', ['-Target', 'all']);
    assert.deepEqual(snapshot(fixture), before);
  });
  check('doctor validates both isolated installations', () => {
    run('doctor.ps1', ['-Target', 'all']);
  });
  check('existing Claude instructions are preserved; drift propagates through all', () => {
    const file = path.join(claude, 'CLAUDE.md');
    fs.appendFileSync(file, '\nPersonal instruction to preserve.\n');
    const original = fs.readFileSync(file);
    run('sync.ps1', ['-Target', 'all'], 1);
    assert.deepEqual(fs.readFileSync(file), original);
    run('doctor.ps1', ['-Target', 'all'], 1);
    const before = snapshot(fixture);
    run('sync.ps1', ['-Target', 'claude', '-Force', '-DryRun']);
    assert.deepEqual(snapshot(fixture), before);
    run('sync.ps1', ['-Target', 'claude', '-Force']);
    assert.deepEqual(fs.readFileSync(file + '.bak'), original);
  });
  check('modified Claude command and agent role are preserved without Force', () => {
    const files = ['commands/os-debug.md', 'agents/os-reviewer.md'].map(p => path.join(claude, p));
    for (const file of files) fs.appendFileSync(file, '\nPersonal addition.\n');
    const before = files.map(file => fs.readFileSync(file));
    run('sync.ps1', ['-Target', 'claude'], 1);
    files.forEach((file, i) => assert.deepEqual(fs.readFileSync(file), before[i]));
  });
  check('real skill directory is never replaced, including with Force', () => {
    const alternate = path.join(fixture, 'conflict');
    const skillDir = path.join(alternate, 'skills/memory-keeper');
    fs.mkdirSync(skillDir, { recursive: true });
    fs.writeFileSync(path.join(skillDir, 'personal.txt'), 'Keep this data');
    env.CLAUDE_CONFIG_DIR = alternate;
    run('sync.ps1', ['-Target', 'claude', '-Force'], 1);
    assert.equal(fs.lstatSync(skillDir).isSymbolicLink(), false);
    assert.equal(fs.readFileSync(path.join(skillDir, 'personal.txt'), 'utf8'), 'Keep this data');
  });
  console.log(`${passed} passed / 0 failed. Fixtures: ${fixture}`);
} catch (error) {
  console.error(error.stack);
  console.error(`Fixtures retained: ${fixture}`);
  process.exitCode = 1;
}
