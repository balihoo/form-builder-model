assert = require 'assert'
fb = require '../formbuilder'

describe 'beforeInput', ->
  context 'on a field', ->
    it 'modifies applied value prior to saving', ->
      model = fb.fromCoffee """
        field 'foo', beforeInput: (val) ->
          val + ' modified'
        field 'bar'
      """, foo:'original', bar:'original'
      assert.strictEqual model.child('foo').value, 'original modified'
      assert.strictEqual model.child('bar').value, 'original'
      model.clear()
      model.applyData {foo:'original2', bar:'original2'}
      assert.strictEqual model.child('foo').value, 'original2 modified'
      assert.strictEqual model.child('bar').value, 'original2'
    it "doesn't modify applied object outside of building scope", ->
      data = foo:'bar'
      fb.fromCoffee """
        field 'foo', beforeInput: (val) ->
          val + 't'
      """, data
      assert.strictEqual data.foo, 'bar'
    it 'does NOT run when no data is applied to this', -> #todo:correct? plus below
      model = fb.fromCoffee """
        field 'foo', beforeInput: (val) ->
          'not bar'
      """
      assert.strictEqual model.child('foo').value, ''
      model.clear false
      assert.strictEqual model.child('foo').value, ''
      model.applyData thing:'not a field'
      assert.strictEqual model.child('foo').value, ''
    it 'does NOT run for default value', -> #todo:correct? Else doc that val might be nothing. plus below
      model = fb.fromCoffee """
        field 'foo', value:'bar', beforeInput: (val) ->
          'not bar'
      """
      assert.strictEqual model.child('foo').value, 'bar'
      model.clear false #false to not purge defaults
      assert.strictEqual model.child('foo').value, 'bar'
      model.clear true #true purge defaults
      assert.strictEqual model.child('foo').value, ''
    it 'can access instance attributes'
  context 'on a group', ->
    it 'modifies applied value prior to applying to children', ->
      model = fb.fromCoffee """
        g = group 'g', beforeInput: (val) ->
          val.f1 += '+g'
          val
        g.field 'f1'
        g.field 'f2'
      """, g:{f1:'original',f2:'original'}
      assert.strictEqual model.child('g.f1').value, 'original+g'
      assert.strictEqual model.child('g.f2').value, 'original'
      model.clear()
      model.applyData g:{f1:'original2',f2:'original2'}
      assert.strictEqual model.child('g.f1').value, 'original2+g'
      assert.strictEqual model.child('g.f2').value, 'original2'
    it 'allows children to further modify value prior to input', ->
      model = fb.fromCoffee """
        g = group 'g', beforeInput: (val) ->
          val.f1 += '+g'
          val
        g.field 'f1', beforeInput: (val) ->
          val + '+f1'
        g.field 'f2'
      """, g:{f1:'original', f2:'original'}
      assert.strictEqual model.child('g.f1').value, 'original+g+f1'
      assert.strictEqual model.child('g.f2').value, 'original'
      model.clear()
      model.applyData g:{f1:'original2',f2:'original2'}
      assert.strictEqual model.child('g.f1').value, 'original2+g+f1'
      assert.strictEqual model.child('g.f2').value, 'original2'
    it "doesn't modify applied value outside of building scope", ->
      data = g:f:'bar'
      model = fb.fromCoffee """
        g = group 'g', beforeInput: (val) ->
          val.f = 'changed'
          val
        g.field 'f'
      """, data
      assert.strictEqual model.child('g.f').value, 'changed' #make sure it applied
      assert.strictEqual data.g.f, 'bar' #but didn't change the object
    it 'does NOT run when no data is applied to this', ->
      model = fb.fromCoffee """
        g = group 'g', beforeInput: (val) ->
          val.f = 'modified'
          val
        g.field 'f', value:'default'
      """
      assert.strictEqual model.child('g.f').value, 'default'
      model.clear false
      assert.strictEqual model.child('g.f').value, 'default'
      model.applyData a:'b'
      assert.strictEqual model.child('g.f').value, 'default'
    it 'does NOT run for default value', ->
      # groups do not have value or default value, but will initially have fields with empty values.
      model = fb.fromCoffee """
        g = group 'g', beforeInput: (val) ->
          val.f = 'group beforeInput'
          val
        g.field 'f', value:''
      """
      assert.strictEqual model.child('g.f').value, ''
    it 'can access instance attributes'
  context 'on a repeating group', ->
    it 'modifies applied value by adding a new group', ->
      model = fb.fromCoffee """
        g = group 'g', repeating:true, beforeInput: (val) ->
          val.push f:'additional'
          val
        g.field 'f'
      """, g:[f:'original']
      assert.strictEqual model.child('g').value.length, 2
      assert.strictEqual model.child('g').value[0].child('f').value, 'original'
      assert.strictEqual model.child('g').value[1].child('f').value, 'additional'
      model.clear()
      model.applyData g:[f:'original']
      assert.strictEqual model.child('g').value.length, 2
      assert.strictEqual model.child('g').value[0].child('f').value, 'original'
      assert.strictEqual model.child('g').value[1].child('f').value, 'additional'
    it 'modifies applied value by modifying a value in each group', ->
      model = fb.fromCoffee """
        g = group 'g', repeating:true, beforeInput: (val) ->
          for v,i in val
            v.f += i+1 #add index to each value
          val
        g.field 'f'
      """, g:[{f:'one'},{f:'two'}]
      assert.strictEqual model.child('g').value[0].child('f').value, 'one1'
      assert.strictEqual model.child('g').value[1].child('f').value, 'two2'
      model.clear()
      model.applyData g:[{f:'first'},{f:'second'}]
      assert.strictEqual model.child('g').value[0].child('f').value, 'first1'
      assert.strictEqual model.child('g').value[1].child('f').value, 'second2'
    it 'allows children to further modify value', ->
      model = fb.fromCoffee """
        g = group 'g', repeating:true, beforeInput: (val) ->
          for v,i in val
            v.f += i+1 #add index to each value
          val
        g.field 'f', beforeInput: (val) ->
          val + 'mod'
      """, g:[{f:'one'},{f:'two'}]
      assert.strictEqual model.child('g').value[0].child('f').value, 'one1mod'
    it "doesn't modify applied value outside of building scope", ->
      data = g:[f:'bar']
      model = fb.fromCoffee """
        g = group 'g', repeating:true, beforeInput: (val) ->
          val[0].f = 'changed'
          val
        g.field 'f'
      """, data
      assert.strictEqual model.child('g').value[0].child('f').value, 'changed' #make sure it applied
      assert.strictEqual data.g[0].f, 'bar' #but didn't change the object
    it 'does NOT run when no data is applied to this', ->
      model = fb.fromCoffee """
        g = group 'g', beforeInput: (val) ->
          val[0].f = 'modified'
          val
        g.field 'f', value:'default'
      """
      assert.strictEqual model.child('g').value[0].child('f').value, 'default'
      model.clear false
      assert.strictEqual model.child('g').value[0].child('f').value, 'default'
      model.applyData a:'b'
      assert.strictEqual model.child('g').value[0].child('f').value, 'default'
    it 'does NOT run for default value', ->
      model = fb.fromCoffee """
        g = group 'g', repeating:true, value:[f:'first'], beforeInput: (val) ->
          val[0].f = 'modified'
          val
        g.field 'f', value:'bar'
      """
      assert.strictEqual model.child('g').value[0].child('f').value, 'bar'
      model.clear false #false to not purge defaults
      assert.strictEqual model.child('g').value[0].child('f').value, 'bar'
      model.clear true #true purge defaults
      assert.strictEqual model.child('g').value[0].child('f').value, ''
    it 'can access instance attributes'


describe 'beforeOutput', ->
  context 'on a field', ->
    it 'substitutes value on output', ->
      model = fb.fromCoffee """
        field 'foo', value:'original', beforeOutput: -> 'modified'
      """
      assert.strictEqual model.child('foo').value, 'original'
      assert.strictEqual model.buildOutputData().foo, 'modified'
    it 'modifies value on output', ->
      model = fb.fromCoffee """
        field 'foo', value:'1', beforeOutput: (val) ->
          val+2
      """
      assert.strictEqual model.buildOutputData().foo, '12'
    it 'receives values converted to the correct data type', ->
      model = fb.fromCoffee """
        field 'foo', value:'1', type:'number', beforeOutput: (val) ->
          val+2
      """
      assert.strictEqual model.buildOutputData().foo, 3
    it 'undefined values are missing from the output data', ->
      model = fb.fromCoffee """
        field 'foo', value:'original foo', beforeOutput: -> undefined
        field 'bar', value:'original bar'
      """
      assert.deepEqual model.buildOutputData(), bar:'original bar'
    it 'can access instance attributes', ->
      model = fb.fromCoffee """
        field 'foo', beforeOutput: -> @name
      """
      assert.strictEqual model.buildOutputData().foo, 'foo'
  context 'on a group', ->
    it 'substitutes value on output', ->
      model = fb.fromCoffee """
        group 'g', beforeOutput: ->
          "lets make the value a string"
      """
      assert.strictEqual model.buildOutputData().g, "lets make the value a string"
    it 'modifies value on output', ->
      model = fb.fromCoffee """
        g = group 'g', beforeOutput: (val) ->
          val.extra = 'additional value'
          val
        g.field 'f', value:'f initial'
      """
      assert.deepEqual model.buildOutputData(), g:{
        f: 'f initial'
        extra: 'additional value'
      }
    it 'receives default value as parameter'
    it 'undefined values are missing from the output data'
    it 'can access instance attributes'
  context 'on a repeating group', ->
    it.only 'substitutes value on output', ->
      model = fb.fromCoffee """
        g = group 'g', repeating:true, beforeOutput: ->
          'lets make the value a string'
        g.field 'f'
      """, g:[f:'initial']
      
      g = model.child('g')
      f = g.value[0].child('f')
      
      console.log 'done build model', f.value
      console.log g.value[0].buildOutputData()
      console.log 'done build output data'
      
      
      # so here g's value is an array of ModelGroups, as expected
      assert.deepEqual model.buildOutputData(), g:'lets make the value a string'
    it 'modifies value on output', ->
      # impetus for this feature.  We want to display a repeating group whose value is an array of objects
      # but transform that value into a single object in the output data
      model = fb.fromCoffee """
        g = group 'g', repeating:true, beforeOutput: (val) ->
          o = {}
          for item in val
            p[item.key] = item.value
          o
        g.field 'key'
        g.field 'value'
      """, g:[{key:'first', value:'one'},{key:'second', value:'two'}]
      assert.deepEqual model.buildOutputData(), g:{
        first:'one'
        second:'two'
      }
    it 'receives default value as parameter'
    it 'undefined values are missing from the output data'
    it 'can access instance attributes'
      






