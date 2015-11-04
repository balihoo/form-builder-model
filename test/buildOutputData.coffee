assert = require 'assert'
fb = require '../formbuilder'

describe 'buildOutputData', ->
  it 'a single field', ->
    model = fb.fromCoffee "field 'a'", a:'b'
    assert.deepEqual model.buildOutputData(), a:'b'

  it 'several fields', ->
    model = fb.fromCoffee """
field 'a', value:'first'
field 'b'
""", b:'second'
    assert.deepEqual model.buildOutputData(),
      a:'first'
      b:'second'

  it 'a group of fields', ->
    model = fb.fromCoffee """
group 'g'
.field 'a', value:'first'
.field 'b'
""", g:b:'second'
    assert.deepEqual model.buildOutputData(),
      g:
        a:'first'
        b:'second'

  it 'a multiselect field', ->
    model = fb.fromCoffee """
field 'f', type:'multiselect'
.option 'one'
.option 'two', selected:true
.option 'three'
.option 'four', selected:true
"""
    assert.deepEqual model.buildOutputData(), f:['two','four']

  it 'a repeating group', ->
    data = g:[
      f1: 'first', f2: 'second'
      f1: 'third', f2: 'fourth'
    ]
    model = fb.fromCoffee """
group 'g', repeating:true
.field 'f1'
.field 'f2'
""", data
    assert.deepEqual model.buildOutputData(), data

  it 'a field with optionsFrom remote url', ->
    model = fb.fromCoffee """
field 'foo', value:'bar', optionsFrom:
  url: '/doesnt/get/loaded/during/build'
  parseResults: -> []
"""
    assert.deepEqual model.buildOutputData(), foo:'bar'