assert = require('assert')
formbuilder = require('../lib/formbuilder')
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
