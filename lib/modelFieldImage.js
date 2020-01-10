var ModelField, ModelFieldImage,
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty,
  slice = [].slice;

ModelField = require('./modelField');

module.exports = ModelFieldImage = (function(superClass) {
  extend(ModelFieldImage, superClass);

  function ModelFieldImage() {
    return ModelFieldImage.__super__.constructor.apply(this, arguments);
  }

  ModelFieldImage.prototype.initialize = function() {
    this.setDefault('value', {});
    this.setDefault('allowUpload', false);
    this.setDefault('imagesPerPage', 4);
    this.setDefault('minWidth', 0);
    this.setDefault('maxWidth', 0);
    this.setDefault('minHeight', 0);
    this.setDefault('maxHeight', 0);
    this.setDefault('minSize', 0);
    this.setDefault('maxSize', 0);
    this.set('optionsChanged', false);
    return ModelFieldImage.__super__.initialize.apply(this, arguments);
  };

  ModelFieldImage.prototype.option = function() {
    var optionObject, optionParams;
    optionParams = 1 <= arguments.length ? slice.call(arguments, 0) : [];
    optionObject = this.buildParamObject(optionParams, ['fileID', 'fileUrl', 'thumbnailUrl']);
    if (optionObject.fileID == null) {
      optionObject.fileID = optionObject.fileUrl;
    }
    if (optionObject.thumbnailUrl == null) {
      optionObject.thumbnailUrl = optionObject.fileUrl;
    }
    optionObject.value = {
      fileID: optionObject.fileID,
      fileUrl: optionObject.fileUrl,
      thumbnailUrl: optionObject.thumbnailUrl
    };
    if (optionObject.title == null) {
      optionObject.title = optionObject.fileID;
    }
    this.optionsChanged = true;
    return ModelFieldImage.__super__.option.call(this, optionObject);
  };

  ModelFieldImage.prototype.child = function(fileID) {
    var i, len, o, ref;
    if (Array.isArray(fileID)) {
      fileID = fileID.shift();
    }
    if (typeof fileID === 'object') {
      fileID = fileID.fileID;
    }
    ref = this.options;
    for (i = 0, len = ref.length; i < len; i++) {
      o = ref[i];
      if (o.fileID === fileID) {
        return o;
      }
    }
  };

  ModelFieldImage.prototype.removeOptionValue = function(val) {
    if (this.value.fileID === val.fileID) {
      return this.value = {};
    }
  };

  ModelFieldImage.prototype.hasValue = function(val) {
    return val.fileID === this.value.fileID && val.thumbnailUrl === this.value.thumbnailUrl && val.fileUrl === this.value.fileUrl;
  };

  ModelFieldImage.prototype.clear = function(purgeDefaults) {
    if (purgeDefaults == null) {
      purgeDefaults = false;
    }
    return this.value = purgeDefaults ? {} : this.defaultValue;
  };

  ModelFieldImage.prototype.ensureValueInOptions = function() {
    var existingOption, i, len, o, ref;
    ref = this.options;
    for (i = 0, len = ref.length; i < len; i++) {
      o = ref[i];
      if (o.attributes.fileID === this.value.fileID) {
        existingOption = o;
      }
    }
    if (!existingOption) {
      return this.option(this.value);
    }
  };

  return ModelFieldImage;

})(ModelField);
