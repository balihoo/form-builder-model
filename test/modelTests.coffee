assert = require 'assert'
fb = require '../formbuilder'

describe 'modelTests', ->
  it 'model code pushes tests onto the modelTests array', ->
    fb.fromCoffee "" #just clear out from any previous tests
    assert.strictEqual fb.modelTests.length, 0, 'modelTests initially empty'
    fb.fromCoffee """
      test ->
        console.log 'TEST FUNC'
    """
    assert.strictEqual fb.modelTests.length, 1, 'model code adds model test'
  it 'resets modelTests on new build', ->
    assert.strictEqual fb.modelTests.length, 1, 'one modelTest left over from prior build'
    fb.fromCoffee ""
    assert.strictEqual fb.modelTests.length, 0, 'model tests cleared on new build'
  it "doesn't call modelTests on build", ->
    fb.fromCoffee """
      test ->
        process.exit 1
    """
  it 'test failures are thrown by default', ->
    failMsg = "Things didn't work"
    fb.fromCoffee """
      test ->
        assert false, "#{failMsg}"
    """
    try
      fb.modelTests[0]()
      assert.fail 'failed test now thrown error'
    catch err
      assert.strictEqual err.message, failMsg, "assert error was thrown"
      
      
  
    