assert = require 'assert'
fb = require '../src/formbuilder'
jiff = require 'jiff'

describe 'getChanges', ->
  sortChangeFunc = (a,b) ->
    a.name.localeCompare(b.name)
  it 'returns raw diff', (done) ->
    model = fb.fromCoffee "field 'something'\nfield 'another'", {something: 'endgame'}
    initial =
      something: 'something initial'
      another: 'another initial'
    diff = fb.getChanges model, initial
    assert.deepEqual diff.patch, jiff.diff(initial, model.buildOutputData(), invertible:false)
    done()
  it 'works for single field', (done) ->
    model = fb.fromCoffee "field name:'foo', title:'foo title'", foo: 'current'
    changes = fb.getChanges model, foo: 'initial'
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
    model = fb.fromCoffee """
        field 'first', value:'one'
        group 'container'
        .field 'second', value:'two'
        .field 'third', value:'three'
        .group 'innergroup'
        .field 'fourth', value:'four'
      """
    result = fb.getChanges model, {
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

  it 'shows no changes with initial data is empty and no changes are made', (done) ->
    model = fb.fromCoffee "field name:'foo', title:'foo title'"
    result = fb.getChanges model, {}
    assert.deepEqual result.changes, []
    done()
  it 'doesnt show diff for initial values that have no field', (done) ->
    model = fb.fromCoffee "field name:'foo', title:'foo title'"
    result = fb.getChanges model, {foo:'initial', bar:'ignored'}
    assert.deepEqual result.changes, [
      {
        name: '/foo'
        title: 'foo title'
        before: 'initial'
        after: ''
      }
    ]
    done()

  ###
    when default
      current default, provided
      initial default, provided, missing
    when no default
      current provided
      initial provided, missing
  ###
  context 'when a field has a default value', ->
    model = null
    beforeEach -> model = fb.fromCoffee "field 'foo', value:'bar'"
    it 'current is default, initial is default', ->
      defaults = model.buildOutputData()
      result = model.getChanges defaults
      assert.deepEqual result.changes, []
    it 'current is default, initial is provided', ->
      result = model.getChanges {foo:'initial'}
      assert.deepEqual result.changes, [{
        name: '/foo'
        title: 'foo'
        before: 'initial'
        after: 'bar'
      }]
    it 'current is default, initial is missing', ->
      result = model.getChanges {}
      assert.deepEqual result.changes, []
    it 'current is provided, initial is default', ->
      model.child('foo').value = 'after'
      result = model.getChanges {foo:'bar'}
      assert.deepEqual result.changes, [{
        name: '/foo'
        title: 'foo'
        before: 'bar'
        after: 'after'
      }]
    it 'current is provided, initial is provided', ->
      model.child('foo').value = 'after'
      result = model.getChanges {foo:'initial'}
      assert.deepEqual result.changes, [{
        name: '/foo'
        title: 'foo'
        before: 'initial'
        after: 'after'
      }]
    it 'current is provided, initial is missing', ->
      model.child('foo').value = 'after'
      result = model.getChanges {}
      assert.deepEqual result.changes, [{
        name: '/foo'
        title: 'foo'
        before: 'bar'
        after: 'after'
      }]

  context 'when a field has no default value', ->
    model = null
    beforeEach -> model = fb.fromCoffee "field 'foo'"

    it 'current is provided, initial is provided', ->
      model.child('foo').value = 'after'
      result = model.getChanges foo:'initial'
      assert.deepEqual result.changes, [{
        name: '/foo'
        title: 'foo'
        before: 'initial'
        after: 'after'
      }]

    it 'current is provided, initial is missing', ->
      model.child('foo').value = 'after'
      result = model.getChanges {}
      assert.deepEqual result.changes, [{
        name: '/foo'
        title: 'foo'
        before: ''
        after: 'after'
      }]

  it 'ignores values that dont match a field', ->
    model = fb.fromCoffee "field 'one', value:'first'"
    result = model.getChanges twi:'second'
    assert.deepEqual result.changes, []

  it 'handles multiselects (with array values)', (done) ->
    model = fb.fromCoffee "field 'sel', type:'multiselect'", sel:['one','two']
    result = fb.getChanges model, sel:['two','three']
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
    model = fb.fromCoffee "group 'g', repeating:true\n.field 'f'", g: [
      {
        f: "asdf"
      },
      {
        f: "jkl;"
      }
    ]
    result = fb.getChanges model, g:[
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
  it 'is callable from the model root', (done) ->
    model = fb.fromCoffee "field 'a', value:'after'"
    result = model.getChanges({a:'before'})
    assert.deepEqual result.changes, [{
      name:'/a'
      title:'a'
      before:'before'
      after:'after'
    }]
    done()
  it 'direct test for model changes', (done) ->
    model = fb.fromCoffee "field 'a'\nfield 'b'"
    initial = model.buildOutputData()
    model.child('b').value = 'changed'
    result = model.getChanges initial
    assert.deepEqual result.changes, [{
      name: '/b'
      title: 'b'
      before: ''
      after: 'changed'
    }]
    done()
  it "detects changes to a field with a default value", (done) ->
    model = fb.fromCoffee "field 'a', value:'def'"
    model.child('a').value = 'changed'
    assert.deepEqual model.getChanges(a:'init').changes, [{
      name: '/a'
      title: 'a'
      before: 'init'
      after: 'changed'
    }]
    assert.deepEqual model.getChanges(b:'ignored').changes, [{
      name: '/a'
      title: 'a'
      before: 'def'
      after: 'changed'
    }]
    done()
  it 'detects default values as changes if different', (done) ->
    model = fb.fromCoffee "field 'a', value:'def'"
    assert.deepEqual model.getChanges(a:'init').changes, [{
      name: '/a'
      title: 'a'
      before: 'init'
      after: 'def'
    }]
    done()
  it "does not detect default values as changes if no changes", (done) ->
    #Note: this is because initial data clears even default values
    model = fb.fromCoffee "field 'a', value: 'def'"
    assert.deepEqual model.getChanges(b:'ignored').changes, []
    done()
  it 'works for repeating field groups with beforeInput/beforeOutput functions', ->
    expected = {
      changes: [
        {
          name: "/g",
          title: "g",
          before: {
            a: {
              f: "initial value"
            }
          },
          after: {
            a: {
              f: "new value"
            }
          }
        }
      ],
      patch: [
        {
          op: "replace",
          path: "/g/a/f",
          value: "new value"
        }
      ]
    }

    model = fb.fromCoffee """
      group 'g',
        repeating: true
        beforeInput: (value) ->
          results = []
          for k,v of value
            v.id = k
            results.push v
          results

        beforeOutput: (values) ->
          results = {}
          for value in values
            results[value.id] = value
            delete value.id
          results
      .field 'id'
      .field 'f'
"""
    intialData = g: a: f: "initial value"
    editedData = g: a: f: "new value"
    model.applyData jiff.clone intialData
    model.applyData jiff.clone editedData
    assert.deepEqual model.getChanges(intialData), expected