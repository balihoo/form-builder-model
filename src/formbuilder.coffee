
window?.formbuilder = exports

Backbone     = require 'backbone'
ModelBase    = require './modelBase'
building     = require './building'
globals = require './globals'

exports.fromCode = building.fromCode
exports.fromCoffee = building.fromCoffee
exports.fromPackage = building.fromPackage
exports.getChanges = building.getChanges
exports.mergeData = globals.mergeData

# Apply initialization data to the model.
exports.applyData = (modelObject, inData, clear, purgeDefaults) ->
  modelObject.applyData inData, clear, purgeDefaults

#Call this method before output data is needed.
exports.buildOutputData = (model) ->
  model.buildOutputData()

Object.defineProperty exports, 'modelTests',
  get: -> building.modelTests
    
# We want users to be able to set a new handleError function.  Rather than setting this
# module's handleError function to the current value in global.handleError, we make the
# setter overwrite the function reference in globals rather than the function reference
# in this file.
Object.defineProperty exports, 'handleError',
  get: -> globals.handleError
  set: (f) -> globals.handleError = f
  enumerable: true