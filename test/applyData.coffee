assert = require 'assert'
fb = require '../formbuilder'

describe 'applyData', ->
  it 'applies data to a field', (done) ->
    model = fb.fromCoffee "field 'first'\nfield 'second'", {first:'one',second:'two'}
    assert.deepEqual model.buildOutputData(), {first:'one', second:'two'}
    model.applyData {first:'new one'}
    assert.deepEqual model.buildOutputData(), {first:'new one', second:'two'}
    done()
  it 'clears all when clear=true', (done) ->
    model = fb.fromCoffee "field 'first'\nfield 'second'", {first:'one',second:'two'}
    assert.deepEqual model.buildOutputData(), {first:'one', second:'two'}
    model.applyData {first:'new one'}, true
    assert.deepEqual model.buildOutputData(), {first:'new one', second:''}
    done()
  it 'applies data to nested fields', (done) ->
    model = fb.fromCoffee """
        field 'first', value:'one'
        group 'container'
        .field 'second', value:'two'
        .field 'third', value:'three'
      """
    data = {
      first: 'new one'
      container:
        second: 'new two'
        third: 'new three'
    }
    model.applyData data
    assert.deepEqual model.buildOutputData(), data
    done()
  it 'applies partial data to nested fields', (done) ->
    model = fb.fromCoffee """
        field 'first', value:'one'
        group 'container'
        .field 'second', value:'two'
        .field 'third', value:'three'
      """
    model.applyData {
      first: 'new one'
      container:
        third: 'new three'
    }
    assert.deepEqual model.buildOutputData(), {
      first: 'new one'
      container:
        second:'two'
        third: 'new three'
    }
    done()
  it 'clears nested when clear=true', (done) ->
    model = fb.fromCoffee """
        field 'first', value:'one'
        group 'container'
        .field 'second', value:'two'
        .field 'third', value:'three'
      """
    model.applyData {
      first: 'new one'
      container:
        third: 'new three'
    }, true
    assert.deepEqual model.buildOutputData(), {
      first: 'new one'
      container:
        second:''
        third: 'new three'
    }
    done()
