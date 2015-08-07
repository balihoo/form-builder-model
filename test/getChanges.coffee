assert = require 'assert'
fb = require '../formbuilder'
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
  it 'handles fields not present in initial', (done) ->
    model = fb.fromCoffee "field 'first', value:'one'\nfield 'second', value:'two'"
    result = fb.getChanges model, {first:'one initial'}
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
    ]
    done()
  it 'displays only changed fields', (done) ->
    model = fb.fromCoffee "field 'first', value:'one'\nfield 'second', value:'two'"
    result = fb.getChanges model, {first:'one'}
    assert.deepEqual result.changes, [
      {
        name: '/second'
        title: 'second'
        before: ''
        after: 'two'
      }
    ]
    done()
  it 'handles fields not present in final', (done) ->
    model = fb.fromCoffee "field 'first', value:'one'\nfield 'second', value:'two'"
    result = fb.getChanges model, {first:'one initial', second:'two', third:'three'}
    assert.deepEqual result.changes.sort(sortChangeFunc), [
      {
        name: '/first'
        title: 'first'
        before: 'one initial'
        after: 'one'
      }
    ]
    done()
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
      before: ''
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
  it "detects default values as changes if no changes", (done) ->
    #Note: this is because initial data clears even default values
    model = fb.fromCoffee "field 'a', value: 'def'"
    assert.deepEqual model.getChanges(b:'ignored').changes, [{
      name: '/a'
      title: 'a'
      before: ''
      after: 'def'
    }]
    done()
    