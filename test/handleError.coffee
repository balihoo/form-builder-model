assert = require 'assert'
fb = require '../formbuilder'
globals = require '../lib/globals'
sinon = require 'sinon'

originalHandleError = null

describe 'handleError', ->
  #make sure we put the original handleError back when done, for other tests
  before ->
    originalHandleError = fb.handleError
  after ->
    fb.handleError = originalHandleError
  
  it 'throws error by default', ->
    er = new Error 'my test error'
    try
      fb.handleError er
    catch err
      assert.strictEqual er, err, 'handled error is thrown'

  it 'is called on failed assert', ->
    errMsg = 'test that fails'
    sinon.spy globals, 'handleError'
    try
      fb.fromCoffee """
        test ->
          assert false, '#{errMsg}'
      """
      fb.modelTests[0]()
      assert.fail "failed test doesn't throw error"
    catch err
      assert err instanceof Error, 'handleError converts string message into Error object'
      assert.strictEqual err.message, errMsg, 'error message passed to handleError'
      assert fb.handleError.calledOnce, 'original handleError called'
      globals.handleError.restore()
      
  it 'can be overwritten with a different error handler', ->
    myError = false
    fb.handleError = ->
      myError = true
    try
      fb.fromCoffee """
        test ->
          assert false, 'test that fails'
      """
      fb.modelTests[0]()
    catch err
      assert.fail "Called original error handler after it was replaced"
    
    assert myError, 'replacement error handler called'
    

  
    