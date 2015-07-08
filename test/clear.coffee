assert = require 'assert'
fb = require '../formbuilder'

describe 'clear', ->
  it 'clears a text field', (done) ->
    model = fb.fromCoffee "field 'foo', value:'bar'"
    field = model.child 'foo'
    assert.strictEqual field.value, 'bar'
    field.clear()
    assert.strictEqual field.value, ''
    done()
  it 'clears a multiselect field', (done) ->
    model = fb.fromCoffee "field 'foo', value:['bar'], type:'multiselect'\n.option 'bar'\n.option 'baz'"
    field = model.child 'foo'
    assert.deepEqual field.value, ['bar']
    field.clear()
    assert.deepEqual field.value, []
    done()
  it 'clears a bool field', (done) ->
    model = fb.fromCoffee "field 'foo', value:true, type:'bool'"
    field = model.child 'foo'
    assert.strictEqual field.value, true
    field.clear()
    assert.strictEqual field.value, false
    done()
  it 'clears all fields in a group', (done) ->
    model = fb.fromCoffee """
        group 'g'
        .field 'first'
        .field 'second'
        .field 'third'
      """
    model.applyData g:
      first: 'one'
      second: 'two'
    assert.deepEqual model.buildOutputData(), g:
      first: 'one'
      second: 'two'
      third: ''
    model.clear()
    assert.deepEqual model.buildOutputData(), g:
      first: ''
      second: ''
      third: ''
    done()
  it 'clears a repeating group', (done) ->
    model = fb.fromCoffee """
        group 'g', repeating:true
        .field 'f', value:'initial'
      """
    model.child('g').add()
    assert.deepEqual model.buildOutputData(), g:[f:'initial']
    model.child('g').clear()
    assert.deepEqual model.buildOutputData(), g:[]
    done()
  it 'clears an image field', (done) ->
    model = fb.fromCoffee """
        field 'i', type:'image', value:{fileID:1, fileUrl:'something'}
        .option fileID:1, fileUrl:'something'
      """
    field = model.child 'i'
    assert.deepEqual field.value, {fileID:1, fileUrl:'something'}
    field.clear()
    assert.deepEqual field.value, {}
    done()
  it 'clears a tree field', (done) ->
    model = fb.fromCoffee """
        field 'tree', type: 'tree', value:["reptiles > snake"], options:
          mammals:
            cats: [
              'calico'
              'ragdoll'
              'manx'
            ]
            dogs: [
              'corgi'
              'boxer'
              'dachshund'
            ]
          reptiles: [
            'lizard'
            'snake'
          ]
          fish: null
      """
    field = model.child 'tree'
    assert.deepEqual field.value, ["reptiles > snake"]
    field.clear()
    assert.deepEqual field.value, []
    done()
