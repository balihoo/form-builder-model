assert = require 'assert'
fb = require '../formbuilder'

describe.only 'beforeInput', ->
  context 'on a field', ->
    it 'modifies applied value prior to saving', ->
      model = fb.fromCoffee """
        field 'foo', beforeInput: (val) ->
          val + ' modified'
        field 'bar'
      """, foo:'original', bar:'original'
      assert.strictEqual model.child('foo').value, 'original modified', 'beforeInput used during build'
      assert.strictEqual model.child('bar').value, 'original',
        'field without beforeInput uses unmodified value on build'
      model.clear()
      model.applyData {foo:'original2', bar:'original2'}
      assert.strictEqual model.child('foo').value, 'original2 modified', 'beforeInput used during applyData'
      assert.strictEqual model.child('bar').value, 'original2',
        'field witout beforeInput uses unmodified value on applyData'
  context 'on a group', ->
    it 'modifies applied value prior to applying to children', ->
      model = fb.fromCoffee """
        g = group 'g', beforeInput: (val) ->
          val.f1 += '+g'
          val
        g.field 'f1'
        g.field 'f2'
      """, g:{f1:'original',f2:'original'}
      assert.strictEqual model.child('g.f1').value, 'original+g', 'beforeInput used during build'
      assert.strictEqual model.child('g.f2').value, 'original',
        'field without beforeInput uses unmodified value on build'
      model.clear()
      model.applyData g:{f1:'original2',f2:'original2'}
      assert.strictEqual model.child('g.f1').value, 'original2+g', 'beforeInput used during applyData'
      assert.strictEqual model.child('g.f2').value, 'original2',
        'field without beforeInput uses unmodified value on applyData'
    it 'allows children to further modify value prior to input', ->
      model = fb.fromCoffee """
        g = group 'g', beforeInput: (val) ->
          val.f1 += '+g'
          val
        g.field 'f1', beforeInput: (val) ->
          val + '+f1'
        g.field 'f2'
      """, g:{f1:'original', f2:'original'}
      assert.strictEqual model.child('g.f1').value, 'original+g+f1', 'beforeInput used during build'
      assert.strictEqual model.child('g.f2').value, 'original',
        'field without beforeInput uses unmodified value on build'
      model.clear()
      model.applyData g:{f1:'original2',f2:'original2'}
      assert.strictEqual model.child('g.f1').value, 'original2+g+f1', 'beforeInput used during applyData'
      assert.strictEqual model.child('g.f2').value, 'original2',
        'field without beforeInput uses unmodified value on applyData'

#  context 'on a repeating group'

#describe 'beforeOutput', ->
  
#todo:? make sure reciprocal.  Would we want to warn/error if not true?
# maybe default add a test.  build output data, then apply and build again, make sure the same.
# If I dont care about reciprocal, then split into different files.