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
  it 'group default overrides field defaults', ->
    model = fb.fromCoffee '''
      group 'g', repeating:true, value:[f:'group default']
      .field 'f', value:'field default'
    '''
    assert.strictEqual model.child('g').value.length, 1
    assert.strictEqual model.child('g').value[0].child('f').value, 'group default'
  it 'value instances are type ModelGroup', ->
    model = fb.fromCoffee '''
      group 'g', repeating:true, value:[f:'group default']
      .field 'f'
    '''
    assert.strictEqual model.child('g').value[0].constructor.name, 'ModelGroup'
  it 'value instances do not have attributes that should be excluded', ->
    model = fb.fromCoffee '''
      g = group name:'g', title:'Group Title', repeating:true, value:[f:'group default'],
        beforeInput: -> [f:'group beforeInput']
        beforeOutput: -> [f:'group beforeOutput']
      g.field 'f'
    '''
    g = model.child 'g'
    instance = g.value[0]
    assert.strictEqual instance.name, g.name
    assert.strictEqual instance.title, ''
    testIn = f:'test before input'
    assert.deepEqual instance.beforeInput(testIn), testIn
    testOut = f:'test output'
    assert.deepEqual instance.beforeOutput(testOut), testOut
