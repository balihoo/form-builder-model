
#Things that are shared among many components, but we don't necessarily want to include in the base class.

module.exports =
  runtime: false

# Determine what to do in the case of any error, including during compile, build and dynamic function calls.
# Any client may overwrite this method to handle errors differently, for example displaying them to the user
  handleError: (err) ->
    if err not instanceof Error
      err = new Error err
    throw err

  makeErrorMessage: (model, propName, err) ->
    stack = []
    node  = model

    while node.name?
      stack.push node.name
      node = node.parent

    stack.reverse()

    nameStack = stack.join '.'

    "The '#{propName}' function belonging to the
      field named '#{nameStack}' threw an error with the message '#{err.message}'"

  # Merge data objects together.
  # Modifies and returns the first parameter
  mergeData: (a, b)->
    if b?.constructor is Object
      for key, value of b
        if a[key]? and a[key].constructor is Object and value?.constructor is Object
          module.exports.mergeData a[key], value
        else
          a[key] = value
    a