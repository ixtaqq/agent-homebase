// Integration checks use an isolated config home and retain fixtures for inspection.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const scratch = process.argv[2] || path.join(os.tmpdir(), 'agent-homebase-tests');
fs.mkdirSync(scratch, { recursive: true });
const fixture = fs.mkdtempSync(path.join(scratch, 'sync-'));
const claude = path.join(fixture, 'claude');
const env = { ...process.env, CLAUDE_CONFIG_DIR: claude };
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
function backups(file) {
  return fs.readdirSync(path.dirname(file))
    .filter(name => name.startsWith(path.basename(file) + '.') && name.endsWith('.bak'))
    .map(name => path.join(path.dirname(file), name));
}
function assertLinkedSkills() {
  const names = fs.readdirSync(path.join(claude, 'skills')).sort();
  assert.ok(names.length >= 54);
  for (const name of names) {
    const link = path.join(claude, 'skills', name);
    assert.ok(fs.realpathSync(link).startsWith(root), `${name} does not point into the repo`);
    assert.ok(fs.existsSync(path.join(link, 'SKILL.md')));
  }
}

try {
  check('dry run makes no config directories or files', () => {
    run('sync.ps1', ['-DryRun']);
    assert.equal(fs.existsSync(claude), false);
  });
  check('sync links skill sources and copies guidance, commands, and roles', () => {
    run('sync.ps1', []);
    assertLinkedSkills();
    for (const [dest, source] of [[path.join(claude, 'CLAUDE.md'), 'global/CLAUDE.md'],
      [path.join(claude, 'commands/os-debug.md'), 'commands/debug.md'],
      [path.join(claude, 'agents/os-reviewer.md'), 'claude-home/agents/os-reviewer.md']]) {
      assert.deepEqual(fs.readFileSync(dest), fs.readFileSync(path.join(root, source)));
    }
  });
  check('second sync is idempotent', () => {
    const before = snapshot(fixture);
    run('sync.ps1', []);
    assert.deepEqual(snapshot(fixture), before);
  });
  check('doctor validates the isolated installation', () => {
    run('doctor.ps1', []);
  });
  check('existing Claude instructions are preserved and reported as drift', () => {
    const file = path.join(claude, 'CLAUDE.md');
    fs.appendFileSync(file, '\nPersonal instruction to preserve.\n');
    const original = fs.readFileSync(file);
    run('sync.ps1', [], 1);
    assert.deepEqual(fs.readFileSync(file), original);
    run('doctor.ps1', [], 1);
    const before = snapshot(fixture);
    run('sync.ps1', ['-Force', '-DryRun']);
    assert.deepEqual(snapshot(fixture), before);
    run('sync.ps1', ['-Force']);
    assert.deepEqual(fs.readFileSync(backups(file)[0]), original);
  });
  check('modified Claude command and agent role are preserved without Force', () => {
    const files = ['commands/os-debug.md', 'agents/os-reviewer.md'].map(p => path.join(claude, p));
    for (const file of files) fs.appendFileSync(file, '\nPersonal addition.\n');
    const before = files.map(file => fs.readFileSync(file));
    run('sync.ps1', [], 1);
    files.forEach((file, i) => assert.deepEqual(fs.readFileSync(file), before[i]));
  });
  check('real skill directory is never replaced, including with Force', () => {
    const alternate = path.join(fixture, 'conflict');
    const skillDir = path.join(alternate, 'skills/memory-keeper');
    fs.mkdirSync(skillDir, { recursive: true });
    fs.writeFileSync(path.join(skillDir, 'personal.txt'), 'Keep this data');
    env.CLAUDE_CONFIG_DIR = alternate;
    run('sync.ps1', ['-Force'], 1);
    assert.equal(fs.lstatSync(skillDir).isSymbolicLink(), false);
    assert.equal(fs.readFileSync(path.join(skillDir, 'personal.txt'), 'utf8'), 'Keep this data');
  });
  check('repeated forced syncs preserve every guidance and role backup', () => {
    env.CLAUDE_CONFIG_DIR = claude;
    const files = ['CLAUDE.md', 'agents/os-reviewer.md'].map(p => path.join(claude, p));
    for (let pass = 0; pass < 2; pass++) {
      const old = files.flatMap(file => backups(file)).map(file => [file, fs.readFileSync(file)]);
      for (const file of files) fs.appendFileSync(file, `\nRevision ${pass}\n`);
      const originals = files.map(file => fs.readFileSync(file));
      run('sync.ps1', ['-Force']);
      old.forEach(([file, content]) => assert.deepEqual(fs.readFileSync(file), content));
      files.forEach((file, i) => assert.ok(backups(file).some(backup => fs.readFileSync(backup).equals(originals[i]))));
    }
  });
  console.log(`${passed} passed / 0 failed. Fixtures: ${fixture}`);
} catch (error) {
  console.error(error.stack);
  console.error(`Fixtures retained: ${fixture}`);
  process.exitCode = 1;
}
