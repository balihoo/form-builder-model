assert = require 'assert'
fb = require '../formbuilder'

describe 'field.number', ->
  it 'accepts string default value', ->
    model = fb.fromCoffee "field 'num', type:'number', value:'123'"
    assert.strictEqual model.buildOutputData().num, 123
  it 'accepts string inputdata', ->
    model = fb.fromCoffee "field 'num', type:'number'", num:'123'
    assert.strictEqual model.buildOutputData().num, 123
  it 'accepts number default value', ->
    model = fb.fromCoffee "field 'num', type:'number', value:123"
    assert.strictEqual model.buildOutputData().num, 123
  it 'accepts number inputdata', ->
    model = fb.fromCoffee "field 'num', type:'number'", num:123
    assert.strictEqual model.buildOutputData().num, 123
  it 'defaults internal value to 0', ->
    model = fb.fromCoffee "field 'num', type:'number'"
    assert.strictEqual model.child('num').value, 0
  context 'when value is not parsable as a number', ->
    it 'has outputData null', ->
      model = fb.fromCoffee "field 'num', type:'number', value:'applesauce'"
      field = model.child 'num'
      assert.strictEqual model.buildOutputData().num, null
    it 'is not valid', ->
      model = fb.fromCoffee "field 'num', type:'number', value:'applesauce'"
      field = model.child 'num'
      assert not field.isValid
      assert.strictEqual field.validityMessage, 'Must be an integer or decimal number. (ex. 42 or 1.618)'
    it 'doesnt partially parse strings', ->
      model = fb.fromCoffee "field 'num', type:'number', value:'23 skidoo'"
      assert.strictEqual model.buildOutputData().num, null
      model = fb.fromCoffee "field 'num', type:'number', value:'about2'"
      assert.strictEqual model.buildOutputData().num, null
    it 'doesnt accept double decimals', ->
      model = fb.fromCoffee "field 'num', type:'number', value:'12.34.56'"
      assert.strictEqual model.buildOutputData().num, null