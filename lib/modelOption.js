var ModelBase, ModelOption,
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty;

ModelBase = require('./modelBase');

module.exports = ModelOption = (function(superClass) {
  extend(ModelOption, superClass);

  function ModelOption() {
    return ModelOption.__super__.constructor.apply(this, arguments);
  }

  ModelOption.prototype.initialize = function() {
    this.setDefault('value', this.get('title'));
    this.setDefault('title', this.get('value'));
    this.setDefault('selected', false);
    this.setDefault('path', []);
    ModelOption.__super__.initialize.apply(this, arguments);
    return this.on('change:selected', function() {
      if (this.selected) {
        return this.parent.addOptionValue(this.value, this.bidAdj, this.bidAdjFlag);
      } else {
        return this.parent.removeOptionValue(this.value, this.bidAdjFlag);
      }
    });
  };

  return ModelOption;

})(ModelBase);
