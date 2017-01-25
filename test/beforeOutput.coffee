assert = require 'assert'
fb = require '../formbuilder'


describe 'beforeOutput', ->
  context 'on a field', ->
    it 'substitutes value on output', ->
      model = fb.fromCoffee '''
        field 'foo', value:'original', beforeOutput: -> 'modified'
      '''
      assert.strictEqual model.child('foo').value, 'original'
      assert.strictEqual model.buildOutputData().foo, 'modified'
    it 'modifies value on output', ->
      model = fb.fromCoffee '''
        field 'foo', value:'1', beforeOutput: (val) ->
          val+2
      '''
      assert.strictEqual model.buildOutputData().foo, '12'
    it 'receives values converted to the correct data type', ->
      model = fb.fromCoffee '''
        field 'foo', value:'1', type:'number', beforeOutput: (val) ->
          val+2
      '''
      assert.strictEqual model.buildOutputData().foo, 3
    it 'undefined values are missing from the output data', ->
      model = fb.fromCoffee '''
        field 'foo', value:'original foo', beforeOutput: -> undefined
        field 'bar', value:'original bar'
      '''
      assert.deepEqual model.buildOutputData(), bar:'original bar'
    it 'can access instance attributes', ->
      model = fb.fromCoffee '''
        field 'foo', beforeOutput: ->
          "my name is #{@name}"
      '''
      assert.strictEqual model.buildOutputData().foo, 'my name is foo'
  context 'on a group', ->
    it 'substitutes value on output', ->
      model = fb.fromCoffee '''
        group 'g', beforeOutput: ->
          "lets make the value a string"
      '''
      assert.strictEqual model.buildOutputData().g, "lets make the value a string"
    it 'modifies value on output', ->
      model = fb.fromCoffee '''
        g = group 'g', beforeOutput: (val) ->
          val.extra = 'additional value'
          val
        g.field 'f', value:'f initial'
      '''
      assert.deepEqual model.buildOutputData(), g:{
        f: 'f initial'
        extra: 'additional value'
      }
    it 'receives current value as parameter', ->
      model = fb.fromCoffee '''
        g = group 'g', beforeOutput: (val) ->
          val.foo = 'bar'
          val
        g.field 'f'
      ''', g:f:'initial'
      assert.deepEqual model.buildOutputData(), g:{f:'initial',foo:'bar'}
    it 'undefined values are missing from the output data', ->
      model = fb.fromCoffee '''
        g1 = group 'g1', beforeOutput: -> undefined
        g1.field 'f1'
        g2 = group 'g2'
        g2.field 'f2' 
      ''', {
        g1:f1:'foo1'
        g2:f2:'foo2'
      }
      assert.deepEqual model.buildOutputData(), g2:f2:'foo2'
    it 'can access instance attributes', ->
      model = fb.fromCoffee '''
        group 'g', beforeOutput: (val) -> "my name is #{@name}"
      '''
      assert.deepEqual model.buildOutputData().g, 'my name is g'
  context 'on a repeating group', ->
    it 'substitutes value on output', ->
      model = fb.fromCoffee '''
        g = group 'g', repeating:true, beforeOutput: ->
          'lets make the value a string'
        g.field 'f'
      ''', g:[f:'initial']
      
      assert.deepEqual model.buildOutputData(), g:'lets make the value a string'
    it 'modifies value on output', ->
      # impetus for this feature.  We want to display a repeating group whose value is an array of objects
      # but transform that value into a single object in the output data
      model = fb.fromCoffee '''
        g = group 'g', repeating:true, beforeOutput: (val) ->
          o = {}
          for item in val
            o[item.key] = item.value
          o
        g.field 'key'
        g.field 'value'
      ''', g:[{key:'first', value:'one'},{key:'second', value:'two'}]
      assert.deepEqual model.buildOutputData(), g:{
        first:'one'
        second:'two'
      }
    it 'undefined values are missing from the output data', ->
      model = fb.fromCoffee '''
        g = group 'g', repeating:true, beforeOutput: (val) -> undefined
        g.field 'f'
        g2 = group 'g2', repeating:true
        g2.field 'f2'
      ''', {
        g:[{f:'initial'}]
        g2:[{f2:'initial2'}]
      }
      assert.deepEqual model.buildOutputData(), g2:[{f2:'initial2'}]
    it 'can access instance attributes', ->
      model = fb.fromCoffee '''
        g = group 'g', beforeOutput: (val) ->
          "my name is #{@name}"
      '''
      assert.strictEqual model.buildOutputData().g, 'my name is g'
      






