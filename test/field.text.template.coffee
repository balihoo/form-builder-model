assert = require 'assert'
fb = require '../formbuilder'

describe 'field.text.template', ->
  it 'applies data to the template', ->
    model = fb.fromCoffee """
      field 'temp', value:'Hello {{person}}'
      field 'must', template:'temp'
    """, person:'me'
    assert.strictEqual model.buildOutputData().must, 'Hello me'
  it 'accepts field reference as template parameter', ->
    model = fb.fromCoffee """
      field 'temp', value:'Hello {{person}}'
      field 'must', template:root.child 'temp'
    """, person:'me'
    assert.strictEqual model.buildOutputData().must, 'Hello me'
  context 'when template is not valid Mustache', ->
    it 'all fields using that template become invalid', ->
      model = fb.fromCoffee """
        field 'temp', value:'Hello {{'
        field 'must1', template:'temp'
        field 'must2', template:'temp'
      """
      assert model.child('temp').isValid
      assert not model.child('must1').isValid
      assert not model.child('must2').isValid
    it 'other fields still calculate', ->
      model = fb.fromCoffee """
        field 'temp1', value:'Hello {{'
        field 'must1', template:'temp1'
        field 'temp2', value:'Hello {{person}}'
        field 'must2', template:'temp2'
      """, person:'me'
      assert not model.child('must1').isValid
      assert model.child('must2').isValid
      assert.strictEqual model.buildOutputData().must2, 'Hello me'