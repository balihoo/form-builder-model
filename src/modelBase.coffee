###
# Attributes common to groups and fields.
###

Backbone = require 'backbone'
_ = require 'underscore'
globals = require './globals'
moment = require 'moment'
Mustache = require 'mustache'


# generate a new, unqiue identifier. Mostly good for label.
newid = (->
  incId = 0
  ->
    incId++
    "fbid_#{incId}"
)()


getVisible = (visible) ->
  if typeof visible is 'function'
    return not not visible()
  if visible is undefined
    return true
  return not not visible

module.exports = class ModelBase extends Backbone.Model
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
      return unless globals.runtime
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
        message = globals.makeErrorMessage model, propName, err
        globals.handleError message

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
  cloneModel: (newRoot = @root, constructor = @constructor, excludeAttributes=[]) ->
    # first filter out undesired attributes from the clone
#    filteredAttributes = {}
#    for key,val of @attributes when key not in excludeAttributes
#      filteredAttributes[key] = val
      
    # now call the constructor with the desired attributes
    myClone = new constructor(@attributes)
#    myClone = new constructor(filteredAttributes)

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

