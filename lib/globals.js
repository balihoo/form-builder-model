//Things that are shared among many components, but we don't necessarily want to include in the base class.
module.exports = {
  runtime: false,
  // Determine what to do in the case of any error, including during compile, build and dynamic function calls.
  // Any client may overwrite this method to handle errors differently, for example displaying them to the user
  handleError: function(err) {
    if (!(err instanceof Error)) {
      err = new Error(err);
    }
    throw err;
  },
  makeErrorMessage: function(model, propName, err) {
    var nameStack, node, stack;
    stack = [];
    node = model;
    while (node.name != null) {
      stack.push(node.name);
      node = node.parent;
    }
    stack.reverse();
    nameStack = stack.join('.');
    return `The '${propName}' function belonging to the field named '${nameStack}' threw an error with the message '${err.message}'`;
  },
  // Merge data objects together.
  // Modifies and returns the first parameter
  mergeData: function(a, b) {
    var key, value;
    if ((b != null ? b.constructor : void 0) === Object) {
      for (key in b) {
        value = b[key];
        if ((a[key] != null) && a[key].constructor === Object && (value != null ? value.constructor : void 0) === Object) {
          module.exports.mergeData(a[key], value);
        } else {
          a[key] = value;
        }
      }
    }
    return a;
  }
};
