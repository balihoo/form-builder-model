var Backbone, ModelBase, building, globals;

if (typeof window !== "undefined" && window !== null) {
  window.formbuilder = exports;
}

Backbone = require('backbone');

ModelBase = require('./modelBase');

building = require('./building');

globals = require('./globals');

exports.fromCode = building.fromCode;

exports.fromCoffee = building.fromCoffee;

exports.fromPackage = building.fromPackage;

exports.getChanges = building.getChanges;

exports.mergeData = globals.mergeData;

exports.applyData = function(modelObject, inData, clear, purgeDefaults) {
  return modelObject.applyData(inData, clear, purgeDefaults);
};

exports.buildOutputData = function(model) {
  return model.buildOutputData();
};

Object.defineProperty(exports, 'modelTests', {
  get: function() {
    return building.modelTests;
  }
});

Object.defineProperty(exports, 'handleError', {
  get: function() {
    return globals.handleError;
  },
  set: function(f) {
    return globals.handleError = f;
  },
  enumerable: true
});
