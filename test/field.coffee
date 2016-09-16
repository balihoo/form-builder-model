assert = require 'assert'
fb = require '../formbuilder'
_ = require 'underscore'

describe 'fields', ->
  describe '.option()', ->
    it "adds selected options to the field's defaultValue", ->
      model = fb.fromCoffee "field 'foo'"
      assert.strictEqual model.child('foo').defaultValue, ''
      model = fb.fromCoffee "field('foo').option 'bar'"
      assert.strictEqual model.child('foo').defaultValue, ''
      model = fb.fromCoffee "field('foo').option 'bar', selected:true"
      assert.strictEqual model.child('foo').defaultValue, 'bar'
      model = fb.fromCoffee """
        field 'foo'
        .option 'one'
        .option 'two', selected:true
        .option 'three'
        """
      assert.strictEqual model.child('foo').defaultValue, 'two'
    it "adds selected options to the multiselect field's defaultValue", ->
      model = fb.fromCoffee "field 'foo', type:'multiselect'"
      assert.deepEqual model.child('foo').defaultValue, []
      model = fb.fromCoffee "field('foo', type:'multiselect').option 'bar'"
      assert.deepEqual model.child('foo').defaultValue, []
      model = fb.fromCoffee "field('foo', type:'multiselect').option 'bar', selected:true"
      assert.deepEqual model.child('foo').defaultValue, ['bar']
      model = fb.fromCoffee """
        field 'foo', type:'multiselect'
        .option 'one', selected:true
        .option 'two'
        .option 'three', selected:true
        .option 'four'
        """
      assert.deepEqual model.child('foo').defaultValue, ['one', 'three']
    it "adds selected options to an image field's defaultValue", ->
      model = fb.fromCoffee "field 'foo', type:'image'"
      assert.deepEqual model.child('foo').defaultValue, {}
      model = fb.fromCoffee """
        field 'foo', type:'image'
        .option
          fileID: 'fileID value1'
          fileUrl: 'fileUrl value1'
          thumbnailUrl: 'thumbnailUrl value1'
        """
      assert.deepEqual model.child('foo').defaultValue, {}
      newOpt =
        fileID: 'fileID value2'
        fileUrl: 'fileUrl value2'
        thumbnailUrl: 'thumbnailUrl value2'
        selected:true
      model = fb.fromCoffee """
        field 'foo', type:'image'
        .option #{JSON.stringify newOpt}
        """
      assert.deepEqual model.child('foo').defaultValue, _.omit newOpt, 'selected'
      # and sets current value
      assert.deepEqual model.child('foo').value, _.omit newOpt, 'selected'

      model = fb.fromCoffee """
        field 'foo', type:'image'
        .option
          fileID: 'fileID value1'
          fileUrl: 'fileUrl value1'
          thumbnailUrl: 'thumbnailUrl value1'
        .option #{JSON.stringify newOpt}
        """
      assert.deepEqual model.child('foo').defaultValue, _.omit newOpt, 'selected'
      assert.deepEqual model.child('foo').value, _.omit newOpt, 'selected'
      
    it 'triggers recalculation in other fields', ->
      model = fb.fromCoffee """
        a = field 'a', type:'select'
        field 'b', dynamicValue: -> a.options.length
      """
      model.child('a').option 'first'
      assert.strictEqual model.child('b').value, 1
    it 'triggers recalculation in other fields for image types', ->
      model = fb.fromCoffee """
              a = field 'a', type:'image'
              field 'b', dynamicValue: -> a.options.length
            """
      model.child('a').option {
        fileID: 'fileID value'
        fileUrl: 'fileUrl value'
        thumbnailUrl: 'thumbnailUrl value'
      }
      assert.strictEqual model.child('b').value, 1
    it 'duplicate options replace earlier with the same title', ->
      model = fb.fromCoffee """
        field 'f'
        .option title:'f title', value:'f value 1'
        .option title:'f title', value:'f value 2'
      """
      f = model.child 'f'
      assert.strictEqual f.options.length, 1
      assert.strictEqual f.options[0].value, 'f value 2'
    it 'duplicate options on image fields replace earler', ->
      model = fb.fromCoffee """
        field 'f', type:'image'
        .option fileID: 'fid', fileUrl:'url 1'
        .option fileID: 'fid', fileUrl:'url 2'
      """
      f = model.child 'f'
      assert.strictEqual f.options.length, 1
      assert.strictEqual f.options[0].fileUrl, 'url 2'
  describe '.cloneModel()', ->
    cloneAndCompareField = (foo) ->
      fooClone = foo.cloneModel()
      for prop in ['id']
        assert.notEqual foo[prop], fooClone[prop]
      for prop in ['name', 'title', 'value', 'defaultValue', 'type']
        assert.strictEqual foo[prop], fooClone[prop],
            "Property #{prop} is not strictly equal. Original:#{foo[prop]}, Clone:#{fooClone[prop]}"
    context 'when field has no default value', ->
      it 'cloned fields have the same attributes', ->
        model = fb.fromCoffee "field 'foo'"
        foo = model.child 'foo'
        cloneAndCompareField foo
    context 'when field has a default value', ->
      it 'cloned fields have the same attributes', ->
        model = fb.fromCoffee "field 'foo', value:'bar'"
        foo = model.child 'foo'
        cloneAndCompareField foo
    context 'when properties are changed after creation', ->
      it 'cloned fields have the same attributes', ->
        model = fb.fromCoffee "field 'foo'"
        foo = model.child 'foo'
        foo.value = 'changed'
        cloneAndCompareField foo
    context 'when field has a default value and properties are changed after creation', ->
      it 'cloned fields have the same attributes', ->
        model = fb.fromCoffee "field 'foo', value:'bar'"
        foo = model.child 'foo'
        foo.value = 'changed'
        cloneAndCompareField foo

