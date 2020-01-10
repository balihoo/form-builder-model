var ModelBase, ModelField, ModelFieldDate, ModelFieldImage, ModelFieldTree, ModelGroup, RepeatingModelGroup, globals, jiff,
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty,
  slice = [].slice;

ModelBase = require('./modelBase');

ModelFieldImage = require('./modelFieldImage');

ModelFieldTree = require('./modelFieldTree');

ModelFieldDate = require('./modelFieldDate');

ModelField = require('./modelField');

globals = require('./globals');

jiff = require('jiff');


/*
  A ModelGroup is a model object that can contain any number of other groups and fields
 */

module.exports = ModelGroup = (function(superClass) {
  extend(ModelGroup, superClass);

  function ModelGroup() {
    return ModelGroup.__super__.constructor.apply(this, arguments);
  }

  ModelGroup.prototype.modelClassName = 'ModelGroup';

  ModelGroup.prototype.initialize = function() {
    this.setDefault('children', []);
    this.setDefault('root', this);
    this.set('isValid', true);
    this.set('data', null);
    this.setDefault('beforeInput', function(val) {
      return val;
    });
    this.setDefault('beforeOutput', function(val) {
      return val;
    });
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
    if (fieldObject.disabled == null) {
      fieldObject.disabled = this.disabled;
    }
    fld = (function() {
      switch (fieldObject.type) {
        case 'image':
          return new ModelFieldImage(fieldObject);
        case 'tree':
          return new ModelFieldTree(fieldObject);
        case 'date':
          return new ModelFieldDate(fieldObject);
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
      if (groupObject.disabled == null) {
        groupObject.disabled = this.disabled;
      }
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

  ModelGroup.prototype.buildOutputData = function(group, skipBeforeOutput) {
    var obj;
    if (group == null) {
      group = this;
    }
    obj = {};
    group.children.forEach(function(child) {
      var childData;
      childData = child.buildOutputData(void 0, skipBeforeOutput);
      if (childData !== void 0) {
        return obj[child.name] = childData;
      }
    });
    if (skipBeforeOutput) {
      return obj;
    } else {
      return group.beforeOutput(obj);
    }
  };

  ModelGroup.prototype.buildOutputDataString = function() {
    return JSON.stringify(this.buildOutputData());
  };

  ModelGroup.prototype.clear = function(purgeDefaults) {
    var child, i, j, key, len, len1, ref, ref1, results;
    if (purgeDefaults == null) {
      purgeDefaults = false;
    }
    if (this.data) {
      ref = Object.keys(this.data);
      for (i = 0, len = ref.length; i < len; i++) {
        key = ref[i];
        delete this.data[key];
      }
    }
    ref1 = this.children;
    results = [];
    for (j = 0, len1 = ref1.length; j < len1; j++) {
      child = ref1[j];
      results.push(child.clear(purgeDefaults));
    }
    return results;
  };

  ModelGroup.prototype.applyData = function(inData, clear, purgeDefaults) {
    var finalInData, key, ref, results, value;
    if (clear == null) {
      clear = false;
    }
    if (purgeDefaults == null) {
      purgeDefaults = false;
    }
    if (clear) {
      this.clear(purgeDefaults);
    }
    finalInData = this.beforeInput(jiff.clone(inData));

    /*
    This section preserves a link to the initially applied data object and merges subsequent applies on top
      of it in-place.  This is necessary for two reasons.
    First, the scope of the running model code also references the applied data through the 'data' variable.
      Every applied data must be available even though the runtime is not re-evaluated each time.
    Second, templated fields use this data as the input to their Mustache evaluation. See @renderTemplate()
     */
    if (this.data) {
      globals.mergeData(this.data, inData);
      this.trigger('change');
    } else {
      this.data = inData;
    }
    results = [];
    for (key in finalInData) {
      value = finalInData[key];
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

  RepeatingModelGroup.prototype.modelClassName = 'RepeatingModelGroup';

  RepeatingModelGroup.prototype.initialize = function() {
    this.setDefault('defaultValue', this.get('value') || []);
    this.set('value', []);
    return RepeatingModelGroup.__super__.initialize.apply(this, arguments);
  };

  RepeatingModelGroup.prototype.postBuild = function() {
    var c, i, len, ref;
    ref = this.children;
    for (i = 0, len = ref.length; i < len; i++) {
      c = ref[i];
      c.postBuild();
    }
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

  RepeatingModelGroup.prototype.buildOutputData = function(_, skipBeforeOutput) {
    var tempOut;
    tempOut = this.value.map(function(instance) {
      return RepeatingModelGroup.__super__.buildOutputData.call(this, instance);
    });
    if (skipBeforeOutput) {
      return tempOut;
    } else {
      return this.beforeOutput(tempOut);
    }
  };

  RepeatingModelGroup.prototype.clear = function(purgeDefaults) {
    if (purgeDefaults == null) {
      purgeDefaults = false;
    }
    this.value = [];
    if (!purgeDefaults) {
      if (this.defaultValue) {
        return this.addEachSimpleObject(this.defaultValue);
      }
    }
  };

  RepeatingModelGroup.prototype.applyData = function(inData, clear, purgeDefaults) {
    var finalInData;
    if (clear == null) {
      clear = false;
    }
    if (purgeDefaults == null) {
      purgeDefaults = false;
    }
    finalInData = this.beforeInput(jiff.clone(inData));
    if (finalInData) {
      this.value = [];
    } else {
      if (clear) {
        this.clear(purgeDefaults);
      }
    }
    return this.addEachSimpleObject(finalInData, clear, purgeDefaults);
  };

  RepeatingModelGroup.prototype.addEachSimpleObject = function(o, clear, purgeDefaults) {
    var added, i, key, len, obj, results, value;
    if (clear == null) {
      clear = false;
    }
    if (purgeDefaults == null) {
      purgeDefaults = false;
    }
    results = [];
    for (i = 0, len = o.length; i < len; i++) {
      obj = o[i];
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

  RepeatingModelGroup.prototype.cloneModel = function(root, constructor) {
    var clone, excludeAttributes;
    excludeAttributes = (constructor != null ? constructor.name : void 0) === 'ModelGroup' ? ['value', 'beforeInput', 'beforeOutput', 'description'] : [];
    clone = RepeatingModelGroup.__super__.cloneModel.call(this, root, constructor, excludeAttributes);
    clone.title = '';
    return clone;
  };

  RepeatingModelGroup.prototype.add = function() {
    var clone;
    clone = this.cloneModel(this.root, ModelGroup);
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
