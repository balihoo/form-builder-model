assert = require 'assert'
fb = require '../formbuilder'


describe 'beforeInput', ->
  context 'on a field', ->
    it 'modifies applied value prior to saving', ->
      model = fb.fromCoffee '''
        field 'foo', beforeInput: (val) ->
          val + ' modified'
        field 'bar'
      ''', foo:'original', bar:'original'
      assert.strictEqual model.child('foo').value, 'original modified'
      assert.strictEqual model.child('bar').value, 'original'
      model.clear()
      model.applyData {foo:'original2', bar:'original2'}
      assert.strictEqual model.child('foo').value, 'original2 modified'
      assert.strictEqual model.child('bar').value, 'original2'
    it "doesn't modify applied object outside of building scope", ->
      data = foo:'bar'
      model = fb.fromCoffee '''
        field 'foo', beforeInput: (val) ->
          val + 't'
      ''', data
      #test not modified during build
      assert.strictEqual data.foo, 'bar'
      #test not modified during applyData
      model.applyData data, true
      assert.strictEqual data.foo, 'bar'      
    it 'does NOT run when no data is applied to this', ->
      model = fb.fromCoffee '''
        field 'foo', beforeInput: (val) ->
          'not bar'
      '''
      assert.strictEqual model.child('foo').value, ''
      model.clear false
      assert.strictEqual model.child('foo').value, ''
      model.applyData thing:'not a field'
      assert.strictEqual model.child('foo').value, ''
    it 'does NOT run for default value', ->
      model = fb.fromCoffee '''
        field 'foo', value:'bar', beforeInput: (val) ->
          'not bar'
      '''
      assert.strictEqual model.child('foo').value, 'bar'
      model.clear false #false to not purge defaults
      assert.strictEqual model.child('foo').value, 'bar'
      model.clear true #true purge defaults
      assert.strictEqual model.child('foo').value, ''
    it 'can access instance attributes', ->
      model = fb.fromCoffee '''
        field 'foo', beforeInput: (val) ->
          val + @name
      ''', foo:'bar'
      assert.strictEqual model.child('foo').value, 'barfoo'
  context 'on a group', ->
    it 'modifies applied value prior to applying to children', ->
      model = fb.fromCoffee '''
        g = group 'g', beforeInput: (val) ->
          val.f1 += '+g'
          val
        g.field 'f1'
        g.field 'f2'
      ''', g:{f1:'original',f2:'original'}
      assert.strictEqual model.child('g.f1').value, 'original+g'
      assert.strictEqual model.child('g.f2').value, 'original'
      model.clear()
      model.applyData g:{f1:'original2',f2:'original2'}
      assert.strictEqual model.child('g.f1').value, 'original2+g'
      assert.strictEqual model.child('g.f2').value, 'original2'
    it 'allows children to further modify value prior to input', ->
      model = fb.fromCoffee '''
        g = group 'g', beforeInput: (val) ->
          val.f1 += '+g'
          val
        g.field 'f1', beforeInput: (val) ->
          val + '+f1'
        g.field 'f2'
      ''', g:{f1:'original', f2:'original'}
      assert.strictEqual model.child('g.f1').value, 'original+g+f1'
      assert.strictEqual model.child('g.f2').value, 'original'
      model.clear()
      model.applyData g:{f1:'original2',f2:'original2'}
      assert.strictEqual model.child('g.f1').value, 'original2+g+f1'
      assert.strictEqual model.child('g.f2').value, 'original2'
    it "doesn't modify applied value outside of building scope", ->
      data = g:f:'bar'
      model = fb.fromCoffee '''
        g = group 'g', beforeInput: (val) ->
          val.f = 'changed'
          val
        g.field 'f'
      ''', data
      #test not modified during build
      assert.strictEqual model.child('g.f').value, 'changed' #make sure it applied
      assert.strictEqual data.g.f, 'bar' #but didn't change the object
      #test not modified during applyData
      model.applyData data, true
      assert.strictEqual model.child('g.f').value, 'changed' #make sure it applied
      assert.strictEqual data.g.f, 'bar' #but didn't change the object
    it 'does NOT run when no data is applied to this', ->
      model = fb.fromCoffee '''
        g = group 'g', beforeInput: (val) ->
          val.f = 'modified'
          val
        g.field 'f', value:'default'
      '''
      assert.strictEqual model.child('g.f').value, 'default'
      model.clear false
      assert.strictEqual model.child('g.f').value, 'default'
      model.applyData a:'b'
      assert.strictEqual model.child('g.f').value, 'default'
    it 'does NOT run for default value', ->
      # groups do not have value or default value, but will initially have fields with empty values.
      model = fb.fromCoffee '''
        g = group 'g', beforeInput: (val) ->
          val.f = 'group beforeInput'
          val
        g.field 'f', value:''
      '''
      assert.strictEqual model.child('g.f').value, ''
    it 'can access instance attributes', ->
      model = fb.fromCoffee '''
        g = group 'g', beforeInput: (val) ->
          val.f += @name
          val
        g.field 'f'
      ''', g:f:'bar'
      assert.strictEqual model.child('g.f').value, 'barg'
  context 'on a repeating group', ->
    it 'modifies applied value by adding a new group', ->
      model = fb.fromCoffee '''
        g = group 'g', repeating:true, beforeInput: (val) ->
          val.push f:'additional'
          val
        g.field 'f'
      ''', g:[f:'original']
      assert.strictEqual model.child('g').value.length, 2
      assert.strictEqual model.child('g').value[0].child('f').value, 'original'
      assert.strictEqual model.child('g').value[1].child('f').value, 'additional'
      model.clear()
      model.applyData g:[f:'original']
      assert.strictEqual model.child('g').value.length, 2
      assert.strictEqual model.child('g').value[0].child('f').value, 'original'
      assert.strictEqual model.child('g').value[1].child('f').value, 'additional'
    it 'modifies applied value by modifying a value in each group', ->
      model = fb.fromCoffee '''
        g = group 'g', repeating:true, beforeInput: (val) ->
          for v,i in val
            v.f += i+1 #add index to each value
          val
        g.field 'f'
      ''', g:[{f:'one'},{f:'two'}]
      assert.strictEqual model.child('g').value[0].child('f').value, 'one1'
      assert.strictEqual model.child('g').value[1].child('f').value, 'two2'
      model.clear()
      model.applyData g:[{f:'first'},{f:'second'}]
      assert.strictEqual model.child('g').value[0].child('f').value, 'first1'
      assert.strictEqual model.child('g').value[1].child('f').value, 'second2'
    it 'allows children to further modify value', ->
      model = fb.fromCoffee '''
        g = group 'g', repeating:true, beforeInput: (val) ->
          for v,i in val
            v.f += i+1 #add index to each value
          val
        g.field 'f', beforeInput: (val) ->
          val + 'mod'
      ''', g:[{f:'one'},{f:'two'}]
      assert.strictEqual model.child('g').value[0].child('f').value, 'one1mod'
    it "doesn't modify applied value outside of building scope", ->
      data = g:[f:'bar']
      model = fb.fromCoffee '''
        g = group 'g', repeating:true, beforeInput: (val) ->
          val[0].f = 'changed'
          val
        g.field 'f'
      ''', data
      #test not modified during build
      assert.strictEqual model.child('g').value[0].child('f').value, 'changed' #make sure it applied
      assert.strictEqual data.g[0].f, 'bar' #but didn't change the object
      #test not modified during applyData
      model.applyData data, true
      assert.strictEqual model.child('g').value[0].child('f').value, 'changed' #make sure it applied
      assert.strictEqual data.g[0].f, 'bar' #but didn't change the object
    it 'does NOT run when no data is applied to this', ->
      model = fb.fromCoffee '''
        g = group 'g', repeating:true, beforeInput: (val) ->
          val[0].f = 'modified'
          val
        g.field 'f', value:'default'
      '''
      assert.strictEqual model.child('g').value.length, 0
      model.clear false
      assert.strictEqual model.child('g').value.length, 0
      model.applyData a:'b'
      assert.strictEqual model.child('g').value.length, 0
    it 'does NOT run for default value', ->
      model = fb.fromCoffee '''
        g = group 'g', repeating:true, value:[f:'first'], beforeInput: (val) ->
          val[0].f = 'modified'
          val
        g.field 'f'
      '''
      assert.strictEqual model.child('g').value[0].child('f').value, 'first'
      model.clear false #false to not purge defaults
      assert.strictEqual model.child('g').value[0].child('f').value, 'first'
      model.clear true #true purge defaults
      assert.strictEqual model.child('g').value.length, 0
    it 'can access instance attributes', ->
      model = fb.fromCoffee '''
        g = group 'g', repeating:true, beforeInput: (val) ->
          val.push f:"added #{@name}"
          val
        g.field 'f'
      ''', g:[f:'build']
      assert.deepEqual model.buildOutputData(), g:[{f:'build'},{f:'added g'}]