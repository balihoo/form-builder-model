

CoffeeScript = require('coffee-script').register()
Mustache     = require 'mustache'
_            = require 'underscore'
vm           = require 'vm'
jiff         = require 'jiff'
globals = require './globals'


ModelGroup = require './modelGroup'
globals = require './globals'


if alert?
  throttledAlert = _.throttle alert, 500

###
  An array of functions that can test a built model.
  Model code may add tests to this array during build.  The tests themselves will not be run at the time, but are
    made avaiable via this export so processes can run the tests when appropriate.
  Tests may modify the model state, so the model should be rebuilt prior to running each test.
###
exports.modelTests = []

# Creates a Model object from JS code.  The executed code will execute in a
# root ModelGroup
# code - model code
# data - initialization data (optional). Object or stringified object
# element - jquery element for firing validation events (optional)
# imports - object mapping {varname : model object}. May be referenced in form code
exports.fromCode = (code, data, element, imports, isImport)->
  data = switch typeof data
    when 'object' then jiff.clone data #copy it
    when 'string' then JSON.parse data
    else {} # 'undefined', 'null', and other unsupported types
  globals.runtime = false
  exports.modelTests = []
  test = (func) -> exports.modelTests.push func
  assert = (bool, message="A model test has failed") ->
    if not bool then globals.handleError message

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
  globals.runtime = true

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
  
  newRoot.styles = false #don't render with well, etc.


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

  # This patch is parsed and used to generate the changes
  internalPatch = jiff.diff(
    modelBefore.buildOutputData(undefined, true)
    modelAfter.buildOutputData(undefined, true)
    invertible:false
  )

  # This is the actual patch
  outputPatch = jiff.diff modelBefore.buildOutputData(), modelAfter.buildOutputData(), invertible:false
  #array paths end in an index #. We only want the field, not the index of the value
  changedPaths = (p.path.replace(/\/[0-9]+$/, '') for p in internalPatch)
  #get distinct field names. Arrays for example might appear multiple times
  changedPathsUniqObject = {}
  changedPathsUniqObject[val] = val for val in changedPaths
  changedPathsUnique = (key for key of changedPathsUniqObject)
  changes = []
  for changedPath in changedPathsUnique
    path = changedPath[1..-1] #don't need that initial separator
    before = modelBefore.child path
    after = modelAfter.child path
    unless _.isEqual before?.value, after?.value #deep equality for non-primitives
      changes.push
        name:changedPath
        title:after.title
        before:before.buildOutputData undefined, true
        after:after.buildOutputData undefined, true
  {
  changes: changes
  patch: outputPatch
  }
