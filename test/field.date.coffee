assert = require 'assert'
fb = require '../formbuilder'


describe 'field.date', ->
  describe 'validation', ->
    it 'defaults format to M/D/YYYY and accepts valid date', ->
      model = fb.fromCoffee "field 'd', type:'date', value:'12/31/2016'"
      assert model.child('d').isValid
    it 'allows custom format YYYY-MM-DD', ->
      model = fb.fromCoffee "field 'd', type:'date', format: 'YYYY-MM-DD', value:'2016-12-31'"
      assert model.child('d').isValid
    it 'allows moment-specific format tokens', ->
      model = fb.fromCoffee "field 'd', type:'date', format:'MMM Do', value:'Jan 1st'"
      assert model.child('d').isValid
    it 'rejects invalid month', ->
      model = fb.fromCoffee "field 'd', type:'date', value:'13/31/2016'"
      assert not model.child('d').isValid
    it 'rejects invalid day', ->
      model = fb.fromCoffee "field 'd', type:'date', value:'12/32/2016'"
      assert not model.child('d').isValid
    it 'rejects invalid day for the given month', ->
      model = fb.fromCoffee "field 'd', type:'date', value:'2/30/2016'"
      assert not model.child('d').isValid
    it 'rejects nonstrict matches', ->
      model = fb.fromCoffee "field 'd', type:'date', value:'It is 12/31/2016'"
      assert not model.child('d').isValid
    it 'accepts blank value', ->
      model = fb.fromCoffee "field 'd', type:'date'"
      assert model.child('d').isValid
      
  