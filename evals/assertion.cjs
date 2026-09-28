module.exports = (output, context) => {
  const pass = new RegExp(context.vars.pattern, 'is').test(String(output));
  return { pass, score: pass ? 1 : 0, reason: pass ? 'Required evidence present' : 'Missing required evidence' };
};
