assert = require 'assert'
fb = require '../formbuilder'

describe 'mergeData', ->
  it 'merges missing keys', ->
    a = one: 'first'
    b = two: 'second'
    fb.mergeData a, b
    assert.deepEqual a, one:'first', two:'second'
  it 'overwrites early values with later ones', ->
    a = one: 'first', two:'second'
    b = one: 'third'
    fb.mergeData a, b
    assert.deepEqual a, one:'third', two: 'second'
  it 'merges recursive objects', ->
    a = one:two:three:'four'
    b = one:two:five:'six'
    fb.mergeData a, b
    assert.deepEqual a, 
      one:
        two:
          three:'four'
          five:'six'
  it 'returns the merged value', ->
    a = one:'first'
    b = two:'second'
    c = fb.mergeData a, b
    assert.deepEqual c,
      one:'first'
      two:'second'
      
  # BUGS-1848 - merging an object with a null results in:
  # TypeError: Cannot read property 'constructor' of null
  context 'when the first parameter has a key with a null value', ->
    context 'and there is a matching object in the second parameter', ->
      it 'overwrites the key with the second value', ->
        a = one:null
        b = one:two:2
        c = fb.mergeData a, b
        assert.deepEqual c, one:two:2
    context 'and there is no matching object in the second parameter', ->
      it 'adds the key', ->
        a = one:null
        b = stuff:'things'
        c = fb.mergeData a, b
        assert.deepEqual c,
          one:null
          stuff:'things'
  context 'when the second parameter has a key with a null value', ->
    context 'and there is a matching key in the first parameter', ->
      it 'overwrites the key with the null value', ->
        a = one:two:2
        b = one:null
        c = fb.mergeData a, b
        assert.deepEqual c, one:null
    context 'and there is no matching key in the first parameter', ->
      it 'adds the key with the null value', ->
        a = stuff:'things'
        b = one:null
        c = fb.mergeData a, b
        assert.deepEqual c,
          stuff:'things'
          one:null