
ModelBase = require './modelBase'
ModelFieldImage = require './modelFieldImage'
ModelFieldTree = require './modelFieldTree'
ModelFieldDate = require './modelFieldDate'
ModelField = require './modelField'
globals = require './globals'

###
  A ModelGroup is a model object that can contain any number of other groups and fields
###
module.exports = class ModelGroup extends ModelBase
  modelClassName: 'ModelGroup'
  initialize: ->
    @setDefault 'children', []
    @setDefault 'root', @
    @set 'isValid', true
    @set 'data', null

    super

  postBuild: ->
    child.postBuild() for child in @children

  field: (fieldParams...) ->
    fieldObject = @buildParamObject fieldParams, ['title', 'name', 'type', 'value']

    #Could move this to a factory, but fields should only be created here so probably not necessary.
    fld = switch fieldObject.type
      when 'image'
        new ModelFieldImage fieldObject
      when 'tree'
        new ModelFieldTree fieldObject
      when 'date'
        new ModelFieldDate fieldObject
      else
        new ModelField fieldObject

    @children.push fld
    @trigger 'change'
    return fld

  group: (groupParams...) ->
    grp = {}
    if groupParams[0].constructor?.name is 'ModelGroup'
      grp = groupParams[0].cloneModel(@root)
      #set any other supplied params on the clone
      groupParams.shift() #remove the cloned object
      groupObject = @buildParamObject groupParams, ['title', 'name', 'description']
      groupObject.name ?= groupObject.title
      groupObject.title ?= groupObject.name
      for key,val of groupObject
        grp.set(key, val)
    else
      groupObject = @buildParamObject groupParams, ['title', 'name', 'description']
      if groupObject.repeating
        grp = new RepeatingModelGroup groupObject
      else
        grp = new ModelGroup groupObject

    @children.push grp
    @trigger 'change'
    return grp

  # find a child by name.
  # can also find descendants multiple levels down by supplying one of
  # * an array of child names (in order) eg: group.child(['childname','grandchildname','greatgrandchildname'])
  # * a dot or slash delimited string. eg: group.child('childname.grandchildname.greatgrandchildname')
  child: (path) ->
    if not (Array.isArray path)
      path = path.split /[./]/
    name = path.shift()
    child = c for c in @children when c.name is name

    if path.length is 0
      child
    else
      child.child path


  setDirty: (id, whatChanged) ->
    child.setDirty id, whatChanged for child in @children
    super id, whatChanged

  setClean: (all) ->
    super
    if all
      child.setClean all for child in @children

  recalculateRelativeProperties: (collection = @children) ->
    dirty = @dirty
    super
    #group is valid if all children are valid
    #might not need to check validy, but always need to recalculate all children anyway.
    newValid = true
    for child in collection
      child.recalculateRelativeProperties()
      newValid &&= child.isValid
    @isValid = newValid

  buildOutputData: (group = @) ->
    obj = {}
    group.children.forEach (child) ->
      childData = child.buildOutputData()
      unless childData is undefined # undefined values do not appear in output, but nulls do
        obj[child.name] = childData
    obj

  buildOutputDataString: ->
    JSON.stringify @buildOutputData()

  clear: (purgeDefaults=false) ->
    #reset the 'data' object in-place, so model code will see an empty object too.
    if @data
      delete @data[key] for key in Object.keys @data
    child.clear purgeDefaults for child in @children

  applyData: (inData, clear=false, purgeDefaults=false) ->
    @clear purgeDefaults if clear
    ###
    This section preserves a link to the initially applied data object and merges subsequent applies on top
      of it in-place.  This is necessary for two reasons.
    First, the scope of the running model code also references the applied data through the 'data' variable.
      Every applied data must be available even though the runtime is not re-evaluated each time.
    Second, templated fields use this data as the input to their Mustache evaluation. See @renderTemplate()
    ###
    if @data
      globals.mergeData @data, inData
      @trigger 'change'
    else
      @data = inData

    for key, value of inData
      @child(key)?.applyData value



###
  Encapsulates a group of form objects that can be added or removed to the form together multiple times
###
class RepeatingModelGroup extends ModelGroup
  modelClassName: 'RepeatingModelGroup'
  initialize: ->
    @setDefault 'defaultValue', @get('value') or []
    @set 'value', []

    super

  postBuild: ->
    c.postBuild() for c in @children
    @clear() # Apply the defaultValue for the repeating model group after it has been built

  setDirty: (id, whatChanged) ->
    val.setDirty id, whatChanged for val in @value
    super id, whatChanged

  setClean: (all) ->
    super
    if all
      val.setClean all for val in @value

  recalculateRelativeProperties: ->
    #ignore validity/visibility of children, only value instances
    super @value

  buildOutputData: ->
    @value.map (instance) ->
      super instance #build output data of each value as a group, not repeating group

  clear: (purgeDefaults=false) ->
    @value = []

    unless purgeDefaults
      @applyData @defaultValue if @defaultValue

  applyData: (inData, clear=false, purgeDefaults=false) ->
    # always clear out and replace the model value when data is supplied
    if inData
      @value = []
    else
      @clear purgeDefaults if clear

    #each value in the repeating group needs to be a repeating group object, not just the anonymous object in data
    #add a new repeating group to value for each in data, and apply data like with a model group
    for obj in inData
      added = @add()
      for key,value of obj
        added.child(key)?.applyData value, clear, purgeDefaults

  add: ->
    clone = @cloneModel @root, ModelGroup
    clone.title = '' #don't display group name on every repeated group
    clone.value = []
    @value.push clone
    @trigger 'change'
    clone

  delete: (index) ->
    @value.splice(index, 1)
    @trigger 'change'
