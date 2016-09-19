
window?.formbuilder = exports

CoffeeScript = require 'coffee-script'
Backbone     = require 'backbone'
_            = require 'underscore'
Mustache     = require 'mustache'
vm           = require 'vm'
jiff         = require 'jiff'
moment       = require 'moment'

# generate a new, unqiue identifier. Mostly good for label.
newid = (->
  incId = 0
  ->
    incId++
    "fbid_#{incId}"
)()

makeErrorMessage = (model, propName, err)->
  stack = []
  node  = model

  while node.name?
    stack.push node.name
    node = node.parent

  stack.reverse()

  nameStack = stack.join '.'

  "The '#{propName}' function belonging to the
  field named '#{nameStack}' threw an error with the message '#{err.message}'"

if alert?
  throttledAlert = _.throttle alert, 500

# Determine what to do in the case of any error, including during compile, build and dynamic function calls.
# Any client may overwrite this method to handle errors differently, for example displaying them to the user
exports.handleError = (err) ->
  if err not instanceof Error
    err = new Error err
  throw err

# Apply initialization data to the model.
exports.applyData = (modelObject, inData, clear, purgeDefaults) ->
  modelObject.applyData inData, clear, purgeDefaults

# Merge data objects together.
# Modifies and returns the first parameter
exports.mergeData = (a, b)->
  if b?.constructor is Object
    for key, value of b
      if a[key]? and a[key].constructor is Object and value?.constructor is Object
        exports.mergeData a[key], value
      else
        a[key] = value
  a

runtime = false
exports.modelTests= []

# Creates a Model object from JS code.  The executed code will execute in a
# root ModelGroup
# code - model code
# data - initialization data (optional). Object or stringified object
# element - jquery element for firing validation events (optional)
# imports - object mapping {varname : model object}. May be referenced in form code
exports.fromCode = (code, data, element, imports, isImport)->
  data = switch typeof data
    when 'object' then JSON.parse JSON.stringify data #copy it
    when 'string' then JSON.parse data
    else {} # 'undefined', 'null', and other unsupported types
  runtime = false
  exports.modelTests = []
  test = (func) -> exports.modelTests.push func
  assert = (bool, message="A model test has failed") ->
    if not bool then exports.handleError message

  emit = (name, context) ->
    if element and $
      element.trigger $.Event name, context

  newRoot = new ModelGroup()
  #dont recalculate until model is done creating
  newRoot.recalculating = false
  newRoot.recalculateCycle = ->

  do (root = null) -> #new scope for root variable name

    field    = newRoot.field.bind(newRoot)
    group    = newRoot.group.bind(newRoot)
    root     = newRoot.root
    validate = newRoot.validate

    #running in a vm is safer, but slower.  Let the browser do plain eval, but not server.
    if not window?
      sandbox = #hooks available in form code
        field: field
        group: group
        root: root
        validate: validate
        data: data
        imports: imports
        test: test
        assert: assert
        Mustache: Mustache
        emit: emit
        _:_
        console:#console functions don't break, but don't do anything
          log:->
          error:->
        print:->
      vm.runInNewContext '"use strict";' + code, sandbox
    else
      eval '"use strict";' + code

  newRoot.postBuild()
  runtime = true
  
  newRoot.applyData data

  newRoot.getChanges = exports.getChanges.bind null, newRoot

  newRoot.setDirty newRoot.id, 'multiple'

  newRoot.recalculateCycle = ->
    while !@recalculating and @dirty
      @recalculating = true
      @recalculateRelativeProperties()
      @recalculating = false
      
  newRoot.recalculateCycle()

  newRoot.on 'change:isValid', ->
    unless isImport
      emit 'validate', isValid:newRoot.isValid

  newRoot.on 'recalculate', ->
    unless isImport
      emit 'change'
  newRoot.trigger 'change:isValid'
  newRoot.trigger 'recalculate'


  return newRoot

# CoffeeScript counterpart to fromCode.  Compiles the given code to JS
# and passes it to fromCode.
exports.fromCoffee = (code, data, element, imports, isImport)->
  return exports.fromCode (CoffeeScript.compile code), data, element, imports, isImport

# Build a model from a package object, consisting of
# - formid (int or string)
# - forms (array of object).  Each object contains
# - - formid (int)
# - - model (string) coffeescript model code
# - - imports (array of object).  Each object contains
# - - - importformid (int)
# - - - namespace (string)
# - data (object, optional)
# data may also be supplied as the second parameter to the function. Data in this parameter
#   will override any matching keys provided in the package data
# element to which to bind validation and change messages, also optional
exports.fromPackage = (pkg, data, element) ->
  buildModelWithRecursiveImports = (p, el, isImport) ->
    form = (f for f in p.forms when f.formid is p.formid)[0]
    return if !form?

    builtImports = {}
    buildImport = (impObj) ->
      builtImports[impObj.namespace] = buildModelWithRecursiveImports({
        formid: impObj.importformid
        data: data
        forms: p.forms
      }, element, true)

    if form.imports #in case imports left off the package
      form.imports.forEach(buildImport)

    return exports.fromCoffee form.model, data, el, builtImports, isImport

  if (typeof pkg.formid is 'string')
    pkg.formid = parseInt pkg.formid
  #data could be in the package and/or as a separate parameter.  Extend them together.
  data = _.extend pkg.data or {}, data or {}
  return buildModelWithRecursiveImports pkg, element, false

exports.getChanges = (modelAfter, beforeData) ->
  modelBefore = modelAfter.cloneModel()
  modelBefore.applyData(beforeData, true)

  patch = jiff.diff modelBefore.buildOutputData(), modelAfter.buildOutputData(), invertible:false
  #array paths end in an index #. We only want the field, not the index of the value
  changedPaths = (p.path.replace(/\/[0-9]+$/, '') for p in patch)
  #get distinct field names. Arrays for example might appear multiple times
  changedPathsUniqObject = {}
  changedPathsUniqObject[val] = val for val in changedPaths
  changedPathsUnique = (key for key of changedPathsUniqObject)

  changes = []
  for changedPath in changedPathsUnique
    path = changedPath[1..-1] #don't need that initial separator
    before = modelBefore.child path
    after = modelAfter.child path
    if before?.value isnt after?.value
      changes.push
        name:changedPath
        title:after.title
        before:before.buildOutputData()
        after:after.buildOutputData()
  {
    changes:changes
    patch: patch
  }


###
# Attributes common to groups and fields.
###
class ModelBase extends Backbone.Model
  modelClassName: 'ModelBase'
  initialize: ->
    @setDefault 'visible', true
    @set 'isVisible', true
    @setDefault 'onChangePropertiesHandlers', []
    @set 'id', newid()
    @setDefault 'parent', undefined
    @setDefault 'root', undefined
    @setDefault 'name', @get 'title'
    @setDefault 'title', @get 'name'

    #add accessors for each name access instead of get/set
    for key,val of @attributes
      do (key) =>
        Object.defineProperty @, key, {
          get: ->
            @get key
          set: (newValue) ->
            if (@get key) isnt newValue #save an onChange event if value isnt different
              @set key, newValue
        }

    @bindPropFunctions 'visible'
    @makePropArray 'onChangePropertiesHandlers'
    @bindPropFunctions 'onChangePropertiesHandlers'

    # Other fields may need to update visibility, validity, etc when this field changes.
    # Fire an event on change, and catch those events fired by others.
    @on 'change', ->
      return unless runtime
      # model onChangePropertiesHandlers functions
      for changeFunc in @onChangePropertiesHandlers
        changeFunc()

      ch = @changedAttributes()
      if ch is false #no changes, manual trigger meant to fire everything
        ch = 'multiple'

      @root.setDirty @id, ch
      @root.recalculateCycle()

  postBuild: ->

  setDefault: (field, val) ->
    if not @get(field)?
      @set field, val

  text: (message)->
    @field message, type: 'info'

  #note: doesn't set the variable locally, just creates a bound version of it
  bindPropFunction: (propName, func)->
    model = @
    ->
      try
        if @ instanceof ModelBase
          model = @
        func.apply model, arguments
      catch err
        message = makeErrorMessage model, propName, err
        exports.handleError message

  # bind properties that are functions to this object's context. Single functions or arrays of functions
  bindPropFunctions: (propName) ->
    if Array.isArray @[propName]
      for index in [0...@[propName].length]
        @[propName][index] = @bindPropFunction propName, @[propName][index]
    else if typeof @[propName] is 'function'
      @set propName, @bindPropFunction(propName, @[propName]), silent:true

  # ensure a property is array type, for when a single value is supplied where an array is needed.
  makePropArray: (propName) ->
    if not Array.isArray @get propName
      @set propName, [@get propName]

  # convert list of params, either object(s) or positional strings (or both), into an object
  # and add a few common properties
  # assumes always called by creator of child objects, and thus sets parent to this
  buildParamObject: (params, paramPositions) ->
    paramObject = {}
    paramIndex = 0
    for param in params
      if typeof param in ['string', 'number', 'boolean'] or Array.isArray param
        paramObject[paramPositions[paramIndex++]] = param
      else if Object.prototype.toString.call(param) is '[object Object]'
        for key, val of param
          paramObject[key] = val
    paramObject.parent = @ #not a param, but common to everything that uses this method
    paramObject.root = @root
    paramObject

  dirty: '' #do as a local string not attribute so it is not included in @changed
  # set the dirty flag according to an object with all current changes
  # or, whatChanged could be a string to set as the dirty value
  setDirty: (id, whatChanged) ->
    ch =
      if typeof whatChanged is 'string'
        whatChanged
      else
        keys = Object.keys(whatChanged)
        if keys.length is 1 then "#{id}:#{keys[0]}" else 'multiple'

    drt = if @dirty is ch or @dirty is '' then ch else "multiple"
    @dirty = drt
  setClean: ->
    @dirty = ''

  shouldCallTriggerFunctionFor: (dirty, attrName) ->
    dirty and dirty isnt "#{@id}:#{attrName}"

  # Any local properties that may need to recalculate if a foreign field changes.
  recalculateRelativeProperties: ->
    dirty = @dirty
    @setClean()

    # visibility
    if @shouldCallTriggerFunctionFor dirty, 'isVisible'
      @isVisible = getVisible @visible

    @trigger 'recalculate'

  # Add a new change properties handler to this object.
  # This change itself will trigger on change properties functions to run, including the just-added one!
  # If this trigger is not desired, set the second property to false
  onChangeProperties: (f, trigger = true) ->
    @onChangePropertiesHandlers.push @bindPropFunction 'onChangeProperties', f
    @trigger 'change' if trigger
    @

  # Built-in functions for checking validity.
  validate:
    required: (value = @value or '')->
      if (switch typeof value
        when 'number', 'boolean' then false #these types cannot be empty
        when 'string' then value.length is 0
        when 'object' then Object.keys(value).length is 0
        else true) #null, undefined
        return "This field is required"
    minLength: (n)-> (value = @value or '')->
      if value.length < n
        return "Must be at least #{n} characters long"
    maxLength: (n)-> (value = @value or '')->
      if value.length > n
        return "Can be at most #{n} characters long"
    number: (value = @value or '')->
      if isNaN(+value)
        return "Must be an integer or decimal number. (ex. 42 or 1.618)"
    date: (value = @value or '', format = @format) ->
      return if value is ''
      unless moment(value, format, true).isValid()
        "Not a valid date or does not match the format #{format}"
    email: (value = @value or '')->
      if not value.match /// ^
        [a-z0-9!\#$%&'*+/=?^_`{|}~-]+
          (?:\.[a-z0-9!\#$%&'*+/=?^_`{|}~-]+)*
          @
          (?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+
          [a-z0-9]
          (?:[a-z0-9-]*[a-z0-9])?
        $ ///
        return "Must be a valid email"
    url: (value = @value or '')->
      if not value.match /// ^
        (
          ([A-Za-z]{3,9}:(?:\/\/)?)
          (?:[-;:&=\+\$,\w]+@)?
          [A-Za-z0-9.-]+
        | (?:www.|[-;:&=\+\$,\w]+@)
          [A-Za-z0-9.-]+
        )
        (
          (?:\/[\+~%\/.\w-_]*)?
          \??
          (?:[-\+=&;%@.\w_]*)
          \#?
          (?:[\w]*)
        )?
        $ ///
        return "Must be a URL"
    dollars: (value = @value or '')->
      if not value.match /^\$(\d+\.\d\d|\d+)$/
        return "Must be a dollar amount (ex. $3.99)"
    minSelections: (n)-> (value = @value or '')->
      if value.length < n
        return "Please select at least #{n} options"
    maxSelections: (n)-> (value = @value or '')->
      if value.length > n
        return "Please select at most #{n} options"
    selectedIsVisible: (field = @) ->
      for opt in field.options
        if opt.selected and not opt.isVisible
          return "A selected option is not currently available.  Please make a new choice from available options."
    template: -> #ensure the template field contains valid mustache
      return unless @template
      if typeof @template is 'object'
        template = @template.value
      else
        template = @parent.child(@template).value
      try
        Mustache.render template, @root.data
        return
      catch e
        "Template field does not contain valid Mustache"

  #Deep copy this backbone model by creating a new one with the same attributes.
  #Overwrite each root attribute with the new root in the cloning form.
  cloneModel: (newRoot = @root, constructor = @constructor) ->
    myClone = new constructor(@attributes)

    #some attributes need to be deep copied
    for key,val of myClone.attributes
      #attributes that are form model objects need to themselves be cloned
      if key is 'root'
        myClone.set(key, newRoot)
      else if val instanceof ModelBase and key not in ['root','parent']
        myClone.set(key, val.cloneModel(newRoot))
      else if Array.isArray val
        newVal = []
        #array of form model objects, each needs to be cloned. Don't clone value objects
        if val[0] instanceof ModelBase and key isnt 'value'
          for modelObj in val
            childClone = modelObj.cloneModel(newRoot)
            #and if children/options are cloned, update their parent to this new object
            if childClone.parent is @
              childClone.parent = myClone
              if key is 'options' and childClone.selected
                myClone.addOptionValue childClone.value
            newVal.push childClone
        else
          newVal = _.clone(val)
        myClone.set(key, newVal)
    myClone

###
  A ModelGroup is a model object that can contain any number of other groups and fields
###
class ModelGroup extends ModelBase
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
      exports.mergeData @data, inData
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


###
  A ModelField represents a model object that render as a DOM field
  NOTE: The following field types are subclasses: image, tree, date
###
class ModelField extends ModelBase
  modelClassName: 'ModelField'
  initialize: ->
    @setDefault 'type', 'text'
    @setDefault 'options', []
    @setDefault 'value', switch @get 'type'
      when 'multiselect' then []
      when 'bool' then false
      when 'info', 'button' then undefined
      else (@get 'defaultValue') or ''
    @setDefault 'defaultValue', @get 'value' #used for control type and clear()
    @set 'isValid', true
    @setDefault 'validators', []
    @setDefault 'onChangeHandlers', []
    @setDefault 'dynamicValue', null
    @setDefault 'template', null
    @setDefault 'autocomplete', null
    @setDefault 'disabled', false

    super

    #difficult to catch bad types at render time.  error here instead
    if @type not in ['info', 'text', 'url', 'email', 'tel', 'time', 'date', 'textarea',
                     'bool', 'tree', 'color', 'select', 'multiselect', 'image', 'button', 'number']
      return exports.handleError "Bad field type: #{@type}"

    @bindPropFunctions 'dynamicValue'

    # multiselects are arrays, others are strings.  If typeof value doesn't match, convert it.
    while (Array.isArray @value) and (@type isnt 'multiselect') and (@type isnt 'tree') and (@type isnt 'button')
      @value = @value[0]

    if typeof @value is 'string' and (@type is 'multiselect')
      @value = [@value]

    #bools are special too.
    if @type is 'bool' and typeof @value isnt 'bool'
      @value = not not @value #convert to bool
      
    @makePropArray 'validators'
    @bindPropFunctions 'validators'

    #onChangeHandlers functions for field value changes only.  For any property change, use onChangePropertiesHandlers
    @makePropArray 'onChangeHandlers'
    @bindPropFunctions 'onChangeHandlers'
    
    if @optionsFrom?
      if !@optionsFrom.url? or !@optionsFrom.parseResults?
        return exports.handleError 'When fetching options remotely, both url and parseResults properties are required'
      if typeof @optionsFrom?.url is 'function'
        @optionsFrom.url = @bindPropFunction 'optionsFrom.url', @optionsFrom.url
      if typeof @optionsFrom.parseResults isnt 'function'
        return exports.handleError 'optionsFrom.parseResults must be a function'
      @optionsFrom.parseResults = @bindPropFunction 'optionsFrom.parseResults', @optionsFrom.parseResults

    @updateOptionsSelected()

    @on 'change:value', ->
      for changeFunc in @onChangeHandlers
        changeFunc()
      @updateOptionsSelected()

    # if type changes, need to update value
    @on 'change:type', ->
      if @type is 'multiselect'
        @value = if @value.length > 0 then [@value] else []
      else if @previousAttributes().type is 'multiselect'
        @value = if @value.length > 0 then @value[0] else ''
      # must be *select if options present
      if @options.length > 0 and not (@type in ['select', 'multiselect'])
        @type = 'select'

  getOptionsFrom: ->
    return if !@optionsFrom?
    
    url =
      if typeof @optionsFrom.url is 'function'
        @optionsFrom.url()
      else
        @optionsFrom.url
    if @prevUrl is url
      return
    @prevUrl = url

    window?.formbuilderproxy?.getFromProxy {
      url: url
      method: @optionsFrom.method or 'get'
      headerKey: @optionsFrom.headerKey
    }, (error, data) =>
      if error
        return exports.handleError makeErrorMessage @, 'optionsFrom', error
      mappedResults = @optionsFrom.parseResults data
      if not Array.isArray mappedResults
        return exports.handleError 'results of parseResults must be an array of option parameters'
      @options = []
      @option opt for opt in mappedResults

  validityMessage: undefined
  field: (obj...) ->
    @parent.field obj...

  group: (obj...) ->
    @parent.group obj...

  option: (optionParams...) ->
    optionObject = @buildParamObject optionParams, ['title', 'value', 'selected']

    # when adding an option to a field, make sure it is a *select type
    if not (@type in ['select','multiselect','image','tree'])
      @type = 'select'
      
    # If this option already exists, replace.  Otherwise append
    nextOpts = (opt for opt in @options when opt.title isnt optionObject.title)
    newOption = new ModelOption optionObject
    nextOpts.push newOption
    @options = nextOpts

    #if new option has selected:true, set this field's value to that
    #don't remove from parent value if not selected. Might be supplied by field value during creation.
    if newOption.selected
      @addOptionValue newOption.value
    @ #return the field so we can chain .option calls
  
  postBuild: ->
    # options may have changed the starting value, so update the defaultValue to that
    @defaultValue = @value #todo: NO! need to clone this in case value isnt primitive
    #update each option's selected status to match the field value
    @updateOptionsSelected()

  updateOptionsSelected: ->
    for opt in @options
      opt.selected = @hasValue opt.value

  # find an option by value.  Uses the same child method as groups and fields to find constituent objects
  child: (value) ->
    if Array.isArray value
      value = value.shift()
    return o for o in @options when o.value is value

  # add a new validator function
  validator: (func) ->
    @validators.push @bindPropFunction 'validator', func
    @trigger 'change'
    @

  # add a new onChangeHandler function that triggers when the field's value changes
  onChange: (f) ->
    @onChangeHandlers.push @bindPropFunction 'onChange', f
    @trigger 'change'
    @

  setDirty: (id, whatChanged) ->
    opt.setDirty id, whatChanged for opt in @options
    super id, whatChanged

  setClean: (all) ->
    super
    if all
      opt.setClean all for opt in @options

  recalculateRelativeProperties: ->
    dirty = @dirty
    super

    # validity
    # only fire if isValid changes.  If isValid stays false but message changes, don't need to re-fire.
    if @shouldCallTriggerFunctionFor dirty, 'isValid'
      validityMessage = undefined
      #certain validators are automatic on fields with certain properties
      if @template
        validityMessage or= @validate.template.call @
      if @type is 'number'
        validityMessage or= @validate.number.call @
      #if no problems yet, try all the user-defined validators
      unless validityMessage
        for validator in @validators
          if typeof validator is 'function'
            validityMessage = validator.call @
          if typeof validityMessage is 'function'
            return exports.handleError "A validator on field '#{@name}' returned a function"
          if validityMessage then break
      @validityMessage = validityMessage
      @set isValid: not validityMessage?
    
    # Fields with a template property can't also have a dynamicValue property.
    if @template and @shouldCallTriggerFunctionFor dirty, 'value'
      @renderTemplate()
    else
      #dynamic value
      if typeof @dynamicValue is 'function' and @shouldCallTriggerFunctionFor dirty, 'value'
        value = @dynamicValue()

        if typeof value is 'function'
          return exports.handleError "dynamicValue on field '#{@name}' returned a function"

        @set 'value', value

    if @shouldCallTriggerFunctionFor dirty, 'options'
      @getOptionsFrom()

    for opt in @options
      opt.recalculateRelativeProperties()

  addOptionValue: (val) ->
    if @type in ['multiselect','tree']
      if not (val in @value)
        @value.push val
    else #single-select
      @value = val

  removeOptionValue: (val) ->
    if @type in ['multiselect','tree']
      if val in @value
        @value = @value.filter (v) -> v isnt val
    else if @value is val #single-select
      @value = ''

  #determine if the value is or contains the provided value.
  hasValue: (val) ->
    if @type in ['multiselect','tree']
      val in @value
    else
      val is @value

  buildOutputData: ->
    switch @type
      when 'number'
        out = +@value
        if isNaN out then null else out
      when 'info', 'button' then undefined
      when 'bool' then not not @value
      else @value
      
  clear: (purgeDefaults=false) ->
    if purgeDefaults
      @value = switch @type
        when 'multiselect' then []
        when 'bool' then false
        else ''
    else
      @value = @defaultValue

  ensureValueInOptions: ->
    return unless @type in ['select','multiselect','image']
    if typeof @value is 'string'
      existingOption = o for o in @options when o.value is @value
      unless existingOption
        @option @value
    else if Array.isArray @value
      for v in @value
        existingOption = o for o in @options when o.value is v
        unless existingOption
          @option v

  applyData: (inData, clear=false, purgeDefaults=false) ->
    @clear purgeDefaults if clear
    if inData?
      @value = inData
      @ensureValueInOptions()

  renderTemplate: () ->
    if typeof @template is 'object'
      template = @template.value
    else
      template = @parent.child(@template).value
    try
      @value = Mustache.render template, @root.data
    catch #just don't crash. Validator will display error later.

    

class ModelFieldDate extends ModelField
  initialize: ->
    @setDefault 'format', 'M/D/YYYY'
    super
    @validator @validate.date
    
  # Convert date to string according to this format
  dateToString: (date = @value, format = @format) ->
    moment(date).format format
  # Convert string in this format to a date. Could be an invalid date.
  stringToDate: (str = @value, format = @format) ->
    moment(str, format, true).toDate()

    
class ModelFieldTree extends ModelField
  initialize: ->
    @setDefault 'value', []
    super

  option: (optionParams...) ->
    optionObject = @buildParamObject optionParams, ['path', 'value', 'selected']
    optionObject.value ?= optionObject.id
    optionObject.value ?= optionObject.path.join ' > '
    optionObject.title = optionObject.path.join '>' #use path as the key since that is what is rendered.
    super optionObject
    
  clear: (purgeDefaults=false) ->
    @value = if purgeDefaults then [] else @defaultValue

# An image field is different enough from other fields to warrant its own subclass
class ModelFieldImage extends ModelField
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
    optionObject = @buildParamObject optionParams, ['fileID', 'fileUrl', 'thumbnailUrl']
    optionObject.fileID ?= optionObject.fileUrl
    optionObject.thumbnailUrl ?= optionObject.fileUrl
    optionObject.value = {
      fileID: optionObject.fileID
      fileUrl: optionObject.fileUrl
      thumbnailUrl: optionObject.thumbnailUrl
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
      val.fileUrl is @value.fileUrl

  clear: (purgeDefaults=false) ->
    @value = if purgeDefaults then {} else @defaultValue

  ensureValueInOptions: ->
    existingOption = o for o in @options when o.attributes.fileID is @value.fileID
    unless existingOption
      @option @value


class ModelOption extends ModelBase
  initialize: ->
    @setDefault 'value', @get 'title'
    # No two options on a field should have the same title.  This would be confusing during render.
    # Even if not rendered, title can be used as primary key to determine when duplicate options should be avoided.
    @setDefault 'title', @get 'value'
    # selected is used to set default value and also to store current value.
    @setDefault 'selected', false
    @setDefault 'path', [] #for tree. Might should move to subclass
    super

    # if selected is changed, make sure parent matches
    # this change likely comes from parent value changing, so be careful not to infinitely recurse.
    @on 'change:selected', ->
      if @selected
        @parent.addOptionValue @value
      else # not selected
        @parent.removeOptionValue @value

#Call this method before output data is needed.
exports.buildOutputData = (model) ->
  model.buildOutputData()


getVisible = (visible) ->
  if typeof visible is 'function'
    return not not visible()
  if visible is undefined
    return true
  return not not visible