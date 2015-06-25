assert = require('assert')
formbuilder = require('../formbuilder')
describe 'fromCoffee', ->
  it 'can build a simple model', (done) ->
    model = formbuilder.fromCoffee('field "a"')
    assert.strictEqual typeof model, 'object', 'built an object'
    assert.strictEqual model.child('a').name, 'a', 'has the correct child'
    done()
  it 'can apply data to a model', (done) ->
    model = formbuilder.fromCoffee('field "a"\nfield "b"',
      a: 'first'
      b: 'second')
    assert.strictEqual model.child('a').value, 'first', 'applied first datum'
    assert.strictEqual model.child('b').value, 'second', 'applied second datum'
    done()
describe 'fromPackage', ->
  it 'can build a model with no data', (done) ->
    pkg =
      formid: 123
      forms:[{formid:123, model:"field 'foo', value:'I pity da'"}]
    model = formbuilder.fromPackage pkg
    assert.deepEqual model.buildOutputData(), {foo:'I pity da'}
    done()
  it 'can build packages with imports', (done) ->
    pkg =
      formid:33
      forms: [
        {
          formid:34
          model:'field "name", value:"Bob, son of #{imports.parent.child(\"name\").value}"'
          imports:[
            {importformid:35, namespace:'parent'}
          ]
        }
        {
          formid:33
          model:'''
              field 'name', value:"Charlie, son of #{imports.parent.child('name').value}"
              field "gpa", value:imports.grandparent.child('name').value
            '''
          imports:[
            {importformid:34, namespace:'parent'}
            {importformid:35, namespace:'grandparent'}
          ]
        }
        {
          formid:35
          model:'field "name", value:"Abe"'
        }
      ]

    model = formbuilder.fromPackage(pkg)

    assert.deepEqual model.buildOutputData(), {
      name: 'Charlie, son of Bob, son of Abe'
      gpa: 'Abe'
    }
    done()
  it 'can take data in package', (done) ->
    pkg =
      formid: 123
      forms:[{formid:123, model:"field 'foo', value:'I pity da'"}]
      data:{foo:'tball'}
    model = formbuilder.fromPackage pkg
    assert.deepEqual model.buildOutputData(), {foo:'tball'}
    done()
  it 'can take data as second parameter', (done) ->
    pkg =
      formid: 1
      forms:[{formid:1, model:"field 'foo'"}]
    model = formbuilder.fromPackage pkg, {foo:'bar'}
    assert.deepEqual model.buildOutputData(), {foo:'bar'}
    done()
  it 'can take data in both places, second parameter extending package', (done) ->
    pkg =
      formid: 1
      forms:[{formid:1, model:"field 'foo'\nfield 'bar'"}]
      data:{foo:'pkg foo',bar:'pkg bar'}
    model = formbuilder.fromPackage pkg, {foo:'second foo'}
    assert.deepEqual model.buildOutputData(), {foo:'second foo', bar:'pkg bar'}
    done()
  it 'handles errors in the main form', (done) ->
    pkg =
      formid: 1
      forms:[
        {formid:1, model:'applesauce'}
      ]
    result =
      try
        formbuilder.fromPackage pkg
      catch e
        e.message

    assert.strictEqual result, "applesauce is not defined"
    done()
  it 'handles errors in an import', (done) ->
    pkg =
      formid: 2
      forms: [
        {formid:2, model:"field 'foo', value:imports.i.foo()", imports:[{importformid:3, namespace:'i'}]}
        {formid:3, model:"root.foo = -> 'value for foo'\ncheeseburger"}
      ]
    result =
      try
        formbuilder.fromPackage pkg
      catch e
        e.message
    assert.strictEqual result, "cheeseburger is not defined"
    done()

