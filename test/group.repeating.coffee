assert = require 'assert'
fb = require '../formbuilder'

describe 'group.repeating', ->
  it 'has a value array', ->
    model = fb.fromCoffee "group 'g', repeating:true"
    assert Array.isArray model.child('g').value
  it 'accepts prototype children', ->
    model = fb.fromCoffee """
      group 'g', repeating:true
      .field 'foo'
    """
    assert.strictEqual model.child('g').children.length, 1
    assert.deepEqual model.child('g').value, []
  it 'can add() children to value', ->
    model = fb.fromCoffee """
      group 'g', repeating:true
      .field 'foo'
    """
    model.child('g').add()
    assert.deepEqual model.buildOutputData(), g:[{foo:''}]
  it 'add()ed children can have default value', ->
    model = fb.fromCoffee """
      group 'g', repeating:true
      .field 'foo', value:'bar'
    """
    model.child('g').add()
    assert.deepEqual model.buildOutputData(), g:[{foo:'bar'}]
    firstFoo = model.child('g').value[0].child('foo')
    assert.strictEqual firstFoo.value, 'bar'
    assert.strictEqual firstFoo.defaultValue, 'bar'
  it 'add()ed children can have default value via options selected', ->
    model = fb.fromCoffee """
      group 'g', repeating:true
      .field 'foo'
      .option 'bar', selected:true
    """
    model.child('g').add()
    assert.deepEqual model.buildOutputData(), g:[{foo:'bar'}]
    firstFoo = model.child('g').value[0].child('foo')
    assert.strictEqual firstFoo.value, 'bar'
    assert.strictEqual firstFoo.defaultValue, 'bar'
  