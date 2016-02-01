assert = require 'assert'
fb = require '../formbuilder'

describe 'clear', ->
  it 'restores a text field to its initial value', (done) ->
    model = fb.fromCoffee "field 'foo', value:'bar'"
    field = model.child 'foo'
    assert.strictEqual field.value, 'bar'
    field.value = 'qux'
    assert.strictEqual field.value, 'qux'
    field.clear()
    assert.strictEqual field.value, 'bar'
    done()
  it 'restores a multiselect field to its initial value', (done) ->
    model = fb.fromCoffee "field 'foo', value:['bar'], type:'multiselect'\n.option 'bar'\n.option 'baz'"
    field = model.child 'foo'
    assert.deepEqual field.value, ['bar']
    field.value = ['baz']
    assert.deepEqual field.value, ['baz']
    field.clear()
    assert.deepEqual field.value, ['bar']
    done()
  it 'restores a bool field to its initial value', (done) ->
    model = fb.fromCoffee "field 'foo', value:true, type:'bool'"
    field = model.child 'foo'
    assert.strictEqual field.value, true
    field.value = false
    assert.strictEqual field.value, false
    field.clear()
    assert.strictEqual field.value, true
    done()
  it 'restores all fields in a group to their initial value', (done) ->
    model = fb.fromCoffee """
        group 'g'
        .field 'first', value: 'one'
        .field 'second', value: 'two'
        .field 'third'
      """
    assert.deepEqual model.buildOutputData(), g:
      first: 'one'
      second: 'two'
      third: ''
    model.applyData g:
      first: 'new one'
      second: 'new two'
    assert.deepEqual model.buildOutputData(), g:
      first: 'new one'
      second: 'new two'
      third: ''
    model.applyData g:
      third: 'new three'
    assert.deepEqual model.buildOutputData(), g:
      first: 'new one'
      second: 'new two'
      third: 'new three'
    model.clear()
    assert.deepEqual model.buildOutputData(), g:
      first: 'one'
      second: 'two'
      third: ''
    done()
  it 'restores a repeating group to its initial value', (done) ->
    model = fb.fromCoffee """
        group 'g', repeating:true, value: [f:'initial']
        .field 'f'
      """
    assert.deepEqual model.buildOutputData(), g:[f:'initial']
    model.child('g').add()
    assert.deepEqual model.buildOutputData(), g:[{f:'initial'},{f:''}]
    model.child('g').clear()
    assert.deepEqual model.buildOutputData(), g:[f:'initial']
    done()
  it 'clears a repeating group to when purgeDefaults=true', (done) ->
    model = fb.fromCoffee """
        group 'g', repeating:true, value: [f:'initial']
        .field 'f'
      """
    assert.deepEqual model.buildOutputData(), g:[f:'initial']
    model.child('g').add()
    assert.deepEqual model.buildOutputData(), g:[{f:'initial'},{f:''}]
    model.child('g').clear(true)
    assert.deepEqual model.buildOutputData(), g:[]
    done()
  it 'restores an image field to its initial value', (done) ->
    model = fb.fromCoffee """
        field 'i', type:'image', value:{fileID:1, fileUrl:'something'}
        .option fileID:1, fileUrl:'something'
      """
    field = model.child 'i'
    assert.deepEqual field.value, {fileID:1, fileUrl:'something'}
    field.value = {fileID:1, fileUrl:'nothing'}
    assert.deepEqual field.value, {fileID:1, fileUrl:'nothing'}
    field.clear()
    assert.deepEqual field.value, {fileID:1, fileUrl:'something'}
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
    field.value = ["dogs > boxer"]
    assert.deepEqual field.value, ["dogs > boxer"]
    field.clear()
    assert.deepEqual field.value, ["reptiles > snake"]
    done()