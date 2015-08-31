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
    assert.deepEqual c, one:'first', two:'second'
    
            