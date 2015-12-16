
window?.formbuilder = exports

CoffeeScript = require 'coffee-script'
Backbone     = require 'backbone'
_            = require 'underscore'
Mustache     = require 'mustache'
vm           = require 'vm'
jiff         = require 'jiff'

empty = (o)->
  not o or (o.length? and o.length is 0) or (typeof o is 'object' and Object.keys(o).length is 0)

# generate a new, unqiue identifier. Mostly good for label.for
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
exports.applyData = (modelObject, data) ->
  modelObject.applyData data

# Merge data objects together.  Should have the same result
# as if applyData was called sequentially.
exports.mergeData = (a, b)->
  if b.constructor is Object
    for key, value of b
      if a[key]? and a[key].constructor is Object and value.constructor is Object
        exports.mergeData a[key], value
      else
        a[key] = value
    a
  else
    exports.handleError 'mergeData: The object to merge in is not an object'

runtime = false
exports.modelTests= []

# Creates a Model object from JS code.  The executed code will execute in a
# root ModelGroup
# code - model code
# data - initialization data (optional). Object or stringified object
# element - jquery element for firing validation events (optional)
# imports - object mapping {varname : model object}. May be referenced in form code
exports.fromCode = (code, data, element, imports)->
  if typeof data is 'string'
    data = JSON.parse data
  runtime = false
  exports.modelTests = []
  test = (func) -> exports.modelTests.push func
  assert = (bool, message="A model test has failed") ->
    if not bool then exports.handleError message

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
        _:_
        console:#console functions don't break, but don't do anything
          log:->
          error:->
        print:->
      vm.runInNewContext '"use strict";' + code, sandbox
    else
      eval '"use strict";' + code

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
    if element
      e = $.Event 'validate'
      e.isValid = newRoot.isValid
      element.trigger e

  newRoot.on 'recalculate', ->
    if element
      element.trigger $.Event 'change'
  newRoot.trigger 'change:isValid'
  newRoot.trigger 'recalculate'

  runtime = true
  return newRoot

# CoffeeScript counterpart to fromCode.  Compiles the given code to JS
# and passes it to fromCode.
exports.fromCoffee = (code, data, element, imports)->
  return exports.fromCode (CoffeeScript.compile code), data, element, imports

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
  buildModelWithRecursiveImports = (p, el) ->
    form = (f for f in p.forms when f.formid is p.formid)[0]
    return if !form?

    builtImports = {}
    buildImport = (impObj) ->
      builtImports[impObj.namespace] = buildModelWithRecursiveImports
        formid: impObj.importformid
        data: p.data
        forms: p.forms
        #no element, don't want to bind triggers for imports.

    if form.imports #in case imports left off the package
      form.imports.forEach(buildImport)

    return exports.fromCoffee form.model, p.data, el, builtImports

  if (typeof pkg.formid is 'string')
    pkg.formid = parseInt pkg.formid
  if data?
    pkg.data = _.extend pkg.data or {}, data
  return buildModelWithRecursiveImports pkg, element

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
      # model onChangePropertiesHandlers functions
      for changeFunc in @onChangePropertiesHandlers
        changeFunc()

      ch = @changedAttributes()
      if ch is false #no changes, manual trigger meant to fire everything
        ch = 'multiple'

      @root.setDirty @id, ch
      @root.recalculateCycle()

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
      if typeof param in ['string', 'number']
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
      if empty value
        return "This field is required"
    minLength: (n)-> (value = @value or '')->
      if value.length < n
        return "Must be at least #{n} characters long"
    maxLength: (n)-> (value = @value or '')->
      if value.length > n
        return "Can be at most #{n} characters long"
    number: (value = @value or '')->
      if not value.match /^[-+]?\d*(\.?\d*)?$/
        return "Must be an integer or decimal number. (ex. 42 or 1.618)"
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
  initialize: ->
    @setDefault 'children', []
    @setDefault 'root', @
    @set 'isValid', true
    @set 'data', null

    super

  field: (fieldParams...) ->
    fieldObject = @buildParamObject fieldParams, ['title', 'name', 'type', 'value']

    #Could move this to a factory, but fields should only be created here so probably not necessary.
    fld = switch fieldObject.type
      when 'image'
        new ModelFieldImage fieldObject
      when 'tree'
        new ModelTree fieldObject
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
      data = child.buildOutputData()
      if data?
        obj[child.name] = child.buildOutputData()
    obj

  buildOutputDataString: ->
    JSON.stringify @buildOutputData()

  clear: () ->
    child.clear() for child in @children

  applyData: (data, clear=false) ->
    @clear() if clear
    @data = data
    for key, value of data
      @child(key)?.applyData value

###
  Encapsulates a group of form objects that can be added or removed to the form together multiple times
###
class RepeatingModelGroup extends ModelGroup
  initialize: ->
    @setDefault 'value', []
    @setDefault('defaultValue', @get 'value')

    super

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

  clear: () ->
    @value = @defaultValue

  applyData: (data, clear=false) ->
    @set('value', []) if clear or data?.length
    #each value in the repeating group needs to be a repeating group object, not just the anonymous object in data
    #add a new repeating group to value for each in data, and apply data like with a model group
    for obj in data
      added = @add()
      for key,value of obj
        added.child(key)?.applyData value

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
###
class ModelField extends ModelBase
  initialize: ->
    @setDefault 'type', 'text'
    @setDefault 'options', []
    @setDefault 'defaultValue', @get 'value' #determines control type, so keep separate from current value
    if @get('defaultValue')?
      @set('value', @get 'defaultValue')  #value may be overwritten by input data, so set even if exists
    else
      @clear() #clears value
    @set 'isValid', true
    @setDefault 'validators', []
    @setDefault 'onChangeHandlers', []
    @setDefault 'dynamicValue', null
    @setDefault 'template', null

    super

    #difficult to catch bad types at render time.  error here instead
    if @type not in ['info', 'text', 'url', 'email', 'tel', 'time', 'date', 'textarea',
                     'bool', 'tree', 'color', 'select', 'multiselect', 'image']
      return exports.handleError "Bad field type: #{@type}"

    # Fields with a template property can't also have a dynamicValue property.
    @bindPropFunctions 'dynamicValue' unless @template

    # multiselects are arrays, others are strings.  If typeof value doesn't match, convert it.
    while (Array.isArray @value) and (@type isnt 'multiselect') and (@type isnt 'tree')
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
      @getOptionsFrom()

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

  getOptionsFrom: _.throttle ->
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
  , 1000

  validityMessage: undefined
  field: (obj...) ->
    @parent.field obj...

  group: (obj...) ->
    @parent.group obj...

  option: (optionParams...) ->
    optionObject = @buildParamObject optionParams, ['title', 'value', 'selected']

    # when adding an option to a field, make sure it is a *select type
    if not (@type in ['select','multiselect'])
      @type = 'select'

    @options = @options.concat new ModelOption optionObject #assign rather than push to trigger correctly

    #if any option has selected:true, set this field's value to that
    for opt in @options
      if opt.selected
        @addOptionValue opt.value
    #update each option's selected value to match this field. eg, if default supplied on the field rather than option(s)
    @updateOptionsSelected()
    #don't remove from parent value if not selected. Might be supplied by field value during creation.
    @ #return the field so we can chain .option calls

  updateOptionsSelected: ->
    for opt in @options
      opt.selected = @hasValue opt.value

  # find an option by name.  Uses the same child method as groups and fields to find constituent objects
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
      for validator in @validators
        if typeof validator is 'function'
          validityMessage = validator.call @
        if typeof validityMessage is 'function'
          return exports.handleError "A validator on field '#{@name}' returned a function"
        if validityMessage then break
      @validityMessage = validityMessage
      @set isValid: not validityMessage?
    
    if @template
      @renderTemplate() if @shouldCallTriggerFunctionFor dirty, 'template'
    else
      #dynamic value
      if typeof @dynamicValue is 'function' and @shouldCallTriggerFunctionFor dirty, 'value'
        value = @dynamicValue()

        if typeof value is 'function'
          return exports.handleError "dynamicValue on field '#{@name}' returned a function"

        @set 'value', value

    if typeof @optionsFrom?.url is 'function' and @shouldCallTriggerFunctionFor dirty, 'options'
      @getOptionsFrom()

    for opt in @options
      opt.recalculateRelativeProperties()

  addOptionValue: (val) ->
    if @type is 'multiselect'
      if not (val in @value)
        @value.push val
    else #single-select
      @value = val

  removeOptionValue: (val) ->
    if @type is 'multiselect'
      if val in @value
        @value = @value.filter (v) -> v isnt val
    else if @value is val #single-select
      @value = ''

  #determine if the value is or contains the provided value.
  hasValue: (val) ->
    if @type is 'multiselect'
      val in @value
    else
      val is @value

  buildOutputData: ->
    if @type isnt 'info'
      @value

  clear: () ->
    @set 'value',
      if @defaultValue then @defaultValue
      else if (@get 'type') is 'multiselect' then []
      else if (@get 'type') is 'bool' then false
      else ''

  applyData: (data, clear=false) ->
    @clear() if clear
    if data?
      @value = data

  renderTemplate: () ->
    @applyData(Mustache.render(@parent.child(@template).value, @root.data))

class ModelTree extends ModelField
  initialize: ->
    @setDefault 'value', []

    super
    @get('value').sort()

  add: (item)->
    if _.indexOf(@value, item, 'isSorted') == -1

      if item instanceof Object
        index = _.sortedIndex @value, item, 'value'
      else
        index = _.sortedIndex @value, item

      @value.splice index, 0, item
      @trigger 'change'

  option: (item)->
    [pieces..., last] = item.split ' > '
    context           = @options

    for piece in pieces
      if not context[piece]
        context = context[piece] = {}
      else
        context = context[piece]

    if context instanceof Array
      context.push last
    else
      context[last] = null

    @trigger 'change'
    @

  remove: (item)->
    if item instanceof Object
      search = _.findWhere(@value, item)
      index = _.indexOf @value, search
    else
      index = _.indexOf @value, item, 'isSorted'

    if index != -1
      @value.splice index, 1
      @trigger 'change'

  clear: () ->
    @value = @defaultValue

# An image field is different enough from other fields to warrant its own subclass
class ModelFieldImage extends ModelField
  initialize: ->
    @setDefault 'value', {}
    @setDefault 'allowUpload', false
    @setDefault 'imagesPerPage', 4
    @set 'optionsChanged', false #React needs to know if the number of options changed,
    # as this requires a full reinit of the plugin at render time that is not necessary for other changes.
    super

    #companyID is required.  If it doesn't exist, throw an error
    if @allowUpload and !@companyID?
      return exports.handleError "required property 'companyID' missing for image field '#{@name}'"

  # Override behaviors different from other fields.

  option: (optionParams...) ->
    optionObject = @buildParamObject optionParams, ['fileID', 'fileUrl', 'thumbnailUrl']
    optionObject.title = @fileID
    optionObject.thumbnailUrl ?= optionObject.fileUrl
    optionObject.value = {
      fileID: optionObject.fileID
      fileUrl: optionObject.fileUrl
      thumbnailUrl: optionObject.thumbnailUrl
    }
    @options.push new ModelOption optionObject
    @optionsChanged = true
    @trigger 'change'
    @

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

  clear: () ->
    @value = @defaultValue

class ModelOption extends ModelBase
  initialize: ->
    @setDefault 'value', @get 'title'
    @setDefault 'title', @get 'value'
    # selected is used to set default value and also to store current value.
    @setDefault 'selected', false
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