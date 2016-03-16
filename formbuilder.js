var Backbone, CoffeeScript, ModelBase, ModelField, ModelFieldImage, ModelGroup, ModelOption, ModelTree, Mustache, RepeatingModelGroup, _, empty, getVisible, jiff, makeErrorMessage, newid, runtime, throttledAlert, vm,
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty,
  slice = [].slice,
  indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

if (typeof window !== "undefined" && window !== null) {
  window.formbuilder = exports;
}

CoffeeScript = require('coffee-script');

Backbone = require('backbone');

_ = require('underscore');

Mustache = require('mustache');

vm = require('vm');

jiff = require('jiff');

empty = function(o) {
  return !o || ((o.length != null) && o.length === 0) || (typeof o === 'object' && Object.keys(o).length === 0);
};

newid = (function() {
  var incId;
  incId = 0;
  return function() {
    incId++;
    return "fbid_" + incId;
  };
})();

makeErrorMessage = function(model, propName, err) {
  var nameStack, node, stack;
  stack = [];
  node = model;
  while (node.name != null) {
    stack.push(node.name);
    node = node.parent;
  }
  stack.reverse();
  nameStack = stack.join('.');
  return "The '" + propName + "' function belonging to the field named '" + nameStack + "' threw an error with the message '" + err.message + "'";
};

if (typeof alert !== "undefined" && alert !== null) {
  throttledAlert = _.throttle(alert, 500);
}

exports.handleError = function(err) {
  if (!(err instanceof Error)) {
    err = new Error(err);
  }
  throw err;
};

exports.applyData = function(modelObject, data, clear, purgeDefaults) {
  return modelObject.applyData(data, clear, purgeDefaults);
};

exports.mergeData = function(a, b) {
  var key, value;
  if (b.constructor === Object) {
    for (key in b) {
      value = b[key];
      if ((a[key] != null) && a[key].constructor === Object && value.constructor === Object) {
        exports.mergeData(a[key], value);
      } else {
        a[key] = value;
      }
    }
    return a;
  } else {
    return exports.handleError('mergeData: The object to merge in is not an object');
  }
};

runtime = false;

exports.modelTests = [];

exports.fromCode = function(code, data, element, imports, isImport) {
  var assert, emit, newRoot, test;
  data || (data = {});
  if (typeof data === 'string') {
    data = JSON.parse(data);
  }
  runtime = false;
  exports.modelTests = [];
  test = function(func) {
    return exports.modelTests.push(func);
  };
  assert = function(bool, message) {
    if (message == null) {
      message = "A model test has failed";
    }
    if (!bool) {
      return exports.handleError(message);
    }
  };
  emit = function(name, context) {
    if (element && $) {
      return element.trigger($.Event(name, context));
    }
  };
  newRoot = new ModelGroup();
  newRoot.recalculating = false;
  newRoot.recalculateCycle = function() {};
  (function(root) {
    var field, group, sandbox, validate;
    field = newRoot.field.bind(newRoot);
    group = newRoot.group.bind(newRoot);
    root = newRoot.root;
    validate = newRoot.validate;
    if (typeof window === "undefined" || window === null) {
      sandbox = {
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
        console: {
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
  runtime = true;
  return newRoot;
};

exports.fromCoffee = function(code, data, element, imports, isImport) {
  return exports.fromCode(CoffeeScript.compile(code), data, element, imports, isImport);
};

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
        data: p.data,
        forms: p.forms
      }, element, true);
    };
    if (form.imports) {
      form.imports.forEach(buildImport);
    }
    return exports.fromCoffee(form.model, p.data, el, builtImports, isImport);
  };
  if (typeof pkg.formid === 'string') {
    pkg.formid = parseInt(pkg.formid);
  }
  pkg.data = _.extend(pkg.data || {}, data || {});
  return buildModelWithRecursiveImports(pkg, element, false);
};

exports.getChanges = function(modelAfter, beforeData) {
  var after, before, changedPath, changedPaths, changedPathsUniqObject, changedPathsUnique, changes, i, j, key, len, len1, modelBefore, p, patch, path, val;
  modelBefore = modelAfter.cloneModel();
  modelBefore.applyData(beforeData, true);
  patch = jiff.diff(modelBefore.buildOutputData(), modelAfter.buildOutputData(), {
    invertible: false
  });
  changedPaths = (function() {
    var i, len, results;
    results = [];
    for (i = 0, len = patch.length; i < len; i++) {
      p = patch[i];
      results.push(p.path.replace(/\/[0-9]+$/, ''));
    }
    return results;
  })();
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
    if ((before != null ? before.value : void 0) !== (after != null ? after.value : void 0)) {
      changes.push({
        name: changedPath,
        title: after.title,
        before: before.buildOutputData(),
        after: after.buildOutputData()
      });
    }
  }
  return {
    changes: changes,
    patch: patch
  };
};


/*
 * Attributes common to groups and fields.
 */

ModelBase = (function(superClass) {
  extend(ModelBase, superClass);

  function ModelBase() {
    return ModelBase.__super__.constructor.apply(this, arguments);
  }

  ModelBase.prototype.initialize = function() {
    var fn, key, ref, val;
    this.setDefault('visible', true);
    this.set('isVisible', true);
    this.setDefault('onChangePropertiesHandlers', []);
    this.set('id', newid());
    this.setDefault('parent', void 0);
    this.setDefault('root', void 0);
    this.setDefault('name', this.get('title'));
    this.setDefault('title', this.get('name'));
    ref = this.attributes;
    fn = (function(_this) {
      return function(key) {
        return Object.defineProperty(_this, key, {
          get: function() {
            return this.get(key);
          },
          set: function(newValue) {
            if ((this.get(key)) !== newValue) {
              return this.set(key, newValue);
            }
          }
        });
      };
    })(this);
    for (key in ref) {
      val = ref[key];
      fn(key);
    }
    this.bindPropFunctions('visible');
    this.makePropArray('onChangePropertiesHandlers');
    this.bindPropFunctions('onChangePropertiesHandlers');
    return this.on('change', function() {
      var ch, changeFunc, i, len, ref1;
      ref1 = this.onChangePropertiesHandlers;
      for (i = 0, len = ref1.length; i < len; i++) {
        changeFunc = ref1[i];
        changeFunc();
      }
      ch = this.changedAttributes();
      if (ch === false) {
        ch = 'multiple';
      }
      this.root.setDirty(this.id, ch);
      return this.root.recalculateCycle();
    });
  };

  ModelBase.prototype.postBuild = function() {};

  ModelBase.prototype.setDefault = function(field, val) {
    if (this.get(field) == null) {
      return this.set(field, val);
    }
  };

  ModelBase.prototype.text = function(message) {
    return this.field(message, {
      type: 'info'
    });
  };

  ModelBase.prototype.bindPropFunction = function(propName, func) {
    var model;
    model = this;
    return function() {
      var err, message;
      try {
        if (this instanceof ModelBase) {
          model = this;
        }
        return func.apply(model, arguments);
      } catch (_error) {
        err = _error;
        message = makeErrorMessage(model, propName, err);
        return exports.handleError(message);
      }
    };
  };

  ModelBase.prototype.bindPropFunctions = function(propName) {
    var i, index, ref, results;
    if (Array.isArray(this[propName])) {
      results = [];
      for (index = i = 0, ref = this[propName].length; 0 <= ref ? i < ref : i > ref; index = 0 <= ref ? ++i : --i) {
        results.push(this[propName][index] = this.bindPropFunction(propName, this[propName][index]));
      }
      return results;
    } else if (typeof this[propName] === 'function') {
      return this.set(propName, this.bindPropFunction(propName, this[propName]), {
        silent: true
      });
    }
  };

  ModelBase.prototype.makePropArray = function(propName) {
    if (!Array.isArray(this.get(propName))) {
      return this.set(propName, [this.get(propName)]);
    }
  };

  ModelBase.prototype.buildParamObject = function(params, paramPositions) {
    var i, key, len, param, paramIndex, paramObject, ref, val;
    paramObject = {};
    paramIndex = 0;
    for (i = 0, len = params.length; i < len; i++) {
      param = params[i];
      if ((ref = typeof param) === 'string' || ref === 'number') {
        paramObject[paramPositions[paramIndex++]] = param;
      } else if (Object.prototype.toString.call(param) === '[object Object]') {
        for (key in param) {
          val = param[key];
          paramObject[key] = val;
        }
      }
    }
    paramObject.parent = this;
    paramObject.root = this.root;
    return paramObject;
  };

  ModelBase.prototype.dirty = '';

  ModelBase.prototype.setDirty = function(id, whatChanged) {
    var ch, drt, keys;
    ch = typeof whatChanged === 'string' ? whatChanged : (keys = Object.keys(whatChanged), keys.length === 1 ? id + ":" + keys[0] : 'multiple');
    drt = this.dirty === ch || this.dirty === '' ? ch : "multiple";
    return this.dirty = drt;
  };

  ModelBase.prototype.setClean = function() {
    return this.dirty = '';
  };

  ModelBase.prototype.shouldCallTriggerFunctionFor = function(dirty, attrName) {
    return dirty && dirty !== (this.id + ":" + attrName);
  };

  ModelBase.prototype.recalculateRelativeProperties = function() {
    var dirty;
    dirty = this.dirty;
    this.setClean();
    if (this.shouldCallTriggerFunctionFor(dirty, 'isVisible')) {
      this.isVisible = getVisible(this.visible);
    }
    return this.trigger('recalculate');
  };

  ModelBase.prototype.onChangeProperties = function(f, trigger) {
    if (trigger == null) {
      trigger = true;
    }
    this.onChangePropertiesHandlers.push(this.bindPropFunction('onChangeProperties', f));
    if (trigger) {
      this.trigger('change');
    }
    return this;
  };

  ModelBase.prototype.validate = {
    required: function(value) {
      if (value == null) {
        value = this.value || '';
      }
      if (empty(value)) {
        return "This field is required";
      }
    },
    minLength: function(n) {
      return function(value) {
        if (value == null) {
          value = this.value || '';
        }
        if (value.length < n) {
          return "Must be at least " + n + " characters long";
        }
      };
    },
    maxLength: function(n) {
      return function(value) {
        if (value == null) {
          value = this.value || '';
        }
        if (value.length > n) {
          return "Can be at most " + n + " characters long";
        }
      };
    },
    number: function(value) {
      if (value == null) {
        value = this.value || '';
      }
      if (!value.match(/^[-+]?\d*(\.?\d*)?$/)) {
        return "Must be an integer or decimal number. (ex. 42 or 1.618)";
      }
    },
    email: function(value) {
      if (value == null) {
        value = this.value || '';
      }
      if (!value.match(/^[a-z0-9!\#$%&'*+\/=?^_`{|}~-]+(?:\.[a-z0-9!\#$%&'*+\/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/)) {
        return "Must be a valid email";
      }
    },
    url: function(value) {
      if (value == null) {
        value = this.value || '';
      }
      if (!value.match(/^(([A-Za-z]{3,9}:(?:\/\/)?)(?:[-;:&=\+\$,\w]+@)?[A-Za-z0-9.-]+|(?:www.|[-;:&=\+\$,\w]+@)[A-Za-z0-9.-]+)((?:\/[\+~%\/.\w-_]*)?\??(?:[-\+=&;%@.\w_]*)\#?(?:[\w]*))?$/)) {
        return "Must be a URL";
      }
    },
    dollars: function(value) {
      if (value == null) {
        value = this.value || '';
      }
      if (!value.match(/^\$(\d+\.\d\d|\d+)$/)) {
        return "Must be a dollar amount (ex. $3.99)";
      }
    },
    minSelections: function(n) {
      return function(value) {
        if (value == null) {
          value = this.value || '';
        }
        if (value.length < n) {
          return "Please select at least " + n + " options";
        }
      };
    },
    maxSelections: function(n) {
      return function(value) {
        if (value == null) {
          value = this.value || '';
        }
        if (value.length > n) {
          return "Please select at most " + n + " options";
        }
      };
    },
    selectedIsVisible: function(field) {
      var i, len, opt, ref;
      if (field == null) {
        field = this;
      }
      ref = field.options;
      for (i = 0, len = ref.length; i < len; i++) {
        opt = ref[i];
        if (opt.selected && !opt.isVisible) {
          return "A selected option is not currently available.  Please make a new choice from available options.";
        }
      }
    }
  };

  ModelBase.prototype.cloneModel = function(newRoot, constructor) {
    var childClone, i, key, len, modelObj, myClone, newVal, ref, val;
    if (newRoot == null) {
      newRoot = this.root;
    }
    if (constructor == null) {
      constructor = this.constructor;
    }
    myClone = new constructor(this.attributes);
    ref = myClone.attributes;
    for (key in ref) {
      val = ref[key];
      if (key === 'root') {
        myClone.set(key, newRoot);
      } else if (val instanceof ModelBase && (key !== 'root' && key !== 'parent')) {
        myClone.set(key, val.cloneModel(newRoot));
      } else if (Array.isArray(val)) {
        newVal = [];
        if (val[0] instanceof ModelBase && key !== 'value') {
          for (i = 0, len = val.length; i < len; i++) {
            modelObj = val[i];
            childClone = modelObj.cloneModel(newRoot);
            if (childClone.parent === this) {
              childClone.parent = myClone;
              if (key === 'options' && childClone.selected) {
                myClone.addOptionValue(childClone.value);
              }
            }
            newVal.push(childClone);
          }
        } else {
          newVal = _.clone(val);
        }
        myClone.set(key, newVal);
      }
    }
    return myClone;
  };

  return ModelBase;

})(Backbone.Model);


/*
  A ModelGroup is a model object that can contain any number of other groups and fields
 */

ModelGroup = (function(superClass) {
  extend(ModelGroup, superClass);

  function ModelGroup() {
    return ModelGroup.__super__.constructor.apply(this, arguments);
  }

  ModelGroup.prototype.initialize = function() {
    this.setDefault('children', []);
    this.setDefault('root', this);
    this.set('isValid', true);
    this.set('data', null);
    return ModelGroup.__super__.initialize.apply(this, arguments);
  };

  ModelGroup.prototype.postBuild = function() {
    var child, i, len, ref, results;
    ref = this.children;
    results = [];
    for (i = 0, len = ref.length; i < len; i++) {
      child = ref[i];
      results.push(child.postBuild());
    }
    return results;
  };

  ModelGroup.prototype.field = function() {
    var fieldObject, fieldParams, fld;
    fieldParams = 1 <= arguments.length ? slice.call(arguments, 0) : [];
    fieldObject = this.buildParamObject(fieldParams, ['title', 'name', 'type', 'value']);
    fld = (function() {
      switch (fieldObject.type) {
        case 'image':
          return new ModelFieldImage(fieldObject);
        case 'tree':
          return new ModelTree(fieldObject);
        default:
          return new ModelField(fieldObject);
      }
    })();
    this.children.push(fld);
    this.trigger('change');
    return fld;
  };

  ModelGroup.prototype.group = function() {
    var groupObject, groupParams, grp, key, ref, val;
    groupParams = 1 <= arguments.length ? slice.call(arguments, 0) : [];
    grp = {};
    if (((ref = groupParams[0].constructor) != null ? ref.name : void 0) === 'ModelGroup') {
      grp = groupParams[0].cloneModel(this.root);
      groupParams.shift();
      groupObject = this.buildParamObject(groupParams, ['title', 'name', 'description']);
      if (groupObject.name == null) {
        groupObject.name = groupObject.title;
      }
      if (groupObject.title == null) {
        groupObject.title = groupObject.name;
      }
      for (key in groupObject) {
        val = groupObject[key];
        grp.set(key, val);
      }
    } else {
      groupObject = this.buildParamObject(groupParams, ['title', 'name', 'description']);
      if (groupObject.repeating) {
        grp = new RepeatingModelGroup(groupObject);
      } else {
        grp = new ModelGroup(groupObject);
      }
    }
    this.children.push(grp);
    this.trigger('change');
    return grp;
  };

  ModelGroup.prototype.child = function(path) {
    var c, child, i, len, name, ref;
    if (!(Array.isArray(path))) {
      path = path.split(/[.\/]/);
    }
    name = path.shift();
    ref = this.children;
    for (i = 0, len = ref.length; i < len; i++) {
      c = ref[i];
      if (c.name === name) {
        child = c;
      }
    }
    if (path.length === 0) {
      return child;
    } else {
      return child.child(path);
    }
  };

  ModelGroup.prototype.setDirty = function(id, whatChanged) {
    var child, i, len, ref;
    ref = this.children;
    for (i = 0, len = ref.length; i < len; i++) {
      child = ref[i];
      child.setDirty(id, whatChanged);
    }
    return ModelGroup.__super__.setDirty.call(this, id, whatChanged);
  };

  ModelGroup.prototype.setClean = function(all) {
    var child, i, len, ref, results;
    ModelGroup.__super__.setClean.apply(this, arguments);
    if (all) {
      ref = this.children;
      results = [];
      for (i = 0, len = ref.length; i < len; i++) {
        child = ref[i];
        results.push(child.setClean(all));
      }
      return results;
    }
  };

  ModelGroup.prototype.recalculateRelativeProperties = function(collection) {
    var child, dirty, i, len, newValid;
    if (collection == null) {
      collection = this.children;
    }
    dirty = this.dirty;
    ModelGroup.__super__.recalculateRelativeProperties.apply(this, arguments);
    newValid = true;
    for (i = 0, len = collection.length; i < len; i++) {
      child = collection[i];
      child.recalculateRelativeProperties();
      newValid && (newValid = child.isValid);
    }
    return this.isValid = newValid;
  };

  ModelGroup.prototype.buildOutputData = function(group) {
    var obj;
    if (group == null) {
      group = this;
    }
    obj = {};
    group.children.forEach(function(child) {
      var data;
      data = child.buildOutputData();
      if (data != null) {
        return obj[child.name] = child.buildOutputData();
      }
    });
    return obj;
  };

  ModelGroup.prototype.buildOutputDataString = function() {
    return JSON.stringify(this.buildOutputData());
  };

  ModelGroup.prototype.clear = function(purgeDefaults) {
    var child, i, len, ref, results;
    if (purgeDefaults == null) {
      purgeDefaults = false;
    }
    ref = this.children;
    results = [];
    for (i = 0, len = ref.length; i < len; i++) {
      child = ref[i];
      results.push(child.clear(purgeDefaults));
    }
    return results;
  };

  ModelGroup.prototype.applyData = function(data, clear, purgeDefaults) {
    var key, ref, results, value;
    if (clear == null) {
      clear = false;
    }
    if (purgeDefaults == null) {
      purgeDefaults = false;
    }
    if (clear) {
      this.clear(purgeDefaults);
    }
    if (this.data) {
      this.data = exports.mergeData(this.data, data);
      this.trigger('change');
    } else {
      this.data = data;
    }
    results = [];
    for (key in data) {
      value = data[key];
      results.push((ref = this.child(key)) != null ? ref.applyData(value) : void 0);
    }
    return results;
  };

  return ModelGroup;

})(ModelBase);


/*
  Encapsulates a group of form objects that can be added or removed to the form together multiple times
 */

RepeatingModelGroup = (function(superClass) {
  extend(RepeatingModelGroup, superClass);

  function RepeatingModelGroup() {
    return RepeatingModelGroup.__super__.constructor.apply(this, arguments);
  }

  RepeatingModelGroup.prototype.initialize = function() {
    this.setDefault('defaultValue', this.get('value') || []);
    this.set('value', []);
    return RepeatingModelGroup.__super__.initialize.apply(this, arguments);
  };

  RepeatingModelGroup.prototype.postBuild = function() {
    return this.clear();
  };

  RepeatingModelGroup.prototype.setDirty = function(id, whatChanged) {
    var i, len, ref, val;
    ref = this.value;
    for (i = 0, len = ref.length; i < len; i++) {
      val = ref[i];
      val.setDirty(id, whatChanged);
    }
    return RepeatingModelGroup.__super__.setDirty.call(this, id, whatChanged);
  };

  RepeatingModelGroup.prototype.setClean = function(all) {
    var i, len, ref, results, val;
    RepeatingModelGroup.__super__.setClean.apply(this, arguments);
    if (all) {
      ref = this.value;
      results = [];
      for (i = 0, len = ref.length; i < len; i++) {
        val = ref[i];
        results.push(val.setClean(all));
      }
      return results;
    }
  };

  RepeatingModelGroup.prototype.recalculateRelativeProperties = function() {
    return RepeatingModelGroup.__super__.recalculateRelativeProperties.call(this, this.value);
  };

  RepeatingModelGroup.prototype.buildOutputData = function() {
    return this.value.map(function(instance) {
      return RepeatingModelGroup.__super__.buildOutputData.call(this, instance);
    });
  };

  RepeatingModelGroup.prototype.clear = function(purgeDefaults) {
    if (purgeDefaults == null) {
      purgeDefaults = false;
    }
    this.value = [];
    if (!purgeDefaults) {
      if (this.defaultValue) {
        return this.applyData(this.defaultValue);
      }
    }
  };

  RepeatingModelGroup.prototype.applyData = function(data, clear, purgeDefaults) {
    var added, i, key, len, obj, results, value;
    if (clear == null) {
      clear = false;
    }
    if (purgeDefaults == null) {
      purgeDefaults = false;
    }
    if (data) {
      this.value = [];
    } else {
      if (clear) {
        this.clear(purgeDefaults);
      }
    }
    results = [];
    for (i = 0, len = data.length; i < len; i++) {
      obj = data[i];
      added = this.add();
      results.push((function() {
        var ref, results1;
        results1 = [];
        for (key in obj) {
          value = obj[key];
          results1.push((ref = added.child(key)) != null ? ref.applyData(value, clear, purgeDefaults) : void 0);
        }
        return results1;
      })());
    }
    return results;
  };

  RepeatingModelGroup.prototype.add = function() {
    var clone;
    clone = this.cloneModel(this.root, ModelGroup);
    clone.title = '';
    clone.value = [];
    this.value.push(clone);
    this.trigger('change');
    return clone;
  };

  RepeatingModelGroup.prototype["delete"] = function(index) {
    this.value.splice(index, 1);
    return this.trigger('change');
  };

  return RepeatingModelGroup;

})(ModelGroup);


/*
  A ModelField represents a model object that render as a DOM field
 */

ModelField = (function(superClass) {
  extend(ModelField, superClass);

  function ModelField() {
    return ModelField.__super__.constructor.apply(this, arguments);
  }

  ModelField.prototype.initialize = function() {
    var ref, ref1;
    this.setDefault('type', 'text');
    this.setDefault('options', []);
    this.setDefault('value', (this.get('type')) === 'multiselect' ? [] : (this.get('type')) === 'bool' ? false : (this.get('type')) === 'button' ? null : '');
    this.setDefault('defaultValue', this.get('value'));
    this.set('isValid', true);
    this.setDefault('validators', []);
    this.setDefault('onChangeHandlers', []);
    this.setDefault('dynamicValue', null);
    this.setDefault('template', null);
    this.setDefault('autocomplete', null);
    ModelField.__super__.initialize.apply(this, arguments);
    if ((ref = this.type) !== 'info' && ref !== 'text' && ref !== 'url' && ref !== 'email' && ref !== 'tel' && ref !== 'time' && ref !== 'date' && ref !== 'textarea' && ref !== 'bool' && ref !== 'tree' && ref !== 'color' && ref !== 'select' && ref !== 'multiselect' && ref !== 'image' && ref !== 'button') {
      return exports.handleError("Bad field type: " + this.type);
    }
    this.bindPropFunctions('dynamicValue');
    while ((Array.isArray(this.value)) && (this.type !== 'multiselect') && (this.type !== 'tree') && (this.type !== 'button')) {
      this.value = this.value[0];
    }
    if (typeof this.value === 'string' && (this.type === 'multiselect')) {
      this.value = [this.value];
    }
    if (this.type === 'bool' && typeof this.value !== 'bool') {
      this.value = !!this.value;
    }
    this.makePropArray('validators');
    this.bindPropFunctions('validators');
    this.makePropArray('onChangeHandlers');
    this.bindPropFunctions('onChangeHandlers');
    if (this.optionsFrom != null) {
      if ((this.optionsFrom.url == null) || (this.optionsFrom.parseResults == null)) {
        return exports.handleError('When fetching options remotely, both url and parseResults properties are required');
      }
      if (typeof ((ref1 = this.optionsFrom) != null ? ref1.url : void 0) === 'function') {
        this.optionsFrom.url = this.bindPropFunction('optionsFrom.url', this.optionsFrom.url);
      }
      if (typeof this.optionsFrom.parseResults !== 'function') {
        return exports.handleError('optionsFrom.parseResults must be a function');
      }
      this.optionsFrom.parseResults = this.bindPropFunction('optionsFrom.parseResults', this.optionsFrom.parseResults);
    }
    this.updateOptionsSelected();
    this.on('change:value', function() {
      var changeFunc, i, len, ref2;
      ref2 = this.onChangeHandlers;
      for (i = 0, len = ref2.length; i < len; i++) {
        changeFunc = ref2[i];
        changeFunc();
      }
      return this.updateOptionsSelected();
    });
    return this.on('change:type', function() {
      var ref2;
      if (this.type === 'multiselect') {
        this.value = this.value.length > 0 ? [this.value] : [];
      } else if (this.previousAttributes().type === 'multiselect') {
        this.value = this.value.length > 0 ? this.value[0] : '';
      }
      if (this.options.length > 0 && !((ref2 = this.type) === 'select' || ref2 === 'multiselect')) {
        return this.type = 'select';
      }
    });
  };

  ModelField.prototype.getOptionsFrom = function() {
    var ref, url;
    if (this.optionsFrom == null) {
      return;
    }
    url = typeof this.optionsFrom.url === 'function' ? this.optionsFrom.url() : this.optionsFrom.url;
    if (this.prevUrl === url) {
      return;
    }
    this.prevUrl = url;
    return typeof window !== "undefined" && window !== null ? (ref = window.formbuilderproxy) != null ? ref.getFromProxy({
      url: url,
      method: this.optionsFrom.method || 'get',
      headerKey: this.optionsFrom.headerKey
    }, (function(_this) {
      return function(error, data) {
        var i, len, mappedResults, opt, results;
        if (error) {
          return exports.handleError(makeErrorMessage(_this, 'optionsFrom', error));
        }
        mappedResults = _this.optionsFrom.parseResults(data);
        if (!Array.isArray(mappedResults)) {
          return exports.handleError('results of parseResults must be an array of option parameters');
        }
        _this.options = [];
        results = [];
        for (i = 0, len = mappedResults.length; i < len; i++) {
          opt = mappedResults[i];
          results.push(_this.option(opt));
        }
        return results;
      };
    })(this)) : void 0 : void 0;
  };

  ModelField.prototype.validityMessage = void 0;

  ModelField.prototype.field = function() {
    var obj, ref;
    obj = 1 <= arguments.length ? slice.call(arguments, 0) : [];
    return (ref = this.parent).field.apply(ref, obj);
  };

  ModelField.prototype.group = function() {
    var obj, ref;
    obj = 1 <= arguments.length ? slice.call(arguments, 0) : [];
    return (ref = this.parent).group.apply(ref, obj);
  };

  ModelField.prototype.option = function() {
    var i, len, opt, optionObject, optionParams, ref, ref1;
    optionParams = 1 <= arguments.length ? slice.call(arguments, 0) : [];
    optionObject = this.buildParamObject(optionParams, ['title', 'value', 'selected']);
    if (!((ref = this.type) === 'select' || ref === 'multiselect' || ref === 'image')) {
      this.type = 'select';
    }
    this.options = this.options.concat(new ModelOption(optionObject));
    ref1 = this.options;
    for (i = 0, len = ref1.length; i < len; i++) {
      opt = ref1[i];
      if (opt.selected) {
        this.addOptionValue(opt.value);
      }
    }
    this.defaultValue = this.value;
    this.updateOptionsSelected();
    return this;
  };

  ModelField.prototype.updateOptionsSelected = function() {
    var i, len, opt, ref, results;
    ref = this.options;
    results = [];
    for (i = 0, len = ref.length; i < len; i++) {
      opt = ref[i];
      results.push(opt.selected = this.hasValue(opt.value));
    }
    return results;
  };

  ModelField.prototype.child = function(value) {
    var i, len, o, ref;
    if (Array.isArray(value)) {
      value = value.shift();
    }
    ref = this.options;
    for (i = 0, len = ref.length; i < len; i++) {
      o = ref[i];
      if (o.value === value) {
        return o;
      }
    }
  };

  ModelField.prototype.validator = function(func) {
    this.validators.push(this.bindPropFunction('validator', func));
    this.trigger('change');
    return this;
  };

  ModelField.prototype.onChange = function(f) {
    this.onChangeHandlers.push(this.bindPropFunction('onChange', f));
    this.trigger('change');
    return this;
  };

  ModelField.prototype.setDirty = function(id, whatChanged) {
    var i, len, opt, ref;
    ref = this.options;
    for (i = 0, len = ref.length; i < len; i++) {
      opt = ref[i];
      opt.setDirty(id, whatChanged);
    }
    return ModelField.__super__.setDirty.call(this, id, whatChanged);
  };

  ModelField.prototype.setClean = function(all) {
    var i, len, opt, ref, results;
    ModelField.__super__.setClean.apply(this, arguments);
    if (all) {
      ref = this.options;
      results = [];
      for (i = 0, len = ref.length; i < len; i++) {
        opt = ref[i];
        results.push(opt.setClean(all));
      }
      return results;
    }
  };

  ModelField.prototype.recalculateRelativeProperties = function() {
    var dirty, i, j, len, len1, opt, ref, ref1, results, validator, validityMessage, value;
    dirty = this.dirty;
    ModelField.__super__.recalculateRelativeProperties.apply(this, arguments);
    if (this.shouldCallTriggerFunctionFor(dirty, 'isValid')) {
      validityMessage = void 0;
      ref = this.validators;
      for (i = 0, len = ref.length; i < len; i++) {
        validator = ref[i];
        if (typeof validator === 'function') {
          validityMessage = validator.call(this);
        }
        if (typeof validityMessage === 'function') {
          return exports.handleError("A validator on field '" + this.name + "' returned a function");
        }
        if (validityMessage) {
          break;
        }
      }
      this.validityMessage = validityMessage;
      this.set({
        isValid: validityMessage == null
      });
    }
    if (this.template && this.shouldCallTriggerFunctionFor(dirty, 'value')) {
      this.renderTemplate();
    } else {
      if (typeof this.dynamicValue === 'function' && this.shouldCallTriggerFunctionFor(dirty, 'value')) {
        value = this.dynamicValue();
        if (typeof value === 'function') {
          return exports.handleError("dynamicValue on field '" + this.name + "' returned a function");
        }
        this.set('value', value);
      }
    }
    if (this.shouldCallTriggerFunctionFor(dirty, 'options')) {
      this.getOptionsFrom();
    }
    ref1 = this.options;
    results = [];
    for (j = 0, len1 = ref1.length; j < len1; j++) {
      opt = ref1[j];
      results.push(opt.recalculateRelativeProperties());
    }
    return results;
  };

  ModelField.prototype.addOptionValue = function(val) {
    if (this.type === 'multiselect') {
      if (!(indexOf.call(this.value, val) >= 0)) {
        return this.value.push(val);
      }
    } else {
      return this.value = val;
    }
  };

  ModelField.prototype.removeOptionValue = function(val) {
    if (this.type === 'multiselect') {
      if (indexOf.call(this.value, val) >= 0) {
        return this.value = this.value.filter(function(v) {
          return v !== val;
        });
      }
    } else if (this.value === val) {
      return this.value = '';
    }
  };

  ModelField.prototype.hasValue = function(val) {
    if (this.type === 'multiselect') {
      return indexOf.call(this.value, val) >= 0;
    } else {
      return val === this.value;
    }
  };

  ModelField.prototype.buildOutputData = function() {
    if (this.type !== 'info') {
      return this.value;
    }
  };

  ModelField.prototype.clear = function(purgeDefaults) {
    if (purgeDefaults == null) {
      purgeDefaults = false;
    }
    if (purgeDefaults) {
      return this.value = (function() {
        switch (this.type) {
          case 'multiselect':
            return [];
          case 'bool':
            return false;
          default:
            return '';
        }
      }).call(this);
    } else {
      return this.value = this.defaultValue;
    }
  };

  ModelField.prototype.ensureValueInOptions = function() {
    var existingOption, i, j, k, len, len1, len2, o, ref, ref1, ref2, ref3, results, v;
    if ((ref = this.type) !== 'select' && ref !== 'multiselect' && ref !== 'image') {
      return;
    }
    if (typeof this.value === 'string') {
      ref1 = this.options;
      for (i = 0, len = ref1.length; i < len; i++) {
        o = ref1[i];
        if (o.value === this.value) {
          existingOption = o;
        }
      }
      if (!existingOption) {
        return this.option(this.value);
      }
    } else if (Array.isArray(this.value)) {
      ref2 = this.value;
      results = [];
      for (j = 0, len1 = ref2.length; j < len1; j++) {
        v = ref2[j];
        ref3 = this.options;
        for (k = 0, len2 = ref3.length; k < len2; k++) {
          o = ref3[k];
          if (o.value === v) {
            existingOption = o;
          }
        }
        if (!existingOption) {
          results.push(this.option(v));
        } else {
          results.push(void 0);
        }
      }
      return results;
    }
  };

  ModelField.prototype.applyData = function(data, clear, purgeDefaults) {
    if (clear == null) {
      clear = false;
    }
    if (purgeDefaults == null) {
      purgeDefaults = false;
    }
    if (clear) {
      this.clear(purgeDefaults);
    }
    if (data != null) {
      this.value = data;
      return this.ensureValueInOptions();
    }
  };

  ModelField.prototype.renderTemplate = function() {
    var template;
    if (typeof this.template === 'object') {
      template = this.template.value;
    } else {
      template = this.parent.child(this.template).value;
    }
    return this.value = Mustache.render(template, this.root.data);
  };

  return ModelField;

})(ModelBase);

ModelTree = (function(superClass) {
  extend(ModelTree, superClass);

  function ModelTree() {
    return ModelTree.__super__.constructor.apply(this, arguments);
  }

  ModelTree.prototype.initialize = function() {
    this.setDefault('value', []);
    ModelTree.__super__.initialize.apply(this, arguments);
    return this.get('value').sort();
  };

  ModelTree.prototype.add = function(item) {
    var index;
    if (_.indexOf(this.value, item, 'isSorted') === -1) {
      if (item instanceof Object) {
        index = _.sortedIndex(this.value, item, 'value');
      } else {
        index = _.sortedIndex(this.value, item);
      }
      this.value.splice(index, 0, item);
      return this.trigger('change');
    }
  };

  ModelTree.prototype.option = function(item) {
    var context, i, j, last, len, piece, pieces, ref;
    ref = item.split(' > '), pieces = 2 <= ref.length ? slice.call(ref, 0, i = ref.length - 1) : (i = 0, []), last = ref[i++];
    context = this.options;
    for (j = 0, len = pieces.length; j < len; j++) {
      piece = pieces[j];
      if (!context[piece]) {
        context = context[piece] = {};
      } else {
        context = context[piece];
      }
    }
    if (context instanceof Array) {
      context.push(last);
    } else {
      context[last] = null;
    }
    this.trigger('change');
    return this;
  };

  ModelTree.prototype.remove = function(item) {
    var index, search;
    if (item instanceof Object) {
      search = _.findWhere(this.value, item);
      index = _.indexOf(this.value, search);
    } else {
      index = _.indexOf(this.value, item, 'isSorted');
    }
    if (index !== -1) {
      this.value.splice(index, 1);
      return this.trigger('change');
    }
  };

  ModelTree.prototype.clear = function(purgeDefaults) {
    if (purgeDefaults == null) {
      purgeDefaults = false;
    }
    return this.value = purgeDefaults ? [] : this.defaultValue;
  };

  return ModelTree;

})(ModelField);

ModelFieldImage = (function(superClass) {
  extend(ModelFieldImage, superClass);

  function ModelFieldImage() {
    return ModelFieldImage.__super__.constructor.apply(this, arguments);
  }

  ModelFieldImage.prototype.initialize = function() {
    this.setDefault('value', {});
    this.setDefault('allowUpload', false);
    this.setDefault('imagesPerPage', 4);
    this.set('optionsChanged', false);
    return ModelFieldImage.__super__.initialize.apply(this, arguments);
  };

  ModelFieldImage.prototype.option = function() {
    var optionObject, optionParams;
    optionParams = 1 <= arguments.length ? slice.call(arguments, 0) : [];
    optionObject = this.buildParamObject(optionParams, ['fileID', 'fileUrl', 'thumbnailUrl']);
    if (optionObject.fileID == null) {
      optionObject.fileID = optionObject.fileUrl;
    }
    if (optionObject.thumbnailUrl == null) {
      optionObject.thumbnailUrl = optionObject.fileUrl;
    }
    optionObject.value = {
      fileID: optionObject.fileID,
      fileUrl: optionObject.fileUrl,
      thumbnailUrl: optionObject.thumbnailUrl
    };
    this.optionsChanged = true;
    return ModelFieldImage.__super__.option.call(this, optionObject);
  };

  ModelFieldImage.prototype.child = function(fileID) {
    var i, len, o, ref;
    if (Array.isArray(fileID)) {
      fileID = fileID.shift();
    }
    if (typeof fileID === 'object') {
      fileID = fileID.fileID;
    }
    ref = this.options;
    for (i = 0, len = ref.length; i < len; i++) {
      o = ref[i];
      if (o.fileID === fileID) {
        return o;
      }
    }
  };

  ModelFieldImage.prototype.removeOptionValue = function(val) {
    if (this.value.fileID === val.fileID) {
      return this.value = {};
    }
  };

  ModelFieldImage.prototype.hasValue = function(val) {
    return val.fileID === this.value.fileID && val.thumbnailUrl === this.value.thumbnailUrl && val.fileUrl === this.value.fileUrl;
  };

  ModelFieldImage.prototype.clear = function(purgeDefaults) {
    if (purgeDefaults == null) {
      purgeDefaults = false;
    }
    return this.value = purgeDefaults ? {} : this.defaultValue;
  };

  ModelFieldImage.prototype.ensureValueInOptions = function() {
    var existingOption, i, len, o, ref;
    ref = this.options;
    for (i = 0, len = ref.length; i < len; i++) {
      o = ref[i];
      if (o.attributes.fileID === this.value.fileID) {
        existingOption = o;
      }
    }
    if (!existingOption) {
      return this.option(this.value);
    }
  };

  return ModelFieldImage;

})(ModelField);

ModelOption = (function(superClass) {
  extend(ModelOption, superClass);

  function ModelOption() {
    return ModelOption.__super__.constructor.apply(this, arguments);
  }

  ModelOption.prototype.initialize = function() {
    this.setDefault('value', this.get('title'));
    this.setDefault('title', this.get('value'));
    this.setDefault('selected', false);
    ModelOption.__super__.initialize.apply(this, arguments);
    return this.on('change:selected', function() {
      if (this.selected) {
        return this.parent.addOptionValue(this.value);
      } else {
        return this.parent.removeOptionValue(this.value);
      }
    });
  };

  return ModelOption;

})(ModelBase);

exports.buildOutputData = function(model) {
  return model.buildOutputData();
};

getVisible = function(visible) {
  if (typeof visible === 'function') {
    return !!visible();
  }
  if (visible === void 0) {
    return true;
  }
  return !!visible;
};
