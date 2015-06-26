assert = require 'assert'
formbuilder = require '../formbuilder'
jiff = require 'jiff'

describe 'fromCoffee', ->
	it 'can build a simple model', (done) ->
		model = formbuilder.fromCoffee('field "a"')
		assert.strictEqual typeof model, 'object', 'built an object'
		assert.strictEqual model.child('a').name, 'a', 'has the correct child'
		done()
	it 'can apply data to a model', (done) ->
		model = formbuilder.fromCoffee('field "a"\nfield "b"',
			a: 'first'
			b: 'second')
		assert.strictEqual model.child('a').value, 'first', 'applied first datum'
		assert.strictEqual model.child('b').value, 'second', 'applied second datum'
		done()
describe 'fromPackage', ->
	it 'can build a model with no data', (done) ->
		pkg =
			formid: 123
			forms: [{formid: 123, model: "field 'foo', value:'I pity da'"}]
		model = formbuilder.fromPackage pkg
		assert.deepEqual model.buildOutputData(), {foo: 'I pity da'}
		done()
	it 'can build packages with imports', (done) ->
		pkg =
			formid: 33
			forms: [
				{
					formid: 34
					model: 'field "name", value:"Bob, son of #{imports.parent.child(\"name\").value}"'
					imports: [
						{importformid: 35, namespace: 'parent'}
					]
				}
				{
					formid: 33
					model: '''
              field 'name', value:"Charlie, son of #{imports.parent.child('name').value}"
              field "gpa", value:imports.grandparent.child('name').value
            '''
					imports: [
						{importformid: 34, namespace: 'parent'}
						{importformid: 35, namespace: 'grandparent'}
					]
				}
				{
					formid: 35
					model: 'field "name", value:"Abe"'
				}
			]

		model = formbuilder.fromPackage(pkg)

		assert.deepEqual model.buildOutputData(), {
			name: 'Charlie, son of Bob, son of Abe'
			gpa: 'Abe'
		}
		done()
	it 'can take data in package', (done) ->
		pkg =
			formid: 123
			forms: [{formid: 123, model: "field 'foo', value:'I pity da'"}]
			data: {foo: 'tball'}
		model = formbuilder.fromPackage pkg
		assert.deepEqual model.buildOutputData(), {foo: 'tball'}
		done()
	it 'can take data as second parameter', (done) ->
		pkg =
			formid: 1
			forms: [{formid: 1, model: "field 'foo'"}]
		model = formbuilder.fromPackage pkg, {foo: 'bar'}
		assert.deepEqual model.buildOutputData(), {foo: 'bar'}
		done()
	it 'can take data in both places, second parameter extending package', (done) ->
		pkg =
			formid: 1
			forms: [{formid: 1, model: "field 'foo'\nfield 'bar'"}]
			data: {foo: 'pkg foo', bar: 'pkg bar'}
		model = formbuilder.fromPackage pkg, {foo: 'second foo'}
		assert.deepEqual model.buildOutputData(), {foo: 'second foo', bar: 'pkg bar'}
		done()
	it 'handles errors in the main form', (done) ->
		pkg =
			formid: 1
			forms: [
				{formid: 1, model: 'applesauce'}
			]
		result =
			try
				formbuilder.fromPackage pkg
			catch e
				e.message

		assert.strictEqual result, "applesauce is not defined"
		done()
	it 'handles errors in an import', (done) ->
		pkg =
			formid: 2
			forms: [
				{formid: 2, model: "field 'foo', value:imports.i.foo()", imports: [{importformid: 3, namespace: 'i'}]}
				{formid: 3, model: "root.foo = -> 'value for foo'\ncheeseburger"}
			]
		result =
			try
				formbuilder.fromPackage pkg
			catch e
				e.message
		assert.strictEqual result, "cheeseburger is not defined"
		done()
describe 'getChanges', ->
	it 'returns raw diff', (done) ->
		model = formbuilder.fromCoffee "field 'something'\nfield 'another'", {something: 'endgame'}
		initial =
			something: 'something initial'
			another: 'another initial'
		diff = formbuilder.getChanges model, initial
		assert.deepEqual diff.patch, jiff.diff(initial, model.buildOutputData())
		done()
	it 'works for single field', (done) ->
		model = formbuilder.fromCoffee "field name:'foo', title:'foo title'", foo: 'current'
		changes = formbuilder.getChanges model, foo: 'initial'
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
					op: 'test'
					path: '/foo'
					value: 'initial'
				},
				{
					op: 'replace'
					path: '/foo'
					value: 'current'
				}
			]
		}
		done()
	it 'works on complex, hierarchical models'
	it 'handles values not present in initial', (done) ->
		model = formbuilder.fromCoffee "field name:'foo', title:'foo title'", foo: 'current'
		result = formbuilder.getChanges model, {}
		assert.deepEqual result.changes, [
			{
				name: '/foo'
				title: 'foo title'
				before: ''
				after: 'current'
			}
		]
		done()
	it 'handles values not present in current', (done) ->
		model = formbuilder.fromCoffee "field name:'foo', title:'foo title'"
		result = formbuilder.getChanges model, {foo:'initial'}
		assert.deepEqual result.changes, [
			{
				name: '/foo'
				title: 'foo title'
				before: 'initial'
				after: ''
			}
		]
		done()
	it 'handles fields not present in initial'
	it 'handles fields not present in final'
	it 'handles multiselects (with array values)'
	it 'handles repeating groups (with array values)'

describe 'clear', ->
	it 'clears a text field', (done) ->
		model = formbuilder.fromCoffee "field 'foo', value:'bar'"
		field = model.child 'foo'
		assert.strictEqual field.value, 'bar'
		field.clear()
		assert.strictEqual field.value, ''
		done()
	it 'clears a multiselect field'
	it 'clears a bool field'
	it 'clears all fields in a group'
	it 'clears a repeating group'
	it 'clears an image field'
	it 'clears a tree field'

describe 'applyData', ->
	it 'applies data to a field'
	it 'clears all when clear=true'
	it 'applies data to nested fields'

