var ModelField, ModelFieldImage;

ModelField = require('./modelField');

// An image field is different enough from other fields to warrant its own subclass
module.exports = ModelFieldImage = class ModelFieldImage extends ModelField {
  initialize() {
    this.setDefault('value', {});
    this.setDefault('allowUpload', false);
    this.setDefault('imagesPerPage', 4);
    this.setDefault('minWidth', 0);
    this.setDefault('maxWidth', 0);
    this.setDefault('minHeight', 0);
    this.setDefault('maxHeight', 0);
    this.setDefault('minSize', 0);
    this.setDefault('maxSize', 0);
    this.set('optionsChanged', false); //React needs to know if the number of options changed,
    // as this requires a full reinit of the plugin at render time that is not necessary for other changes.
    return super.initialize({
      objectMode: true
    });
  }

  // Override behaviors different from other fields.
  option(...optionParams) {
    var optionObject;
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
    // use fileID as the key because this is how they are selected when rendered.
    if (optionObject.title == null) {
      optionObject.title = optionObject.fileID;
    }
    this.optionsChanged = true; //required to reinit the carousel in the ui
    return super.option(optionObject);
  }

  // image values are objects, so lookup children by fileid instead
  child(fileID) {
    var i, len, o, ref;
    if (Array.isArray(fileID)) {
      fileID = fileID.shift();
    }
    if (typeof fileID === 'object') { //if lookup by full object value
      fileID = fileID.fileID;
    }
    ref = this.options;
    for (i = 0, len = ref.length; i < len; i++) {
      o = ref[i];
      if (o.fileID === fileID) {
        return o;
      }
    }
  }

  removeOptionValue(val) {
    if (this.value.fileID === val.fileID) {
      return this.value = {};
    }
  }

  hasValue(val) {
    return val.fileID === this.value.fileID && val.thumbnailUrl === this.value.thumbnailUrl && val.fileUrl === this.value.fileUrl;
  }

  clear(purgeDefaults = false) {
    return this.value = purgeDefaults ? {} : this.defaultValue;
  }

  ensureValueInOptions() {
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
  }

};
