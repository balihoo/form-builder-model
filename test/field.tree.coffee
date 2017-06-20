assert = require 'assert'
fb = require '../formbuilder'

describe 'field.tree', ->
  it 'basic example', ->
    model = fb.fromCoffee """
      field 'mytree', type:'tree'
      .option path:['Places','Cities','Boise'], value:'123'
      .option path:['Places','Cities','Spokane'], value:'234'
      .option path:['People','Andy'], value:'345'
    """
    assert.deepEqual model.buildOutputData(), mytree:[]
  it 'allows addressing options by child(value)', ->
    model = fb.fromCoffee """
      field 'mytree', type:'tree'
      .option path:['Places','Cities','Boise'], value:'123'
    """
    assert.deepEqual model.child('mytree.123').path[0], 'Places'
  it 'allows default field value', ->
    model = fb.fromCoffee """
      field 'mytree', type:'tree', value:['first']
      .option path:['firstOpt'], value:'first'
    """
    assert.deepEqual model.buildOutputData(), mytree:['first']
  it 'accepts input data', ->
    model = fb.fromCoffee """
      field 'mytree', type:'tree'
      .option path:['firstOpt'], value:'first'
    """, mytree:['first']
    assert.deepEqual model.buildOutputData(), mytree:['first']
  it 'accepts input data that is not among options and adds it', ->
    model = fb.fromCoffee """
      field 'f', type:'tree'
      .option ['a']
      .option ['b']
    """, f:['c']
    assert.deepEqual model.buildOutputData(), f:['c']
    assert.strictEqual model.child('f').options.length, 3
  it 'accepts input data where some values dont exist among options, but others do', ->
    model = fb.fromCoffee """
      field 'f', type:'tree'
      .option ['a']
      .option ['b']
    """, f:['b','c']
    assert.deepEqual model.buildOutputData(), f:['b','c']
    assert.strictEqual model.child('f').options.length, 3
  describe 'options', ->
    it 'allows selected', ->
      model = fb.fromCoffee """
        field 'mytree', type:'tree'
        .option path:['foo'], selected:true, value:'bar'
      """
      assert.strictEqual model.child('mytree.bar').selected, true
      assert.deepEqual model.buildOutputData(), mytree:['bar']
    it 'allow value as "value" property', ->
      model = fb.fromCoffee """
        field 'mytree', type:'tree'
        .option path:['first'], value:1, selected:true
      """
      assert.deepEqual model.buildOutputData(), mytree:[1]
    it 'allow value as "id" property', ->
      model = fb.fromCoffee """
        field 'mytree', type:'tree'
        .option path:['first'], id:1, selected:true
      """
      assert.deepEqual model.buildOutputData(), mytree:[1]
    it 'allow default value as path concatenated', ->
      model = fb.fromCoffee """
        field 'mytree', type:'tree'
        .option path:['first','option'], selected:true
      """
      assert.deepEqual model.buildOutputData(), mytree:['first > option']
    it 'doesnt overwrite value 0 with default path concatenated', ->
      model = fb.fromCoffee """
        field 'mytree', type:'tree'
        .option path:['first'], value:0, selected:true
      """
      assert.deepEqual model.buildOutputData(), mytree:[0]
    it 'doesnt overwrite value empty string with default path concatenated', ->
      model = fb.fromCoffee """
        field 'mytree', type:'tree'
        .option path:['first'], value:'', selected:true
      """
      assert.deepEqual model.buildOutputData(), mytree:['']
    it 'doesnt overwrite id 0 with default path concatenated', ->
      model = fb.fromCoffee """
        field 'mytree', type:'tree'
        .option path:['first'], id:0, selected:true
      """
      assert.deepEqual model.buildOutputData(), mytree:[0]
    it 'allows value as int', ->
      model = fb.fromCoffee """
        field 'mytree', type:'tree'
        .option path:['first'], value:1, selected:true
      """
      assert.deepEqual model.buildOutputData(), mytree:[1]
    it 'allows value as string', ->
      model = fb.fromCoffee """
        field 'mytree', type:'tree'
        .option path:['first'], value:'1', selected:true
      """
      assert.deepEqual model.buildOutputData(), mytree:['1']
    it 'allows positional parameters', ->
      model = fb.fromCoffee """
        field 'mytree', type:'tree'
        .option ['first','second'], 'optValue', true
      """
      mytree = model.child 'mytree'
      optValue = mytree.child 'optValue'
      opt = model.child 'mytree.optValue'
      assert.deepEqual opt.path, ['first','second']
      assert.strictEqual opt.value, 'optValue'
      assert.strictEqual opt.selected, true
    it 'allows path as string', ->
      model = fb.fromCoffee """
        field 'f', type:'tree'
        .option 'a'
      """
      assert.strictEqual model.child('f').options.length, 1
      assert.strictEqual model.child('f').options[0].path.length, 1
      
      
    

