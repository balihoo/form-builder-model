
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
exports.modelTests = building.modelTests

#Overwrite the default error handler with the function provided.
exports.setErrorHandler = (f) ->
  globals.handleError = f

# Apply initialization data to the model.
exports.applyData = (modelObject, inData, clear, purgeDefaults) ->
  modelObject.applyData inData, clear, purgeDefaults



#Call this method before output data is needed.
exports.buildOutputData = (model) ->
  model.buildOutputData()