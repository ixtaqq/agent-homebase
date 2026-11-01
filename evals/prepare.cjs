const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const cases = require('./cases.json');
const parent = path.join(root, 'logs', 'evals');
fs.mkdirSync(parent, { recursive: true });
const run = fs.mkdtempSync(path.join(parent, 'run-'));
const fixture = path.join(run, 'project');
const claudeHome = path.join(run, 'claude-home');
fs.mkdirSync(fixture);
fs.mkdirSync(claudeHome);
for (const skill of cases.map(test => test.skill)) {
  const target = path.join(fixture, '.claude', 'skills', skill);
  fs.cpSync(path.join(root, 'skills', skill), target, { recursive: true });
  // Only redirect this fixture's personal memory store; the source skill stays unchanged.
  if (skill === 'memory-keeper') {
    const file = path.join(target, 'SKILL.md');
    fs.writeFileSync(file, fs.readFileSync(file, 'utf8').replace('E:\\Workspace\\agent-homebase\\memory\\', path.join(fixture, 'memory') + path.sep));
  }
}
fs.mkdirSync(path.join(fixture, 'memory', 'entries'), { recursive: true });
fs.writeFileSync(path.join(fixture, 'memory', 'INDEX.md'), '- [finch-storage](entries/finch-storage.md) - Finch storage decision\n');
fs.writeFileSync(path.join(fixture, 'memory', 'entries', 'finch-storage.md'), 'Finch uses SQLite because the prototype must work offline.\n');
fs.writeFileSync(path.join(fixture, 'AGENTS.md'), '# Project conventions\nPreserve the Finch naming rule: public identifiers start with Finch.\n');
fs.writeFileSync(path.join(fixture, 'CLAUDE.md'), '@AGENTS.md\n');
fs.writeFileSync(path.join(fixture, 'package.json'), JSON.stringify({ private: true, scripts: { test: 'node test.cjs' } }));
fs.writeFileSync(path.join(fixture, 'test.cjs'), "console.error('FINCH_TEST_FAILURE'); process.exit(1);\n");
const init = spawnSync('git', ['init', fixture], { encoding: 'utf8' });
if (init.status !== 0) throw new Error(init.stderr);
const config = {
  description: 'Agent Homebase skill regression cases (manual, model usage required)',
  prompts: ['{{request}}'],
  providers: [{ id: 'anthropic:claude-agent-sdk', config: {
    model: process.env.EVAL_MODEL || 'sonnet',
    working_dir: fixture,
    // dontAsk denies anything that would prompt, so the cases stay read-only apart from the test run.
    permission_mode: 'dontAsk',
    append_allowed_tools: ['Bash(npm test)', 'Bash(node test.cjs)'],
    setting_sources: ['project'],
    skills: 'all',
    env: { CLAUDE_CONFIG_DIR: claudeHome },
  } }],
  evaluateOptions: { maxConcurrency: 1 },
  tests: cases.map(test => ({
    description: test.description,
    vars: { request: test.request, pattern: test.pattern },
    assert: [
      { type: 'skill-used', value: test.skill },
      { type: 'javascript', value: require('./assertion.js') },
    ],
  })),
};
const file = path.join(run, 'promptfooconfig.json');
fs.writeFileSync(file, JSON.stringify(config, null, 2));
console.log(`Prepared only; no model calls. Config: ${file}`);
console.log('After approving model usage, set ANTHROPIC_API_KEY in the environment and run:');
console.log(`npx --no-install promptfoo eval -c "${file}" --no-cache`);
