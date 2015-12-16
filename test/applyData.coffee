assert = require 'assert'
fb = require '../formbuilder'

describe 'applyData', ->
  it 'applies data to a field', (done) ->
    model = fb.fromCoffee "field 'first'\nfield 'second'", {first:'one',second:'two'}
    assert.deepEqual model.buildOutputData(), {first:'one', second:'two'}
    model.applyData {first:'new one'}
    assert.deepEqual model.buildOutputData(), {first:'new one', second:'two'}
    done()
  it 'restores all initial values when clear=true', (done) ->
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
  it 'restores nested to initial value when clear=true', (done) ->
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
        second:'two'
        third: 'new three'
    }
    model.applyData {
      first: 'newer one'
    }, true
    assert.deepEqual model.buildOutputData(), {
      first: 'newer one'
      container:
        second:'two'
        third: 'three'
    }
    done()
  it 'sets the value of repeating groups', (done) ->
    model = fb.fromCoffee """
      group 'g', repeating:true
      .field 'f'
      """, {g:[
        {f:'initial'}
        {f:'starting'}
      ]}
    model.applyData {g:[
      {f:'ending'}
      {f:'final'}
    ]}
    assert.deepEqual model.buildOutputData(), {
      g: [
        {f:'ending'}
        {f:'final'}
      ]
    }
    done()
  it 'sets the value of template fields', (done) ->
    model = fb.fromCoffee """
      field 'a'
      field 'b', template:'a'""",
      {a:'{{{city}}}'}
    assert.deepEqual model.buildOutputData(), {a:'{{{city}}}', b:''}
    model.applyData {city:'Boise'}
    assert.deepEqual model.buildOutputData(), {a:'{{{city}}}', b:'Boise'}
    model.applyData {a:'{{{state}}}'}
    model.applyData {state:'ID'}
    assert.deepEqual model.buildOutputData(), {a:'{{{state}}}', b:'ID'}
    done()
