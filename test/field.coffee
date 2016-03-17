assert = require 'assert'
fb = require '../formbuilder'

describe 'fields', ->
  describe '.option()', ->
    it "adds selected options to the field's defaultValue", ->
      model = fb.fromCoffee "field 'foo'"
      foo = model.child 'foo'
      assert.strictEqual foo.defaultValue, ''
      foo.option 'bar'
      assert.strictEqual foo.defaultValue, ''
      foo.option 'baz', selected:true
      assert.strictEqual foo.defaultValue, 'baz'
      foo.option 'another'
      assert.strictEqual foo.defaultValue, 'baz'
    it "adds selected options to the multiselect field's defaultValue", ->
      model = fb.fromCoffee "field 'foo', type:'multiselect'"
      foo = model.child 'foo'
      assert.deepEqual foo.defaultValue, []
      foo.option 'bar'
      assert.deepEqual foo.defaultValue, []
      foo.option 'baz', selected:true
      assert.deepEqual foo.defaultValue, ['baz']
      foo.option 'another'
      assert.deepEqual foo.defaultValue, ['baz']
      foo.option 'yet another', selected:true
      assert.deepEqual foo.defaultValue, ['baz', 'yet another']    
    it "adds selected options to an image field's defaultValue", ->
      model = fb.fromCoffee "field 'foo', type:'image'"
      foo = model.child 'foo'
      assert.deepEqual foo.defaultValue, {}
      foo.option {
        fileID: 'fileID value1'
        fileUrl: 'fileUrl value1'
        thumbnailUrl: 'thumbnailUrl value1'
      }
      assert.deepEqual foo.defaultValue, {}
      newOpt = {
        fileID: 'fileID value2'
        fileUrl: 'fileUrl value2'
        thumbnailUrl: 'thumbnailUrl value2'
        selected:true
      }
      foo.option newOpt
      delete newOpt.selected
      # sets default value
      assert.deepEqual foo.defaultValue, newOpt
      # and sets current value
      assert.deepEqual foo.value, newOpt
      foo.option {
        fileID: 'fileID value3'
        fileUrl: 'fileUrl value3'
        thumbnailUrl: 'thumbnailUrl value3'
      }
      assert.deepEqual foo.defaultValue, newOpt
      assert.deepEqual foo.value, newOpt
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

