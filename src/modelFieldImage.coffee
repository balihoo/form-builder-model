ModelField = require './modelField'

# An image field is different enough from other fields to warrant its own subclass
module.exports = class ModelFieldImage extends ModelField
  initialize: ->
    @setDefault 'value', {}
    @setDefault 'allowUpload', false
    @setDefault 'imagesPerPage', 4
    @setDefault 'minWidth', 0
    @setDefault 'maxWidth', 0
    @setDefault 'minHeight', 0
    @setDefault 'maxHeight', 0
    @setDefault 'minSize', 0
    @setDefault 'maxSize', 0
    @set 'optionsChanged', false #React needs to know if the number of options changed,
    # as this requires a full reinit of the plugin at render time that is not necessary for other changes.
    super

  # Override behaviors different from other fields.

  option: (optionParams...) ->
    optionObject = @buildParamObject optionParams, ['fileID', 'fileUrl', 'thumbnailUrl','fileContentype']
    optionObject.fileID ?= optionObject.fileUrl
    optionObject.thumbnailUrl ?= optionObject.fileUrl
    optionObject.fileContentype ?= optionObject.fileContentype

    optionObject.value = {
      fileID: optionObject.fileID
      fileUrl: optionObject.fileUrl
      thumbnailUrl: optionObject.thumbnailUrl
      fileContentype: optionObject.fileContentype
    }
    # use fileID as the key because this is how they are selected when rendered.
    optionObject.title ?= optionObject.fileID
    @optionsChanged = true #required to reinit the carousel in the ui
    super optionObject

  # image values are objects, so lookup children by fileid instead
  child: (fileID) ->
    if Array.isArray fileID
      fileID = fileID.shift()
    if typeof fileID is 'object' #if lookup by full object value
      fileID = fileID.fileID
    return o for o in @options when o.fileID is fileID

  removeOptionValue: (val) ->
    if @value.fileID is val.fileID
      @value = {}

  hasValue: (val) ->
    val.fileID is @value.fileID and
        val.thumbnailUrl is @value.thumbnailUrl and
        val.fileUrl is @value.fileUrl and
        val.fileContentype is @value.fileContentype

  clear: (purgeDefaults=false) ->
    @value = if purgeDefaults then {} else @defaultValue

  ensureValueInOptions: ->
    existingOption = o for o in @options when o.attributes.fileID is @value.fileID
    unless existingOption
      @option @value