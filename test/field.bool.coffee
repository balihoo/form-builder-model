assert = require 'assert'
fb = require '../formbuilder'


describe 'field.bool', ->
  context 'when setting initial value', ->
    it 'defaults value to false', ->
      model = fb.fromCoffee "field 'b', type:'bool'"
      value = model.child('b').value
      assert.strictEqual value, false
    it 'saves bools as datatype bool', ->
      model = fb.fromCoffee "field 'b', type:'bool', value:false"
      value = model.child('b').value
      assert.strictEqual value, false
      model = fb.fromCoffee "field 'b', type:'bool', value:true"
      value = model.child('b').value
      assert.strictEqual value, true
    it 'converts other types to bool on truthyness', ->
      model = fb.fromCoffee "field 'b', type:'bool', value:'false'"
      value = model.child('b').value
      assert.strictEqual value, true
  context 'when buildOutputData', ->
    it 'outputs as datatype bool', ->
      model = fb.fromCoffee "field 'b', type:'bool'"
      out = model.buildOutputData()
      assert.strictEqual typeof out.b, 'boolean'
    it 'converts string values to bool', ->
      model = fb.fromCoffee "field 'b', type:'bool'"
      field = model.child 'b'
      field.value = 'false'
      assert.strictEqual model.buildOutputData().b, true #all non-empty strings are truthy
