ModelField = require './modelField'

module.exports = class ModelFieldTree extends ModelField
  initialize: ->
    @setDefault 'value', []
    super
      objectMode: true
  option: (optionParams...) ->
    optionObject = @buildParamObject optionParams, ['path', 'value', 'selected']
    optionObject.value ?= optionObject.id
    optionObject.value ?= optionObject.path.join ' > '
    optionObject.title = optionObject.path.join '>' #use path as the key since that is what is rendered.
    super optionObject

  clear: (purgeDefaults=false) ->
    @value = if purgeDefaults then [] else @defaultValue