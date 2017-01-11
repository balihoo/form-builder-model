assert = require 'assert'
fb = require '../formbuilder'

describe 'group', ->
  it 'can remove fields', ->
    model = fb.fromCoffee """
      group 'g'
      .field 'f1', value:1
      .field 'f2', value:2
    """
    g = model.child('g')
    assert.strictEqual g.children.length, 2
    assert.deepEqual model.buildOutputData(), g:{f1:1,f2:2}
    g.children = (c for c in g.children when c.name isnt 'f2')
    assert.deepEqual g.children.length, 1
    assert.deepEqual model.buildOutputData(), g:{f1:1}