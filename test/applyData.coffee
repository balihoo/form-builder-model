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
  it 'applies data over the initial value in a repeating model group when clear=true', (done) ->
    model = fb.fromCoffee """
      group 'g', repeating: true, value:[{first:'default'}]
      .field 'first'
      """, {g:[{first:'initial'}]}
    assert.deepEqual model.buildOutputData(), {g:[{first:'initial'}]}
    model.applyData {g:[{first: 'newer'}]}, true
    assert.deepEqual model.buildOutputData(), {g:[{first:'newer'}]}
    done()
  it 'applies data over the initial value in a repeating model group when purgeDefaults=true', (done) ->
    model = fb.fromCoffee """
      group 'g', repeating: true, value:[{first:'default'}]
      .field 'first'
      """, {g:[{first:'initial'}]}
    assert.deepEqual model.buildOutputData(), {g:[{first:'initial'}]}
    model.applyData {g:[{first: 'newer'}]}, false, true
    assert.deepEqual model.buildOutputData(), {g:[{first:'newer'}]}
    done()
  it 'applies data over the initial value in a repeating model group when both clear and purgeDefaults=true', (done) ->
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
  it 'restores initial value in a repeating model group if no data is supplied and clear=true', (done) ->
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
  it 'clears a repeating model group if no data is supplied and both clear and purgeDefaults=true', (done) ->
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
  it 'sets the value of template fields', (done) ->
    model = fb.fromCoffee """
      field 'a'
      field 'b', visible: false, template:'a'""",
      {a:'{{{city}}}'}
    assert.deepEqual model.buildOutputData(), {a:'{{{city}}}', b:''}
    model.applyData {city:'Boise'}
    assert.deepEqual model.buildOutputData(), {a:'{{{city}}}', b:'Boise'}
    model.applyData {a:'{{{state}}}'}
    model.applyData {state:'ID'}
    assert.deepEqual model.buildOutputData(), {a:'{{{state}}}', b:'ID'}
    done()

  describe "ensure that any field with options contains it's value in those options", ->
    context 'when type is select', ->
      it 'adds when missing in select field', ->
        model = fb.fromCoffee """
          field 'f'
          .option 'first'
        """, {f:'second'}
        assert.strictEqual model.child('f').options.length, 2
      it 'added options from the value are selected', ->
        model = fb.fromCoffee """
          field 'f'
          .option 'first'
        """, f:'second'
        assert model.child('f.second').selected
      it 'doesnt add when not missing in select field', ->
        model = fb.fromCoffee """
          field 'f'
          .option 'first'
        """, {f:'first'}
        assert.strictEqual model.child('f').options.length, 1
    context 'when type is multiselect', ->
      it 'adds when missing in multiselect fields, as a string', ->
        model = fb.fromCoffee """
          field 'f', type:'multiselect'
          .option 'first'
        """, {f:'second'}
        assert.strictEqual model.child('f').options.length, 2
      it 'adds when missing in multiselect fields, as an array', ->
        model = fb.fromCoffee """
          field 'f', type:'multiselect'
          .option 'first'
        """, {f:['second']}
        assert.strictEqual model.child('f').options.length, 2
      it 'added options from the value are selected, as a string', ->
        model = fb.fromCoffee """
          field 'f', type:'multiselect'
          .option 'first'
        """, f:'second'
        assert model.child('f.second').selected
      it 'added options from the value are selected, as an array', ->
        model = fb.fromCoffee """
          field 'f', type:'multiselect'
          .option 'first'
        """, f:['second']
        assert model.child('f.second').selected
      it 'doesnt add when not missing in multiselect field', ->
        model = fb.fromCoffee """
          field 'f', type:'multiselect'
          .option 'first'
        """, {f:['first']}
        assert.strictEqual model.child('f').options.length, 1
      it 'adds multiple values, found then not found', ->
        model = fb.fromCoffee """
          field 'f', type: 'multiselect'
            .option 'a'
            .option 'b'
        """, f:['a','c']
        assert.strictEqual model.child('f').options.length, 3
      it 'adds multiple values, not found then found', ->
        model = fb.fromCoffee """
          field 'f', type: 'multiselect'
            .option 'a'
            .option 'b'
        """, f:['c','a']
        assert.strictEqual model.child('f').options.length, 3
    it 'adds the value as an option to image fields', ->
      model = fb.fromCoffee """
        field 'f', type:'image'
        .option
          fileID: 1
          fileUrl: 'url1'
          fileThumbnail: 'thumb1'
      """, {f:{fileID:2, fileUrl:'url2', fileThumbnail:'thumb2'}}
      assert.strictEqual model.child('f').options.length, 2
      assert.strictEqual model.child('f').options[1].fileID, 2
    it 'doesnt add when not missing in image field', ->
      model = fb.fromCoffee """
        field 'f', type:'image'
        .option
          fileID: 1
          fileUrl: 'url1'
          fileThumbnail: 'thumb1'
      """, {f:{fileID:1, fileUrl:'', fileThumbnail:''}}
      assert.strictEqual model.child('f').options.length, 1
      assert.strictEqual model.child('f').options[0].fileUrl, 'url1'

  it 'updates global data variable', ->
    model = fb.fromCoffee "field 'foo', dynamicValue: -> data?.val", val:'initial'
    foo = model.child 'foo'
    assert.strictEqual foo.value, 'initial'
    
    model.applyData val:'second'
    assert.strictEqual foo.value, 'second'

  context 'when mixing objects and nulls', ->
    dataObj =
      hours:
        mon:
          open:
            hours:6
            minutes:0
    dataNull =
      hours:
        mon: null

    modelCoffee = """
      group 'hours'
      .group 'mon'
      .group 'open'
      .field 'hours'
      .field 'minutes'
    """
    it 'obj then null', ->
      model = fb.fromCoffee modelCoffee
      model.applyData dataObj, true
      model.clear()
      model.applyData dataNull, true
    it 'null then obj', ->
      model = fb.fromCoffee modelCoffee
      model.applyData dataNull, true
      model.clear()
      model.applyData dataObj, true
  it 'copies the inputdata so future applyData calls dont merge into it', ->
    inData = b:'b new'
    model = fb.fromCoffee 'field "a", value:"a default"\nfield "b"', inData
    assert.deepEqual model.buildOutputData(), a:'a default', b:'b new'
    #previously,
    model.applyData inData, true, true
    assert.deepEqual model.buildOutputData(), a:'', b:'b new'
    assert.deepEqual inData, b:'b new'
  it 'clones data', ->
    #use a non-primitive to assign reference
    model = fb.fromCoffee 'field "f", type:"multiselect"'
    data = f:['orig']
    model.applyData data
    data.f.push 'added to data'
    assert.strictEqual model.child('f').value.length, 1, "changes to data don't affect model"
    assert.strictEqual data.f.length, 2 #we added one for a previous test
    model.child('f').value.push 'added to model'
    assert.strictEqual data.f.length, 2, "changes to model don't affect data"
    