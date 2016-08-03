assert = require 'assert'
fb = require '../formbuilder'

describe 'field.tree', ->
  it 'basic example', ->
    model = fb.fromCoffee """
      field 'mytree', type:'tree'
      .option path:['Places','Cities','Boise'], value:'123'
      .option path:['Places','Cities','Spokane'], value:'234'
      .option path:['People','Andy'], value:'345'
    """
    assert.deepEqual model.buildOutputData(), mytree:[]
  it 'allows addressing options by child(value)', ->
    model = fb.fromCoffee
  it 'allows options to be default selected', ->
    model = fb.fromCoffee """
      field 'mytree', type:'tree'
      .option path:['foo'], selected:true, value:'bar'
    """
    assert.strictEqual model.child('mytree.bar').selected, true
    assert.deepEqual model.buildOutputData(), mytree:['bar']
  it 'allows default field value'
  it 'accepts input data'

