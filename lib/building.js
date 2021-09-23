var CoffeeScript, ModelGroup, Mustache, _, globals, jiff, throttledAlert, vm;

CoffeeScript = require('coffeescript').register();

Mustache = require('mustache');

_ = require('underscore');

vm = require('vm');

jiff = require('jiff');

globals = require('./globals');

ModelGroup = require('./modelGroup');

globals = require('./globals');

if (typeof alert !== "undefined" && alert !== null) {
  throttledAlert = _.throttle(alert, 500);
}

/*
  An array of functions that can test a built model.
  Model code may add tests to this array during build.  The tests themselves will not be run at the time, but are
    made avaiable via this export so processes can run the tests when appropriate.
  Tests may modify the model state, so the model should be rebuilt prior to running each test.
*/
exports.modelTests = [];

// Creates a Model object from JS code.  The executed code will execute in a
// root ModelGroup
// code - model code
// data - initialization data (optional). Object or stringified object
// element - jquery element for firing validation events (optional)
// imports - object mapping {varname : model object}. May be referenced in form code
exports.fromCode = function(code, data, element, imports, isImport) {
  var assert, emit, newRoot, test;
  data = (function() {
    switch (typeof data) {
      case 'object':
        return jiff.clone(data); //copy it
      case 'string':
        return JSON.parse(data); // 'undefined', 'null', and other unsupported types
      default:
        return {};
    }
  })();
  globals.runtime = false;
  exports.modelTests = [];
  test = function(func) {
    return exports.modelTests.push(func);
  };
  assert = function(bool, message = "A model test has failed") {
    if (!bool) {
      return globals.handleError(message);
    }
  };
  emit = function(name, context) {
    if (element && $) {
      return element.trigger($.Event(name, context));
    }
  };
  newRoot = new ModelGroup();
  //dont recalculate until model is done creating
  newRoot.recalculating = false;
  newRoot.recalculateCycle = function() {};
  (function(root) { //new scope for root variable name
    var field, group, sandbox, validate;
    field = newRoot.field.bind(newRoot);
    group = newRoot.group.bind(newRoot);
    root = newRoot.root;
    validate = newRoot.validate;
    //running in a vm is safer, but slower.  Let the browser do plain eval, but not server.
    if (typeof window === "undefined" || window === null) {
      sandbox = { //hooks available in form code
        field: field,
        group: group,
        root: root,
        validate: validate,
        data: data,
        imports: imports,
        test: test,
        assert: assert,
        Mustache: Mustache,
        emit: emit,
        _: _,
        console: { //console functions don't break, but don't do anything
          log: function() {},
          error: function() {}
        },
        print: function() {}
      };
      return vm.runInNewContext('"use strict";' + code, sandbox);
    } else {
      return eval('"use strict";' + code);
    }
  })(null);
  newRoot.postBuild();
  globals.runtime = true;
  newRoot.applyData(data);
  newRoot.getChanges = exports.getChanges.bind(null, newRoot);
  newRoot.setDirty(newRoot.id, 'multiple');
  newRoot.recalculateCycle = function() {
    var results;
    results = [];
    while (!this.recalculating && this.dirty) {
      this.recalculating = true;
      this.recalculateRelativeProperties();
      results.push(this.recalculating = false);
    }
    return results;
  };
  newRoot.recalculateCycle();
  newRoot.on('change:isValid', function() {
    if (!isImport) {
      return emit('validate', {
        isValid: newRoot.isValid
      });
    }
  });
  newRoot.on('recalculate', function() {
    if (!isImport) {
      return emit('change');
    }
  });
  newRoot.trigger('change:isValid');
  newRoot.trigger('recalculate');
  newRoot.styles = false; //don't render with well, etc.
  return newRoot;
};

// CoffeeScript counterpart to fromCode.  Compiles the given code to JS
// and passes it to fromCode.
exports.fromCoffee = function(code, data, element, imports, isImport) {
  return exports.fromCode(CoffeeScript.compile(code), data, element, imports, isImport);
};

// Build a model from a package object, consisting of
// - formid (int or string)
// - forms (array of object).  Each object contains
// - - formid (int)
// - - model (string) coffeescript model code
// - - imports (array of object).  Each object contains
// - - - importformid (int)
// - - - namespace (string)
// - data (object, optional)
// data may also be supplied as the second parameter to the function. Data in this parameter
//   will override any matching keys provided in the package data
// element to which to bind validation and change messages, also optional
exports.fromPackage = function(pkg, data, element) {
  var buildModelWithRecursiveImports;
  buildModelWithRecursiveImports = function(p, el, isImport) {
    var buildImport, builtImports, f, form;
    form = ((function() {
      var i, len, ref, results;
      ref = p.forms;
      results = [];
      for (i = 0, len = ref.length; i < len; i++) {
        f = ref[i];
        if (f.formid === p.formid) {
          results.push(f);
        }
      }
      return results;
    })())[0];
    if (form == null) {
      return;
    }
    builtImports = {};
    buildImport = function(impObj) {
      return builtImports[impObj.namespace] = buildModelWithRecursiveImports({
        formid: impObj.importformid,
        data: data,
        forms: p.forms
      }, element, true);
    };
    if (form.imports) { //in case imports left off the package
      form.imports.forEach(buildImport);
    }
    return exports.fromCoffee(form.model, data, el, builtImports, isImport);
  };
  if (typeof pkg.formid === 'string') {
    pkg.formid = parseInt(pkg.formid);
  }
  //data could be in the package and/or as a separate parameter.  Extend them together.
  data = _.extend(pkg.data || {}, data || {});
  return buildModelWithRecursiveImports(pkg, element, false);
};

exports.getChanges = function(modelAfter, beforeData) {
  var after, before, changedPath, changedPaths, changedPathsUniqObject, changedPathsUnique, changes, i, internalPatch, j, key, len, len1, modelBefore, outputPatch, p, path, val;
  modelBefore = modelAfter.cloneModel();
  modelBefore.applyData(beforeData, true);
  // This patch is parsed and used to generate the changes
  internalPatch = jiff.diff(modelBefore.buildOutputData(void 0, true), modelAfter.buildOutputData(void 0, true), {
    invertible: false
  });
  // This is the actual patch
  outputPatch = jiff.diff(modelBefore.buildOutputData(), modelAfter.buildOutputData(), {
    invertible: false
  });
  //array paths end in an index #. We only want the field, not the index of the value
  changedPaths = (function() {
    var i, len, results;
    results = [];
    for (i = 0, len = internalPatch.length; i < len; i++) {
      p = internalPatch[i];
      results.push(p.path.replace(/\/[0-9]+$/, ''));
    }
    return results;
  })();
  //get distinct field names. Arrays for example might appear multiple times
  changedPathsUniqObject = {};
  for (i = 0, len = changedPaths.length; i < len; i++) {
    val = changedPaths[i];
    changedPathsUniqObject[val] = val;
  }
  changedPathsUnique = (function() {
    var results;
    results = [];
    for (key in changedPathsUniqObject) {
      results.push(key);
    }
    return results;
  })();
  changes = [];
  for (j = 0, len1 = changedPathsUnique.length; j < len1; j++) {
    changedPath = changedPathsUnique[j];
    path = changedPath.slice(1);
    before = modelBefore.child(path);
    after = modelAfter.child(path);
    if (!_.isEqual(before != null ? before.value : void 0, after != null ? after.value : void 0)) { //deep equality for non-primitives
      changes.push({
        name: changedPath,
        title: after.title,
        before: before.buildOutputData(void 0, true),
        after: after.buildOutputData(void 0, true)
      });
    }
  }
  return {
    changes: changes,
    patch: outputPatch
  };
};
