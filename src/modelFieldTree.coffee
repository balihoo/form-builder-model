ModelField = require './modelField'

module.exports = class ModelFieldTree extends ModelField
  initialize: ->
    @setDefault 'value', []
    super

  option: (optionParams...) ->
    optionObject = @buildParamObject optionParams, ['path', 'value', 'selected', 'bidAdj', 'bidAdjFlag']
    optionObject.value ?= optionObject.id
    if optionObject.value == null && Array.isArray(optionObject.path)
      optionObject.value ?= optionObject.path.join ' > '
      optionObject.title = optionObject.path.join '>' #use path as the key since that is what is rendered.
    super optionObject

  clear: (purgeDefaults=false) ->
    @value = if purgeDefaults then [] else @defaultValue