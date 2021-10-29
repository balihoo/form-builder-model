var ModelBase, ModelOption;

ModelBase = require('./modelBase');

module.exports = ModelOption = class ModelOption extends ModelBase {
  initialize() {
    this.setDefault('value', this.get('title'));
    // No two options on a field should have the same title.  This would be confusing during render.
    // Even if not rendered, title can be used as primary key to determine when duplicate options should be avoided.
    this.setDefault('title', this.get('value'));
    // selected is used to set default value and also to store current value.
    this.setDefault('selected', false);
    // set default bid adjustment
    this.setDefault('path', []); //for tree. Might should move to subclass
    super.initialize({
      objectMode: true
    });
    // if selected is changed, make sure parent matches
    // this change likely comes from parent value changing, so be careful not to infinitely recurse.
    return this.on('change:selected', function() {
      if (this.selected) {
        return this.parent.addOptionValue(this.value, this.bidAdj); // not selected
      } else {
        return this.parent.removeOptionValue(this.value);
      }
    });
  }

};
