
/*
  Encapsulates a group of form objects that can be added or removed to the form together multiple times
*/
var ModelBase, ModelField, ModelFieldDate, ModelFieldImage, ModelFieldTree, ModelGroup, RepeatingModelGroup, globals, jiff;

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
module.exports = ModelGroup = (function() {
  class ModelGroup extends ModelBase {
    initialize() {
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
      return super.initialize({
        objectMode: true
      });
    }

    postBuild() {
      var child, i, len, ref, results;
      ref = this.children;
      results = [];
      for (i = 0, len = ref.length; i < len; i++) {
        child = ref[i];
        results.push(child.postBuild());
      }
      return results;
    }

    field(...fieldParams) {
      var fieldObject, fld;
      fieldObject = this.buildParamObject(fieldParams, ['title', 'name', 'type', 'value']);
      if (fieldObject.disabled == null) {
        fieldObject.disabled = this.disabled;
      }
      //Could move this to a factory, but fields should only be created here so probably not necessary.
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
    }

    group(...groupParams) {
      var groupObject, grp, key, ref, val;
      grp = {};
      if (((ref = groupParams[0].constructor) != null ? ref.name : void 0) === 'ModelGroup') {
        grp = groupParams[0].cloneModel(this.root);
        //set any other supplied params on the clone
        groupParams.shift(); //remove the cloned object
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
    }

    // find a child by name.
    // can also find descendants multiple levels down by supplying one of
    // * an array of child names (in order) eg: group.child(['childname','grandchildname','greatgrandchildname'])
    // * a dot or slash delimited string. eg: group.child('childname.grandchildname.greatgrandchildname')
    child(path) {
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
    }

    setDirty(id, whatChanged) {
      var child, i, len, ref;
      ref = this.children;
      for (i = 0, len = ref.length; i < len; i++) {
        child = ref[i];
        child.setDirty(id, whatChanged);
      }
      return super.setDirty(id, whatChanged);
    }

    setClean(all) {
      var child, i, len, ref, results;
      super.setClean({
        objectMode: true
      });
      if (all) {
        ref = this.children;
        results = [];
        for (i = 0, len = ref.length; i < len; i++) {
          child = ref[i];
          results.push(child.setClean(all));
        }
        return results;
      }
    }

    recalculateRelativeProperties(collection = this.children) {
      var child, dirty, i, len, newValid;
      dirty = this.dirty;
      super.recalculateRelativeProperties({
        objectMode: true
      });
      //group is valid if all children are valid
      //might not need to check validy, but always need to recalculate all children anyway.
      newValid = true;
      for (i = 0, len = collection.length; i < len; i++) {
        child = collection[i];
        child.recalculateRelativeProperties();
        newValid && (newValid = child.isValid);
      }
      return this.isValid = newValid;
    }

    buildOutputData(group = this, skipBeforeOutput) {
      var obj;
      obj = {};
      console.log("buildOutputData======");
      group.children.forEach(function(child) {
        var childData;
        childData = child.buildOutputData(void 0, skipBeforeOutput);
        if (childData !== void 0) { // undefined values do not appear in output, but nulls do
          return obj[child.name] = childData;
        }
      });
      if (skipBeforeOutput) {
        return obj;
      } else {
        return group.beforeOutput(obj);
      }
    }

    buildOutputDataString() {
      return JSON.stringify(this.buildOutputData());
    }

    clear(purgeDefaults = false) {
      var child, i, j, key, len, len1, ref, ref1, results;
      //reset the 'data' object in-place, so model code will see an empty object too.
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
    }

    applyData(inData, clear = false, purgeDefaults = false) {
      var finalInData, key, ref, results, value;
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
    }

  };

  ModelGroup.prototype.modelClassName = 'ModelGroup';

  return ModelGroup;

}).call(this);

RepeatingModelGroup = (function() {
  class RepeatingModelGroup extends ModelGroup {
    initialize() {
      this.setDefault('defaultValue', this.get('value') || []);
      this.set('value', []);
      return super.initialize({
        objectMode: true
      });
    }

    postBuild() {
      var c, i, len, ref;
      ref = this.children;
      for (i = 0, len = ref.length; i < len; i++) {
        c = ref[i];
        c.postBuild();
      }
      return this.clear(); // Apply the defaultValue for the repeating model group after it has been built
    }

    setDirty(id, whatChanged) {
      var i, len, ref, val;
      ref = this.value;
      for (i = 0, len = ref.length; i < len; i++) {
        val = ref[i];
        val.setDirty(id, whatChanged);
      }
      return super.setDirty(id, whatChanged);
    }

    setClean(all) {
      var i, len, ref, results, val;
      super.setClean({
        objectMode: true
      });
      if (all) {
        ref = this.value;
        results = [];
        for (i = 0, len = ref.length; i < len; i++) {
          val = ref[i];
          results.push(val.setClean(all));
        }
        return results;
      }
    }

    recalculateRelativeProperties() {
      //ignore validity/visibility of children, only value instances
      return super.recalculateRelativeProperties(this.value);
    }

    buildOutputData(_, skipBeforeOutput) {
      var tempOut;
      tempOut = this.value.map(function(instance) {
        return ModelGroup.prototype.buildOutputData.apply(instance);
      });
      //super.buildOutputData instance #build output data of each value as a group, not repeating group
      if (skipBeforeOutput) {
        return tempOut;
      } else {
        return this.beforeOutput(tempOut);
      }
    }

    clear(purgeDefaults = false) {
      this.value = [];
      if (!purgeDefaults) {
        if (this.defaultValue) {
          // we do NOT want to run beforeInput when resetting to the default, so just convert each to a ModelGroup
          return this.addEachSimpleObject(this.defaultValue);
        }
      }
    }

    // applyData performs and clearing and transformations, then adds each simple object and a value ModelGroup
    applyData(inData, clear = false, purgeDefaults = false) {
      var finalInData;
      finalInData = this.beforeInput(jiff.clone(inData));
      // always clear out and replace the model value when data is supplied
      if (finalInData) {
        this.value = [];
      } else {
        if (clear) {
          this.clear(purgeDefaults);
        }
      }
      return this.addEachSimpleObject(finalInData, clear, purgeDefaults);
    }

    addEachSimpleObject(o, clear = false, purgeDefaults = false) {
      var added, i, key, len, obj, results, value;
//each value in the repeating group needs to be a repeating group object, not just the anonymous object in data
//add a new repeating group to value for each in data, and apply data like with a model group
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
    }

    cloneModel(root, constructor) {
      var clone, excludeAttributes;
      // When cloning to a ModelGroup exclude items not intended for subordinate clones
      excludeAttributes = (constructor != null ? constructor.name : void 0) === 'ModelGroup' ? ['value', 'beforeInput', 'beforeOutput', 'description'] : [];
      clone = super.cloneModel(root, constructor, excludeAttributes);
      // need name but not title.  Can't exclude in above clone because default to each other.
      clone.title = '';
      return clone;
    }

    add() {
      var clone;
      clone = this.cloneModel(this.root, ModelGroup);
      this.value.push(clone);
      this.trigger('change');
      return clone;
    }

    delete(index) {
      this.value.splice(index, 1);
      return this.trigger('change');
    }

  };

  RepeatingModelGroup.prototype.modelClassName = 'RepeatingModelGroup';

  return RepeatingModelGroup;

}).call(this);
