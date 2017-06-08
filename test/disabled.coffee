assert = require 'assert'
fb = require '../formbuilder'

describe 'disabled', ->
  it 'defaults to false', ->
    model = fb.fromCoffee "field 'foo'"
    assert !model.child('foo').isDisabled
  it 'can be true/false/1/0, or other primitives', ->
    model = fb.fromCoffee """
      field 'true', disabled:true
      field 'false', disabled:false
      field '1', disabled:1
      field '0', disabled:0
      field 'string', disabled:'applesauce'
    """
    assert model.child('true').isDisabled
    assert !model.child('false').isDisabled
    assert model.child('1').isDisabled
    assert !model.child('0').isDisabled
    assert model.child('string').isDisabled
  it 'can be a function', ->
    model = fb.fromCoffee """
      field 'disThis', disabled: ->
        root.child('dependent').value is 'disable'
      field 'dependent'
    """
    assert !model.child('disThis').isDisabled
    model.child('dependent').value = 'disable'
    assert model.child('disThis').isDisabled
  context 'when group', ->
    it 'defaults children to that value', ->
      model = fb.fromCoffee """
        group 'g', disabled:true
        .field 'f1'
        .field 'f2', disabled:false
      """
      assert model.child('g.f1').isDisabled
      assert !model.child('g.f2').isDisabled
    it 'children functions have correct context', ->
      model = fb.fromCoffee """
        group 'g'
        .field 'f1'
        .field 'f2', disabled: ->
          @parent.child('f1').value is 'dis'
      """
      assert !model.child('g.f1').isDisabled
      assert !model.child('g.f2').isDisabled
      model.child('g.f1').value = 'dis'
      assert model.child('g.f2').isDisabled
      model.child('g.f1').value = 'disnope'
      assert !model.child('g.f2').isDisabled
    it 'defaults grandchildren to that value too', ->
      model = fb.fromCoffee """
        group 'g', disabled:true
        .group 'g2'
        .field 'f1'
        .field 'f2', disabled:false
      """
      assert model.child('g.g2.f1').isDisabled
      assert !model.child('g.g2.f2').isDisabled
    it 'defaults cloned group children to that value', ->
      importModel = fb.fromCoffee """
        field 'f1'
        field 'f2', disabled:true
      """
      model = fb.fromCoffee """
        group imports.g, 'g'
      """, null, null, {g:importModel}
      assert !model.child('g.f1').isDisabled
      assert model.child('g.f2').isDisabled
  context 'when repeating group', ->
    it 'defaults children and values to that value', ->
      model = fb.fromCoffee """
        group 'g', disabled:true, repeating:true, value:[{f1:'one', f2:'two'}]
        .field 'f1'
        .field 'f2', disabled:false
      """
      assert model.child('g').value[0].child('f1').isDisabled
      assert !model.child('g').value[0].child('f2').isDisabled
    it 'children functions have correct context', ->
      model = fb.fromCoffee """
        group 'g', repeating:true
        .field 'f1'
        .field 'f2', disabled: ->
          @parent.child('f1').value is 'dis'
      """, g:[{f1:'one', f2:'two'}]
      assert !model.child('g').value[0].child('f1').isDisabled
      assert !model.child('g').value[0].child('f2').isDisabled
      model.child('g').value[0].child('f1').value = 'dis'
      assert !model.child('g').value[0].child('f1').isDisabled
      assert model.child('g').value[0].child('f2').isDisabled
    it 'defaults grandchildren to that value too', ->
      model = fb.fromCoffee """
        group 'g', repeating:true, disabled:true
        .group 'g1'
        .field 'f1'
        .field 'f2', disabled:false
      """, g:[{g1:{f1:'one', f2:'two'}}]
      assert model.child('g').value[0].child('g1.f1').isDisabled
      assert !model.child('g').value[0].child('g1.f2').isDisabled
  context 'when option', ->
    it 'can be a function', ->
      model = fb.fromCoffee """
        field 'dep'
        field 'foo'
        .option 'a'
        .option 'b', disabled: -> root.child('dep').value is 'dis'
      """
      assert !model.child('foo.a').isDisabled
      assert !model.child('foo.b').isDisabled
      model.child('dep').value = 'dis'
      assert !model.child('foo.a').isDisabled
      assert model.child('foo.b').isDisabled
