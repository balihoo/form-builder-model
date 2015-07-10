
assert = require 'assert'
fb = require '../formbuilder'

describe 'validation', ->
  it 'sets initial valid state on build', (done) ->
    model = fb.fromCoffee "field('one').validator validate.required"
    assert.strictEqual model.child('one').isValid, false, 'initial state is invalid for empty required field'
    assert.strictEqual model.child('one').validityMessage, 'This field is required',
      'validation message is correct'
    done()

  it 'calls validation functions set as validators array property', (done) ->
    model = fb.fromCoffee "field 'two', validators:[validate.required]"
    assert.strictEqual model.child('two').isValid, false, 'initial state is invalid for empty required field'
    assert.strictEqual model.child('two').validityMessage, 'This field is required',
        'validation message is correct'
    done()
    
  it 'fires validation event when a validator is added', (done) ->
    model = fb.fromCoffee """
      field 'one'
      field 'two', validators:->
          if root.child('one').validators.length is 1
              'something'
    """
    assert.strictEqual model.children[1].validityMessage, undefined, 'Initial valid state ok'
    model.child('one').validator model.validate.maxLength 5
    assert.strictEqual model.children[1].validityMessage, 'something',
      'changed triggered when validator added'
    
    done()
    
  it 'errors when validation returns a function', (done) ->
    try
      model = fb.fromCoffee """
        field 'one'
        .validator validate.maxLength
      """
    catch error
      caught = error
    assert.strictEqual caught?.message, "A validator on field 'one' returned a function"
    done()
    
  describe 'built-in validation functions', ->
    validate = (fb.fromCoffee '').validate
    valid = undefined
    it 'required', (done) ->
      assert.strictEqual validate.required('hello'), valid
      assert.strictEqual validate.required(''), "This field is required"
      done();
    it 'minLength', (done) ->
      assert.strictEqual validate.minLength(3)('abc'), valid
      assert.strictEqual validate.minLength(3)('ab'), 'Must be at least 3 characters long'
      assert.strictEqual validate.minLength(3)(''), 'Must be at least 3 characters long'
      done()
    it 'maxLength', (done) ->
      assert.strictEqual validate.maxLength(3)('abc'), valid
      assert.strictEqual validate.maxLength(3)(''), valid
      assert.strictEqual validate.maxLength(3)('ab'), valid
      assert.strictEqual validate.maxLength(3)('abcd'), 'Can be at most 3 characters long'
      done()
    it 'email', (done) ->
      assert.strictEqual validate.email('test@example.com'), valid
      assert.strictEqual validate.email('test@example'), 'Must be a valid email'
      assert.strictEqual validate.email(''), 'Must be a valid email'
      done()
    it 'url', (done) ->
      assert.strictEqual validate.url('http://www.google.com'), valid
      assert.strictEqual validate.url("http://google.com/search?q=test"), valid
      assert.strictEqual validate.url("google.com"), "Must be a URL"
      done()
    it 'dollars', (done) ->
      assert.strictEqual validate.dollars("$3.99"), valid
      assert.strictEqual validate.dollars("$0.01"), valid
      assert.strictEqual validate.dollars("$123"), valid
      assert.strictEqual validate.dollars("$5.0"), "Must be a dollar amount (ex. $3.99)"
      assert.strictEqual validate.dollars("$6.123"), "Must be a dollar amount (ex. $3.99)"
      assert.strictEqual validate.dollars("$"), "Must be a dollar amount (ex. $3.99)"
      assert.strictEqual validate.dollars("3.00"), "Must be a dollar amount (ex. $3.99)"
      done()
    it 'minSelections', (done) ->
      assert.strictEqual validate.minSelections(1)(['one']), valid
      assert.strictEqual validate.minSelections(0)([]), valid
      assert.strictEqual validate.minSelections(5)(['one','two','three','four','five','six','seven']), valid
      assert.strictEqual validate.minSelections(1)([]), "Please select at least 1 options"
      assert.strictEqual validate.minSelections(3)(['one','two']), "Please select at least 3 options"
      done();
    it 'maxSelections', (done) ->
      assert.strictEqual validate.maxSelections(0)([]), valid
      assert.strictEqual validate.maxSelections(2)(['one','two']), valid
      assert.strictEqual validate.maxSelections(5)(['one']), valid
      assert.strictEqual validate.maxSelections(5)([]), valid
      assert.strictEqual validate.maxSelections(0)(['one']), "Please select at most 0 options"
      assert.strictEqual validate.maxSelections(1)(['one','two']), "Please select at most 1 options"
      assert.strictEqual validate.maxSelections(3)(['one','two','three','four','five']), "Please select at most 3 options"
      done()
    it 'selectedIsVisible', (done) ->
      model = fb.fromCoffee """
        field 'one', value:'first', validators:validate.selectedIsVisible
         .option 'first'
         .option 'second', visible:false
         .option 'third'
      """
      one = model.child 'one'
      assert.strictEqual validate.selectedIsVisible(one), valid
      
      one.value = 'second'
      assert.strictEqual validate.selectedIsVisible(one),
        "A selected option is not currently available.  Please make a new choice from available options."
      
      one.type = 'multiselect'
      one.value = ['first','second']

      assert.strictEqual validate.selectedIsVisible(one),
        "A selected option is not currently available.  Please make a new choice from available options."
      
      one.value = ['first','third']
      assert.strictEqual validate.selectedIsVisible(one), valid
      done()

