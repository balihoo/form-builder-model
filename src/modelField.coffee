
ModelBase = require './modelBase'
ModelOption = require './modelOption'
globals = require './globals'
Mustache = require 'mustache'
jiff = require 'jiff'

###
  A ModelField represents a model object that render as a DOM field
  NOTE: The following field types are subclasses: image, tree, date
###
module.exports = class ModelField extends ModelBase
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
    @setDefault 'beforeInput', (val) -> val
    @setDefault 'beforeOutput', (val) -> val

    super

    #difficult to catch bad types at render time.  error here instead
    if @type not in ['info', 'text', 'url', 'email', 'tel', 'time', 'date', 'textarea',
                     'bool', 'tree', 'color', 'select', 'multiselect', 'image', 'button', 'number']
      return globals.handleError "Bad field type: #{@type}"

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
      @ensureSelectType()
      if !@optionsFrom.url? or !@optionsFrom.parseResults?
        return globals.handleError 'When fetching options remotely, both url and parseResults properties are required'
      if typeof @optionsFrom?.url is 'function'
        @optionsFrom.url = @bindPropFunction 'optionsFrom.url', @optionsFrom.url
      if typeof @optionsFrom.parseResults isnt 'function'
        return globals.handleError 'optionsFrom.parseResults must be a function'
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
      if @options.length > 0 and not @isSelectType()
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
        return globals.handleError globals.makeErrorMessage @, 'optionsFrom', error
      mappedResults = @optionsFrom.parseResults data
      if not Array.isArray mappedResults
        return globals.handleError 'results of parseResults must be an array of option parameters'
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
    @ensureSelectType()

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

  # returns true if this type is one where a value is selected. Otherwise false
  isSelectType: ->
    @type in ['select', 'multiselect', 'image', 'tree']

  # certain operations require one of the select types.  If its not already, change field type to select
  ensureSelectType: ->
    unless @isSelectType()
      @type = 'select'

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
            return globals.handleError "A validator on field '#{@name}' returned a function"
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
          return globals.handleError "dynamicValue on field '#{@name}' returned a function"

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

  buildOutputData: (_, skipBeforeOutput) ->
    value = switch @type
      when 'number'
        out = +@value
        if isNaN out then null else out
      when 'info', 'button' then undefined
      when 'bool' then not not @value
      else @value

    if skipBeforeOutput then value else @beforeOutput value

  clear: (purgeDefaults=false) ->
    if purgeDefaults
      @value = switch @type
        when 'multiselect' then []
        when 'bool' then false
        else ''
    else
      @value = @defaultValue

  ensureValueInOptions: ->
    return unless @isSelectType()
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
      @value = @beforeInput jiff.clone inData
      @ensureValueInOptions()

  renderTemplate: () ->
    if typeof @template is 'object'
      template = @template.value
    else
      template = @parent.child(@template).value
    try
      @value = Mustache.render template, @root.data
    catch #just don't crash. Validator will display error later.

