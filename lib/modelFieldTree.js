var ModelField, ModelFieldTree,
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty,
  slice = [].slice;

ModelField = require('./modelField');

module.exports = ModelFieldTree = (function(superClass) {
  extend(ModelFieldTree, superClass);

  function ModelFieldTree() {
    return ModelFieldTree.__super__.constructor.apply(this, arguments);
  }

  ModelFieldTree.prototype.initialize = function() {
    this.setDefault('value', []);
    return ModelFieldTree.__super__.initialize.apply(this, arguments);
  };

  ModelFieldTree.prototype.option = function() {
    var optionObject, optionParams;
    optionParams = 1 <= arguments.length ? slice.call(arguments, 0) : [];
    optionObject = this.buildParamObject(optionParams, ['path', 'value', 'selected', 'bidAdj', 'bidAdjFlag']);
    if (optionObject.value == null) {
      optionObject.value = optionObject.id;
    }
    if (optionObject.value == null) {
      optionObject.value = optionObject.path.join(' > ');
    }
    optionObject.title = optionObject.path.join('>');
    return ModelFieldTree.__super__.option.call(this, optionObject);
  };

  ModelFieldTree.prototype.clear = function(purgeDefaults) {
    if (purgeDefaults == null) {
      purgeDefaults = false;
    }
    return this.value = purgeDefaults ? [] : this.defaultValue;
  };

  return ModelFieldTree;

})(ModelField);
