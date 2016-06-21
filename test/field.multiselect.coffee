assert = require 'assert'
fb = require '../formbuilder'


describe 'field.multiselect', ->
  it 'defaults value to empty array', ->
    model = fb.fromCoffee "field 'm', type:'multiselect'"
    value = model.child('m').value
    assert.deepEqual value, []
    