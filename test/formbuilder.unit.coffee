assert = require 'assert'
formbuilder = require '../formbuilder'
jiff = require 'jiff'

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
      forms: [{formid: 123, model: "field 'foo', value:'I pity da'"}]
    model = formbuilder.fromPackage pkg
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

    model = formbuilder.fromPackage(pkg)

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
    model = formbuilder.fromPackage pkg
    assert.deepEqual model.buildOutputData(), {foo: 'tball'}
    done()
  it 'can take data as second parameter', (done) ->
    pkg =
      formid: 1
      forms: [{formid: 1, model: "field 'foo'"}]
    model = formbuilder.fromPackage pkg, {foo: 'bar'}
    assert.deepEqual model.buildOutputData(), {foo: 'bar'}
    done()
  it 'can take data in both places, second parameter extending package', (done) ->
    pkg =
      formid: 1
      forms: [{formid: 1, model: "field 'foo'\nfield 'bar'"}]
      data: {foo: 'pkg foo', bar: 'pkg bar'}
    model = formbuilder.fromPackage pkg, {foo: 'second foo'}
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
        formbuilder.fromPackage pkg
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
        formbuilder.fromPackage pkg
      catch e
        e.message
    assert.strictEqual result, "cheeseburger is not defined"
    done()
describe 'getChanges', ->
  sortChangeFunc = (a,b) ->
    a.name.localeCompare(b.name)
  it 'returns raw diff', (done) ->
    model = formbuilder.fromCoffee "field 'something'\nfield 'another'", {something: 'endgame'}
    initial =
      something: 'something initial'
      another: 'another initial'
    diff = formbuilder.getChanges model, initial
    assert.deepEqual diff.patch, jiff.diff(initial, model.buildOutputData(), invertible:false)
    done()
  it 'works for single field', (done) ->
    model = formbuilder.fromCoffee "field name:'foo', title:'foo title'", foo: 'current'
    changes = formbuilder.getChanges model, foo: 'initial'
    assert.deepEqual changes, {
      changes: [
        {
          name: '/foo'
          title: 'foo title'
          before: 'initial'
          after: 'current'
        }
      ],
      patch: [
        {
          op: 'replace'
          path: '/foo'
          value: 'current'
        }
      ]
    }
    done()
  it 'works on complex, hierarchical models', (done) ->
    model = formbuilder.fromCoffee """
field 'first', value:'one'
group 'container'
.field 'second', value:'two'
.field 'third', value:'three'
.group 'innergroup'
.field 'fourth', value:'four'
"""
    result = formbuilder.getChanges model, {
      first:'initial one'
      container:
        second: ''
        third: 'three'
        innergroup:
          fourth: 'initial four'
    }
    assert.deepEqual result.changes.sort(sortChangeFunc), [
      {
        name: '/first'
        title: 'first'
        before: 'initial one'
        after: 'one'
      }
      {
        name: '/container/second'
        title: 'second'
        before: ''
        after: 'two'
      }
      #third didn't change
      {
        name: '/container/innergroup/fourth'
        title: 'fourth'
        before: 'initial four'
        after: 'four'
      }
    ].sort(sortChangeFunc)
    done()
  it 'handles values not present in initial', (done) ->
    model = formbuilder.fromCoffee "field name:'foo', title:'foo title'", foo: 'current'
    result = formbuilder.getChanges model, {}
    assert.deepEqual result.changes, [
      {
        name: '/foo'
        title: 'foo title'
        before: ''
        after: 'current'
      }
    ]
    done()
  it 'handles values not present in current', (done) ->
    model = formbuilder.fromCoffee "field name:'foo', title:'foo title'"
    result = formbuilder.getChanges model, {foo:'initial'}
    assert.deepEqual result.changes, [
      {
        name: '/foo'
        title: 'foo title'
        before: 'initial'
        after: ''
      }
    ]
    done()
  it 'handles fields not present in initial', (done) ->
    model = formbuilder.fromCoffee "field 'first', value:'one'\nfield 'second', value:'two'"
    result = formbuilder.getChanges model, {first:'one initial'}
    assert.deepEqual result.changes.sort(sortChangeFunc), [
      {
        name: '/first'
        title: 'first'
        before: 'one initial'
        after: 'one'
      }
      {
        name: '/second'
        title: 'second'
        before: ''
        after: 'two'
      }
    ].sort(sortChangeFunc)
    done()
  it 'handles fields not present in final', (done) ->
    model = formbuilder.fromCoffee "field 'first', value:'one'\nfield 'second', value:'two'"
    result = formbuilder.getChanges model, {first:'one initial', second:'two', third:'three'}
    assert.deepEqual result.changes.sort(sortChangeFunc), [
      {
        name: '/first'
        title: 'first'
        before: 'one initial'
        after: 'one'
      }
    ].sort(sortChangeFunc)
    done()
  it 'handles multiselects (with array values)', (done) ->
    model = formbuilder.fromCoffee "field 'sel', type:'multiselect'", sel:['one','two']
    result = formbuilder.getChanges model, sel:['two','three']
    assert.deepEqual result.changes, [
      {
        name: '/sel'
        title: 'sel'
        before: ['two','three']
        after: ['one','two']
      }
    ]
    done()
  it 'handles repeating groups (with array values)', (done) ->
    model = formbuilder.fromCoffee "group 'g', repeating:true\n.field 'f'", g: [
      {
        f: "asdf"
      },
      {
        f: "jkl;"
      }
    ]
    result = formbuilder.getChanges model, g:[
      {
        f: 'initial first'
      }
      {
        f: 'initial second'
      }
      {
        f: 'initial third'
      }
    ]
    assert.deepEqual result.changes, [
      {
        name: '/g'
        title: 'g'
        before: [
          {
            f: 'initial first'
          }
          {
            f: 'initial second'
          }
          {
            f: 'initial third'
          }
        ]
        after: [
          {
            f: "asdf"
          },
          {
            f: "jkl;"
          }
        ]
      }
    ]
    done()

describe 'clear', ->
  it 'clears a text field', (done) ->
    model = formbuilder.fromCoffee "field 'foo', value:'bar'"
    field = model.child 'foo'
    assert.strictEqual field.value, 'bar'
    field.clear()
    assert.strictEqual field.value, ''
    done()
  it 'clears a multiselect field', (done) ->
    model = formbuilder.fromCoffee "field 'foo', value:['bar'], type:'multiselect'\n.option 'bar'\n.option 'baz'"
    field = model.child 'foo'
    assert.deepEqual field.value, ['bar']
    field.clear()
    assert.deepEqual field.value, []
    done()
  it 'clears a bool field', (done) ->
    model = formbuilder.fromCoffee "field 'foo', value:true, type:'bool'"
    field = model.child 'foo'
    assert.strictEqual field.value, true
    field.clear()
    assert.strictEqual field.value, false
    done()
  it 'clears all fields in a group', (done) ->
    model = formbuilder.fromCoffee """
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
    model = formbuilder.fromCoffee """
group 'g', repeating:true
.field 'f', value:'initial'
"""
    model.child('g').add()
    assert.deepEqual model.buildOutputData(), g:[f:'initial']
    model.child('g').clear()
    assert.deepEqual model.buildOutputData(), g:[]
    done()
  it 'clears an image field', (done) ->
    model = formbuilder.fromCoffee """
field 'i', type:'image', value:{fileID:1, fileUrl:'something'}
.option fileID:1, fileUrl:'something'
"""
    field = model.child 'i'
    assert.deepEqual field.value, {fileID:1, fileUrl:'something'}
    field.clear()
    assert.deepEqual field.value, {}
    done()
  it 'clears a tree field', (done) ->
    model = formbuilder.fromCoffee """
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

describe 'applyData', ->
  it 'applies data to a field', (done) ->
    model = formbuilder.fromCoffee "field 'first'\nfield 'second'", {first:'one',second:'two'}
    assert.deepEqual model.buildOutputData(), {first:'one', second:'two'}
    model.applyData {first:'new one'}
    assert.deepEqual model.buildOutputData(), {first:'new one', second:'two'}
    done()
  it 'clears all when clear=true', (done) ->
    model = formbuilder.fromCoffee "field 'first'\nfield 'second'", {first:'one',second:'two'}
    assert.deepEqual model.buildOutputData(), {first:'one', second:'two'}
    model.applyData {first:'new one'}, true
    assert.deepEqual model.buildOutputData(), {first:'new one', second:''}
    done()
  it 'applies data to nested fields', (done) ->
    model = formbuilder.fromCoffee """
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
    model = formbuilder.fromCoffee """
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
    model = formbuilder.fromCoffee """
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
