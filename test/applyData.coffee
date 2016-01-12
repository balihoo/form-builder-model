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
    model = fb.fromCoffee """
        field 'first', defaultValue: 'default one'
        field 'second'
      """, {first:'one',second:'two'}
    assert.deepEqual model.buildOutputData(), {first:'one', second:'two'}
    model.applyData {second:'new two'}, true
    assert.deepEqual model.buildOutputData(), {first:'default one', second:'new two'}
    done()
  it 'clears initial values when clear=true and purgeDefaults=true', (done) ->
    model = fb.fromCoffee """
        field 'first', defaultValue: 'default one'
        field 'second'
      """, {first:'one',second:'two'}
    assert.deepEqual model.buildOutputData(), {first:'one', second:'two'}
    model.applyData {second:'new two'}, true, true
    assert.deepEqual model.buildOutputData(), {first:'', second:'new two'}
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
  it 'clears nested values when clear=true and purgeDefaults=true', (done) ->
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
    }, true, true
    assert.deepEqual model.buildOutputData(), {
      first: 'new one'
      container:
        second: ''
        third: 'new three'
    }
    model.applyData {
      first: 'newer one'
    }, true, true
    assert.deepEqual model.buildOutputData(), {
      first: 'newer one'
      container:
        second: ''
        third: ''
    }
    done()
  it 'applies data to a model group', (done) ->
    model = fb.fromCoffee """
      group 'g'
      .field 'first'
      """
    assert.deepEqual model.buildOutputData(), {g:{first:''}}
    model.applyData {g:{first: 'fresh'}}
    assert.deepEqual model.buildOutputData(), {g:{first:'fresh'}}
    done()
  it 'applies data to a repeating model group', (done) ->
    model = fb.fromCoffee """
      group 'g', repeating: true
      .field 'first'
      """, {g:[{first:'initial'}]}
    assert.deepEqual model.buildOutputData(), {g:[{first:'initial'}]}
    done()
  it 'restores a repeating model group to initial value', (done) ->
    model = fb.fromCoffee """
      group 'g', repeating: true, value:[{first:'default'}]
      .field 'first'
      """
    assert.deepEqual model.buildOutputData(), {g:[{first:'default'}]}
    done()
  it 'applies data over the intiial value in a repeating model group', (done) ->
    model = fb.fromCoffee """
      group 'g', repeating: true, value:[{first:'default'}]
      .field 'first'
      """, {g:[{first:'initial'}]}
    assert.deepEqual model.buildOutputData(), {g:[{first:'initial'}]}
    model.applyData {g:[{first: 'newer'}]}
    assert.deepEqual model.buildOutputData(), {g:[{first:'newer'}]}
    done()
  it 'applies data over the intiial value in a repeating model group when clear=true', (done) ->
    model = fb.fromCoffee """
      group 'g', repeating: true, value:[{first:'default'}]
      .field 'first'
      """, {g:[{first:'initial'}]}
    assert.deepEqual model.buildOutputData(), {g:[{first:'initial'}]}
    model.applyData {g:[{first: 'newer'}]}, true
    assert.deepEqual model.buildOutputData(), {g:[{first:'newer'}]}
    done()
  it 'applies data over the intiial value in a repeating model group when purgeDefaults=true', (done) ->
    model = fb.fromCoffee """
      group 'g', repeating: true, value:[{first:'default'}]
      .field 'first'
      """, {g:[{first:'initial'}]}
    assert.deepEqual model.buildOutputData(), {g:[{first:'initial'}]}
    model.applyData {g:[{first: 'newer'}]}, false, true
    assert.deepEqual model.buildOutputData(), {g:[{first:'newer'}]}
    done()
  it 'applies data over the intiial value in a repeating model group when both clear and purgeDefaults=true', (done) ->
    model = fb.fromCoffee """
      group 'g', repeating: true, value:[{first:'default'}]
      .field 'first'
      """, {g:[{first:'initial'}]}
    assert.deepEqual model.buildOutputData(), {g:[{first:'initial'}]}
    model.applyData {g:[{first: 'newer'}]}, true, true
    assert.deepEqual model.buildOutputData(), {g:[{first:'newer'}]}
    done()
  it 'does not change a repeating model group if no data is supplied', (done) ->
    model = fb.fromCoffee """
      group 'g', repeating: true, value:[{first:'default'}]
      .field 'first'
      """
    assert.deepEqual model.buildOutputData(), {g:[{first:'default'}]}
    model.applyData {}
    assert.deepEqual model.buildOutputData(), {g:[{first:'default'}]}
    done()
  it 'restores intiial value in a repeating model group if no data is supplied and clear=true', (done) ->
    model = fb.fromCoffee """
      group 'g', repeating: true, value:[{first:'default'}]
      .field 'first'
      """
    assert.deepEqual model.buildOutputData(), {g:[{first:'default'}]}
    model.applyData {g:[first:"newer"]}
    assert.deepEqual model.buildOutputData(), {g:[{first:'newer'}]}
    model.applyData {}, true
    assert.deepEqual model.buildOutputData(), {g:[{first:'default'}]}
    done()
  it 'clears s repeating model group if no data is supplied and both clear and purgeDefaults=true', (done) ->
    model = fb.fromCoffee """
      group 'g', repeating: true, value:[{first:'default'}]
      .field 'first'
      """
    assert.deepEqual model.buildOutputData(), {g:[{first:'default'}]}
    model.applyData {g:[first:"newer"]}
    assert.deepEqual model.buildOutputData(), {g:[{first:'newer'}]}
    model.applyData {}, true, true
    assert.deepEqual model.buildOutputData(), {g:[]}
    done()
  it 'does not change a repeating model group if no data is supplied and purgeDefaults=true but clear=false', (done) ->
    model = fb.fromCoffee """
      group 'g', repeating: true, value:[{first:'default'}]
      .field 'first'
      """
    assert.deepEqual model.buildOutputData(), {g:[{first:'default'}]}
    model.applyData {g:[first:"newer"]}
    assert.deepEqual model.buildOutputData(), {g:[{first:'newer'}]}
    model.applyData {}, false, true
    assert.deepEqual model.buildOutputData(), {g:[{first:'newer'}]}
    done()
