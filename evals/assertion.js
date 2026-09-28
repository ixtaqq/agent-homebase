// Embed the shared scorer as JavaScript source for Promptfoo's assertion evaluator.
module.exports = 'return (' + require('./assertion.cjs').toString() + ')(output, context);';
