var ModelField, ModelFieldTree;

ModelField = require('./modelField');

module.exports = ModelFieldTree = class ModelFieldTree extends ModelField {
  initialize() {
    this.setDefault('value', []);
    return super.initialize({
      objectMode: true
    });
  }

  option(...optionParams) {
    var optionObject;
    optionObject = this.buildParamObject(optionParams, ['path', 'value', 'selected']);
    if (optionObject.value == null) {
      optionObject.value = optionObject.id;
    }
    if (optionObject.value == null) {
      optionObject.value = optionObject.path.join(' > ');
    }
    optionObject.title = optionObject.path.join('>'); //use path as the key since that is what is rendered.
    return super.option(optionObject);
  }

  clear(purgeDefaults = false) {
    return this.value = purgeDefaults ? [] : this.defaultValue;
  }

};
