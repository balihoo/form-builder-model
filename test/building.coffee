assert = require 'assert'
fb = require '../formbuilder'

describe 'fromCoffee', ->
  it 'can build a field', (done) ->
    model = fb.fromCoffee 'field "a"'
    assert.strictEqual typeof model, 'object', 'built an object'
    assert.strictEqual model.constructor.name, 'ModelGroup', 'returned value is correct class'
    a = model.child 'a'
    assert.strictEqual a.name, 'a', 'has the correct name'
    assert.strictEqual a.title, 'a', 'has the correct title'
    assert.strictEqual a.constructor.name, 'ModelField', 'field has correct constructor'
    assert.strictEqual a.value, '', 'model has the correct default value'
    done()

  it 'can build a field with a description', (done) ->
    model = fb.fromCoffee 'field "a", value: "foo", description: "bar"'
    assert.strictEqual typeof model, 'object', 'built an object'
    assert.strictEqual model.constructor.name, 'ModelGroup', 'returned value is correct class'
    a = model.child 'a'
    assert.strictEqual a.name, 'a', 'has the correct name'
    assert.strictEqual a.title, 'a', 'has the correct title'
    assert.strictEqual a.constructor.name, 'ModelField', 'field has correct constructor'
    assert.strictEqual a.value, 'foo', 'model has the correct value'
    assert.strictEqual a.description, 'bar', 'model has the correct description'
    done()
    
  it 'can build a field with a template string', (done) ->
    model = fb.fromCoffee """
      field 'a'
      field 'b', visible: false, template:'a'""",
      {a:'{{{city}}}'}
    a = model.child 'a'
    b = model.child 'b'
    assert.strictEqual a.value, '{{{city}}}'
    assert.strictEqual b.value, ''
    done()

  it 'can build a field with a template object', (done) ->
    model = fb.fromCoffee """
      field 'a'
      field 'b', visible: false, template:root.child('a')""",
      {a:'{{{city}}}'}
    a = model.child 'a'
    b = model.child 'b'
    assert.strictEqual a.value, '{{{city}}}'
    assert.strictEqual b.value, ''
    done()

  it 'can build a field with a template and render mustache', (done) ->
    model = fb.fromCoffee """
      field 'a'
      field 'b', visible: false, template:'a'""",
      {a:'{{{city}}}', city:'Boise'}
    a = model.child 'a'
    b = model.child 'b'
    assert.strictEqual a.value, '{{{city}}}'
    assert.strictEqual b.value, 'Boise'
    done()

  it 'can build a field with a template string to child object', (done) ->
    model = fb.fromCoffee """
      group 'a'
        .field 'b'
      field 'c', visible: false, template:'a.b'""",
      {a:{b:'{{{stuff}}}'}, stuff:'candy'}
    b = model.child 'a.b'
    c = model.child 'c'
    assert.strictEqual b.value, '{{{stuff}}}'
    assert.strictEqual c.value, 'candy'
    done()

  it 'can applyData for mustache input', (done) ->
    model = fb.fromCoffee """
      field 'a'
      field 'b', visible: false, template:'a' """
    #data is applied in more than one stage and merged together.
    model.applyData a:'I like {{{stuff}}}'
    model.applyData stuff:'candy'
    assert.deepEqual model.buildOutputData(), {
      a:'I like {{{stuff}}}'
      b:'I like candy'
    }
    done()

  it 'can applyData for mustache input in a reversed order', (done) ->
    model = fb.fromCoffee """
      field 'a'
      field 'b', visible: false, template:'a' """
    #data is applied in more than one stage and merged together.
    model.applyData stuff:'candy'
    model.applyData a:'I like {{{stuff}}}'
    assert.deepEqual model.buildOutputData(), {
      a:'I like {{{stuff}}}'
      b:'I like candy'
    }
    done()

  it 'can build a model that contains groups', (done) ->
    model = fb.fromCoffee """
      group 'g'
      .field 'f'
    """
    group = model.children[0]
    assert.strictEqual group.constructor.name, 'ModelGroup', 'group has the correct class name'
    assert.strictEqual group.children.length, 1, 'group has 1 child'
    assert.strictEqual group.name, 'g', 'group has the correct name'
    
    done()

  it 'can apply data to a model', (done) ->
    model = fb.fromCoffee('field "a"\nfield "b"',
      a: 'first'
      b: 'second')
    assert.strictEqual model.child('a').value, 'first', 'applied first datum'
    assert.strictEqual model.child('b').value, 'second', 'applied second datum'
    done()

  it 'can apply data to a model multiple times', (done) ->
    model = fb.fromCoffee "field 'a', dynamicValue: -> data.b", b:'c'
    a = model.child 'a'
    assert.deepEqual model.buildOutputData(), a:'c'
    model.applyData b:'d'
    assert.deepEqual model.buildOutputData(), a:'d'
    done()
    
  it 'uses default if no data is provided', (done) ->
    model = fb.fromCoffee "field 'a', value:'b'"
    assert.strictEqual model.child('a').value, 'b', 'uses default value'
    done()
    
describe 'fromPackage', ->
  it 'can build a model with no data', (done) ->
    pkg =
      formid: 123
      forms: [{formid: 123, model: "field 'foo', value:'I pity da'"}]
    model = fb.fromPackage pkg
    assert.deepEqual model.buildOutputData(), {foo: 'I pity da'}
    done()
  it 'can build packages with imports', (done) ->
    pkg =
      formid: 33
      forms: [
        {
          formid: 34
          model: 'field "name", value:"Bob, son of #{imports.parent.child(\"name\").value}"'
          imports: [
            {importformid: 35, namespace: 'parent'}
          ]
        }
        {
          formid: 33
          model: '''
            field 'name', value:"Charlie, son of #{imports.parent.child('name').value}"
            field "gpa", value:imports.grandparent.child('name').value
          '''
          imports: [
            {importformid: 34, namespace: 'parent'}
            {importformid: 35, namespace: 'grandparent'}
          ]
        }
        {
          formid: 35
          model: 'field "name", value:"Abe"'
        }
      ]

    model = fb.fromPackage(pkg)

    assert.deepEqual model.buildOutputData(), {
      name: 'Charlie, son of Bob, son of Abe'
      gpa: 'Abe'
    }
    done()
  it 'can take data in package', (done) ->
    pkg =
      formid: 123
      forms: [{formid: 123, model: "field 'foo', value:'I pity da'"}]
      data: {foo: 'tball'}
    model = fb.fromPackage pkg
    assert.deepEqual model.buildOutputData(), {foo: 'tball'}
    done()
  it 'can take data as second parameter', (done) ->
    pkg =
      formid: 1
      forms: [{formid: 1, model: "field 'foo'"}]
    model = fb.fromPackage pkg, {foo: 'bar'}
    assert.deepEqual model.buildOutputData(), {foo: 'bar'}
    done()
  it 'can take data in both places, second parameter extending package', (done) ->
    pkg =
      formid: 1
      forms: [{formid: 1, model: "field 'foo'\nfield 'bar'"}]
      data: {foo: 'pkg foo', bar: 'pkg bar'}
    model = fb.fromPackage pkg, {foo: 'second foo'}
    assert.deepEqual model.buildOutputData(), {foo: 'second foo', bar: 'pkg bar'}
    done()
  it 'handles errors in the main form', (done) ->
    pkg =
      formid: 1
      forms: [
        {formid: 1, model: 'applesauce'}
      ]
    result =
      try
        fb.fromPackage pkg
      catch e
        e.message

    assert.strictEqual result, "applesauce is not defined"
    done()
  it 'handles errors in an import', (done) ->
    pkg =
      formid: 2
      forms: [
        {formid: 2, model: "field 'foo', value:imports.i.foo()", imports: [{importformid: 3, namespace: 'i'}]}
        {formid: 3, model: "root.foo = -> 'value for foo'\ncheeseburger"}
      ]
    result =
      try
        fb.fromPackage pkg
      catch e
        e.message
    assert.strictEqual result, "cheeseburger is not defined"
    done()