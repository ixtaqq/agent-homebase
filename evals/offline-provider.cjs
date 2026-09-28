// Tests evaluation plumbing only. These canned answers are not model performance evidence.
module.exports = class OfflineProvider {
  constructor(options) { this.config = options.config || {}; }
  id() { return 'offline-fixture'; }
  async callApi(prompt, context) {
    return { output: context.vars[this.config.answer || 'good'] };
  }
};
