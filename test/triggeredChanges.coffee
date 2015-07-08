
assert = require 'assert'  
fb = require '../formbuilder'

describe 'triggered changes', ->
  describe 'onChangeProperties', -> #onChangeProperties is any property, including value
    it 'calls correctly', (done) ->

      #FIELD
      model = fb.fromCoffee """
        fld1 = field 'test1_field1'

        field 'test1_field2', {onChangePropertiesHandlers:->
          fld1.title = 'foo'
          fld1.value = 'field changed'}
        group 'group1'
          .field 'group1_field1'
            .option 'group1_field1_option1', {onChangePropertiesHandlers: -> fld1.value = 'option changed'}

        root.child('group1').onChangeProperties (-> fld1.value = 'group changed'), false
      """
      fld1 = model.child('test1_field1')
      assert.strictEqual fld1.title, 'test1_field1',
        'Remote field title is from model'
      assert.strictEqual fld1.value, '',
        'Remote field value is initially empty'

      model.child('test1_field2').value = 'y'

      assert.strictEqual fld1.title, 'foo',
          'Remote field title updated onChangeProperties'
      assert.strictEqual fld1.value, 'field changed',
          'Remote field value update on field change'

      #GROUP
      model.child('group1').name = 'Jimmy'
      assert.strictEqual fld1.value, 'group changed',
          'Remote field value update on group change'

      #OPTION
      model.child('Jimmy').child('group1_field1').options[0].selected = true
      assert.strictEqual fld1.value, 'option changed',
          'Remote field value update on option change'

      done()

    it 'property changed during onChangeProperties can trigger additional onChangeProperties events', (done) ->
      model = fb.fromCoffee """
        fld1 = field 'field1'
        fld2 = field 'field2', {onChangePropertiesHandlers: ->
          fld1.value = 'foo'}
        field 'field3', onChangePropertiesHandlers: ->
          fld2.value = 'bar'
      """
      model.child('field3').value = 'y'
      assert.strictEqual model.child('field1').value, 'foo',
        'Field changed during onChangeProperties fired its own onChangeProperties'
      done()

  describe 'onChange', -> #onChange is field value only

    it 'triggers on change and not on no change', (done) ->
      model = fb.fromCoffee """
        field 'one', onChangeHandlers: ->
          root.child('two').title = 'bar'
        field 'two'
      """
      assert.strictEqual model.child('two').title, 'two',
        "Field title has default value"
      model.child('one').title = 'foo'

      assert.strictEqual model.child('two').title, 'two',
        "onChange not triggered on non-value change"

      model.child('one').value = 'new'
      assert.strictEqual model.child('two').title, 'bar',
        "onChange triggered on value change"
      done()

  describe 'partially implemented functions (during typing)', ->
    it 'doesnt hang for dynamic value', (done) ->
      model = fb.fromCoffee """
        root.count = 0
        field 'a', dynamicValue: ->
          root.count += 1
          @
      """
      assert.strictEqual model.count, 1, "doesn't trigger multiple times"
      assert.strictEqual model.child('a').value, model.child('a'), "just sets value to returned"
      done()




  describe 'limiting trigger counts', ->
    #BUGS-1273 - too many triggers can slow things down, test limitations when not necessary
    #Below code has 3 fields, a, b which depends on a, and c which depends on b.
    #Previously, any change causes all dynamicValue functions to be called. There are 2 (on b and c)
    #Initializing alters root, a, b, and c.  4 changes x 2 functions = 8 calls.
    #Change the value of field a triggers functions for b and c, and each of those triggers b and c again = 6 calls
    #Most of these triggers are unnecessary, and if the function takes a while will greatly slow things down
    #and more fields with dynamic values will result in exponentially more calls.
    it 'limits two dynamic value fields triggering each other', (done) ->
      model = fb.fromCoffee """
        root.count = 0

        a = field 'a'
        b = field 'b', dynamicValue: ->
          root.count+=1
          a.value + ' mod'

        c = field 'c', dynamicValue: ->
          root.count+=1
          b.value + ' then mod again'
      """
      ### Should be 3 times on build
      2 - First queue b,c
      0 - b does not trigger itself, nor c because c is already queued
      1 - c does not trigger itself, but does queue b again
          b results in no change, no more triggers
      ###
      assert.strictEqual model.count, 3,
        "Dynamic value functions were called the minimum number of times on init"
      model.count = 0
      model.children[0].value = 'n'
      ### should be 3 times on change
      2 - First queue b and c
      0 - b does not trigger itself, nor c because c is already queued
      1 - c does not trigger itself, but does queue b again
          b results in no change, no more triggers
      ###
      assert.strictEqual model.count, 3,
        "Dynamic value functions were called the minimum number of times on change"
      done()

  #  #more like we usually do, with a input and rendered output form
  #  #demonstrates that number of calls still does climb more rapidly than number of fields
    it 'limits calls several dynamic functions', (done) ->
      model = fb.fromCoffee """
        root.count = 0

        field 'a'
        field 'b', dynamicValue: ->
          root.count += 1
          'a has changed'
        field 'c'
        field 'd', dynamicValue: ->
          root.count += 1
          'c has changed'
        field 'e'
        field 'f', dynamicValue: ->
          root.count += 1
          'f has changed'
      """
      ### should be 6
      #3 - initial trigger
      #0 - b does not trigger itself, and d and f are already queued
      #1 - d causes b to trigger again
      #0 - b fires but returns the same value
      #2 - f fires and re-triggers b and d
      #0 - b and d result in no change
      ####
      assert.strictEqual model.count, 6,
        "Dynamic value function calls grow faster than fields, but still restricted to min required"
      model.count = 0
      model.child('a').value = 'new'
      # on update, each will fire but only one returns a new value.
      # and this update won't trigger itself to run again.
      assert.strictEqual model.count, 3,
        "Dynamic value functions call correctly on update"
      done()

    it 'dynamicValue triggers once, then doesnt trigger itself', (done) ->
      model = fb.fromCoffee """
        root.count = 0

        a = field 'a'
        b = field 'b', dynamicValue: ->
          root.count += 1
          a.value
      """
      model.count = 0
      model.children[0].value = 'new'
      assert.strictEqual model.count, 1,
        "Dynamic value triggered, then not re-triggered by its own change"
      done()

    it 'doesnt fire dynamicValue on value change', (done) ->
      model = fb.fromCoffee """
        root.count = 0
        field 'a', dynamicValue: -> root.count+=1
      """
      assert.strictEqual model.count, 1,
        "Dynamic value functions don't trigger themselves"

      model.count = 0
      model.child('a').value = 'new value'
      assert.strictEqual model.count, 0, 'changing value doesnt trigger its own dynamic value function'
      done()

    it 'doesnt fire visible on field visibility change', (done) ->
      model = fb.fromCoffee """
        root.count = 0
        field 'a', visible: ->
          root.count += 1
          not @isVisible
      """
      assert.strictEqual model.count, 1,
        "visible functions on fields don't trigger themselves"
      done()


    it 'doesnt fire visible on group visibility change', (done) ->
      model = fb.fromCoffee """
        root.count = 0
        group 'a', visible: ->
          root.count += 1
          not @isVisible
      """
      assert.strictEqual model.count, 1,
        "visible functions on groups don't trigger themselves"
      done()

    it 'doesnt fire visible on options change', (done) ->
      model = fb.fromCoffee """
        root.count = 0
        field 'a'
        .option '1', visible: ->
          root.count += 1
          not @isVisible
      """
      assert.strictEqual model.count, 1,
        "visible functions on options don't trigger themselves"
      done()

    it 'doesnt fire validators more than once', (done) ->
      model = fb.fromCoffee """
        root.count = 0
        field 'a', validators: ->
          root.count += 1
          "invalid " + root.count
      """
      # Should be 2. Once for initial fire, again when this becoming invalid makes ROOT invalid
      assert.strictEqual model.count, 2,
        "validator functions don't trigger themselves"
      done()