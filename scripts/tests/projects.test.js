// Fixture workspace only: no reads of the real Projects folder or ~/.codex.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const scratch = process.argv[2] || path.join(os.tmpdir(), 'agent-homebase-tests');
fs.mkdirSync(scratch, { recursive: true });
const fixture = fs.mkdtempSync(path.join(scratch, 'projects-'));
const workspace = path.join(fixture, 'Projects');
const codexHome = path.join(fixture, 'codex');
let passed = 0;

function write(file, text) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, text);
}
function run(args = [], expected = 0) {
  const result = spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
    path.join(root, 'scripts', 'projects-doctor.ps1'), '-ProjectsRoot', workspace, ...args],
    { env: { ...process.env, CODEX_HOME: codexHome }, encoding: 'utf8' });
  assert.equal(result.status, expected, `${args.join(' ')}\n${result.stdout}\n${result.stderr}`);
  return result.stdout;
}
function rows(output, project) {
  return output.split(/\r?\n/).filter((line) => line.startsWith(project + ' '));
}
function check(name, fn) { fn(); console.log(`PASS ${name}`); passed++; }

const wired = path.join(workspace, 'apps', 'wired');
write(path.join(wired, 'AGENTS.md'), 'Read `PROJECT-WORKFLOW.md`.\n');
write(path.join(wired, 'CLAUDE.md'), '@AGENTS.md\n');
fs.mkdirSync(path.join(wired, '.git'));
write(path.join(workspace, 'CLAUDE.md'), '@AGENTS.md\n@E:/x/PROJECT-WORKFLOW.md\n');
write(path.join(workspace, 'README.md'), '| [wired](apps/wired/) |\n');
write(path.join(codexHome, 'config.toml'),
  `[windows]\nsandbox = "elevated"\n\n[projects."${wired.toLowerCase().replace(/\\/g, '\\\\')}"]\ntrust_level = "trusted"\n`);
fs.mkdirSync(path.join(workspace, '.tools', 'node'), { recursive: true });

check('fully wired project passes with a double-quoted trust key', () => {
  const output = run();
  assert.match(output, /All checks passed: 1 project\(s\)/);
  assert.equal(rows(output, 'apps/wired').length, 4);
});

const alias = path.join(workspace, 'wired-alias');
const link = spawnSync('cmd.exe', ['/c', 'mklink', '/J', alias, wired], { encoding: 'utf8' });
assert.equal(link.status, 0, link.stdout + link.stderr);
spawnSync('attrib.exe', ['+h', alias, '/l']);
const visibleAlias = path.join(workspace, 'apps', 'wired link');
assert.equal(spawnSync('cmd.exe', ['/c', 'mklink', '/J', visibleAlias, wired]).status, 0);

check('hidden entries are skipped and junctions are de-duplicated by target', () => {
  const output = run();
  assert.match(output, /1 project\(s\)/);
  assert.equal(rows(output, 'wired-alias').length, 0);
  assert.equal(rows(output, 'apps/wired link').length, 0);
});

write(path.join(workspace, 'apps', 'bare', 'index.html'), '<!doctype html>\n');

check('unwired project reports every missing piece and fails', () => {
  const output = run([], 1);
  const bare = rows(output, 'apps/bare').join('\n');
  for (const item of ['AGENTS.md', 'CLAUDE.md', 'Codex trust', 'README row']) {
    assert.match(bare, new RegExp(`${item.replace('.', '\\.')}\\s+MISSING`));
  }
  assert.match(bare, /git\s+WARN/);
});

check('claude target skips Codex trust', () => {
  const output = run(['-Target', 'claude'], 1);
  assert.doesNotMatch(output, /Codex trust/);
  assert.match(rows(output, 'apps/bare').join('\n'), /CLAUDE\.md\s+MISSING/);
});

write(path.join(workspace, 'apps', 'bare', 'AGENTS.md'), '# Bare\n');
write(path.join(workspace, 'CLAUDE.md'), '@AGENTS.md\n');

check('missing workflow pointer and workspace import are reported', () => {
  const output = run(['-Target', 'claude'], 1);
  assert.match(rows(output, 'apps/bare').join('\n'), /AGENTS\.md\s+MISSING no PROJECT-WORKFLOW\.md pointer/);
  assert.match(output, /CLAUDE\.md import\s+MISSING/);
});

console.log(`${passed} projects-doctor checks passed. Fixture retained at ${fixture}`);
