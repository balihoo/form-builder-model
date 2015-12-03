assert = require 'assert'
fb = require '../formbuilder'

describe 'fields', ->
	describe '.option()', ->
		it "adds selected options to the field's defaultValue", ->
			model = fb.fromCoffee "field 'foo'"
			foo = model.child 'foo'
			assert.strictEqual foo.defaultValue, ''
			foo.option 'bar'
			assert.strictEqual foo.defaultValue, ''
			foo.option 'baz', selected:true
			assert.strictEqual foo.defaultValue, 'baz'
			foo.option 'another'
			assert.strictEqual foo.defaultValue, 'baz'
		it "adds selected options to the multiselect field's defaultValue", ->
			model = fb.fromCoffee "field 'foo', type:'multiselect'"
			foo = model.child 'foo'
			assert.deepEqual foo.defaultValue, []
			foo.option 'bar'
			assert.deepEqual foo.defaultValue, []
			foo.option 'baz', selected:true
			assert.deepEqual foo.defaultValue, ['baz']
			foo.option 'another'
			assert.deepEqual foo.defaultValue, ['baz']
			foo.option 'yet another', selected:true
			assert.deepEqual foo.defaultValue, ['baz', 'yet another']

	describe '.cloneModel()', ->
		cloneAndCompareField = (foo) ->
			fooClone = foo.cloneModel()
			for prop in ['id']
				assert.notEqual foo[prop], fooClone[prop]
			for prop in ['name', 'title', 'value', 'defaultValue', 'type']
				assert.strictEqual foo[prop], fooClone[prop],
						"Property #{prop} is not strictly equal. Original:#{foo[prop]}, Clone:#{fooClone[prop]}"
		context 'when field has no default value', ->
			it 'cloned fields have the same attributes', ->
				model = fb.fromCoffee "field 'foo'"
				foo = model.child 'foo'
				cloneAndCompareField foo
		context 'when field has a default value', ->
			it 'cloned fields have the same attributes', ->
				model = fb.fromCoffee "field 'foo', value:'bar'"
				foo = model.child 'foo'
				cloneAndCompareField foo
		context 'when properties are changed after creation', ->
			it 'cloned fields have the same attributes', ->
				model = fb.fromCoffee "field 'foo'"
				foo = model.child 'foo'
				foo.value = 'changed'
				cloneAndCompareField foo
		context 'when field has a default value and properties are changed after creation', ->
			it 'cloned fields have the same attributes', ->
				model = fb.fromCoffee "field 'foo', value:'bar'"
				foo = model.child 'foo'
				foo.value = 'changed'
				cloneAndCompareField foo

