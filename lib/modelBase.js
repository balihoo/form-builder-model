  /*
   * Attributes common to groups and fields.
   */
  /* Some properties may be booleans or functions that return booleans
    Use this function to determine final boolean value.
    prop - the property to evaluate, which may be something primitive or a function
    deflt - the value to return if the property is undefined
  */
var Backbone, ModelBase, Mustache, _, getBoolOrFunctionResult, globals, moment, newid,
  indexOf = [].indexOf;

Backbone = require('backbone');

_ = require('underscore');

globals = require('./globals');

moment = require('moment');

Mustache = require('mustache');

// generate a new, unqiue identifier. Mostly good for label.
newid = (function() {
  var incId;
  incId = 0;
  return function() {
    incId++;
    return `fbid_${incId}`;
  };
})();

getBoolOrFunctionResult = function(prop, deflt = true) {
  if (typeof prop === 'function') {
    return !!prop();
  }
  if (prop === void 0) {
    return deflt;
  }
  return !!prop;
};

module.exports = ModelBase = (function() {
  class ModelBase extends Backbone.Model {
    initialize() {
      var key, ref, val;
      this.setDefault('visible', true);
      this.set('isVisible', true);
      this.setDefault('disabled', false);
      this.set('isDisabled', false);
      this.setDefault('onChangePropertiesHandlers', []);
      this.set('id', newid());
      this.setDefault('parent', void 0);
      this.setDefault('root', void 0);
      this.setDefault('name', this.get('title'));
      this.setDefault('title', this.get('name'));
      ref = this.attributes;
      //add accessors for each name access instead of get/set
      for (key in ref) {
        val = ref[key];
        ((key) => {
          return Object.defineProperty(this, key, {
            get: function() {
              return this.get(key);
            },
            set: function(newValue) {
              if ((this.get(key)) !== newValue) { //save an onChange event if value isnt different
                return this.set(key, newValue);
              }
            }
          });
        })(key);
      }
      this.bindPropFunctions('visible');
      this.bindPropFunctions('disabled');
      this.makePropArray('onChangePropertiesHandlers');
      this.bindPropFunctions('onChangePropertiesHandlers');
      // Other fields may need to update visibility, validity, etc when this field changes.
      // Fire an event on change, and catch those events fired by others.
      return this.on('change', function() {
        var ch, changeFunc, i, len, ref1;
        if (!globals.runtime) {
          return;
        }
        ref1 = this.onChangePropertiesHandlers;
        // model onChangePropertiesHandlers functions
        for (i = 0, len = ref1.length; i < len; i++) {
          changeFunc = ref1[i];
          changeFunc();
        }
        ch = this.changedAttributes();
        if (ch === false) { //no changes, manual trigger meant to fire everything
          ch = 'multiple';
        }
        this.root.setDirty(this.id, ch);
        return this.root.recalculateCycle();
      });
    }

    postBuild() {}

    setDefault(field, val) {
      if (this.get(field) == null) {
        return this.set(field, val);
      }
    }

    text(message) {
      return this.field(message, {
        type: 'info'
      });
    }

    //note: doesn't set the variable locally, just creates a bound version of it
    bindPropFunction(propName, func) {
      var model;
      model = this;
      return function() {
        var err, message;
        try {
          if (this instanceof ModelBase) {
            model = this;
          }
          return func.apply(model, arguments);
        } catch (error) {
          err = error;
          message = globals.makeErrorMessage(model, propName, err);
          return globals.handleError(message);
        }
      };
    }

    // bind properties that are functions to this object's context. Single functions or arrays of functions
    bindPropFunctions(propName) {
      var i, index, ref, results;
      if (Array.isArray(this[propName])) {
        results = [];
        for (index = i = 0, ref = this[propName].length; (0 <= ref ? i < ref : i > ref); index = 0 <= ref ? ++i : --i) {
          results.push(this[propName][index] = this.bindPropFunction(propName, this[propName][index]));
        }
        return results;
      } else if (typeof this[propName] === 'function') {
        return this.set(propName, this.bindPropFunction(propName, this[propName]), {
          silent: true
        });
      }
    }

    // ensure a property is array type, for when a single value is supplied where an array is needed.
    makePropArray(propName) {
      if (!Array.isArray(this.get(propName))) {
        return this.set(propName, [this.get(propName)]);
      }
    }

    // convert list of params, either object(s) or positional strings (or both), into an object
    // and add a few common properties
    // assumes always called by creator of child objects, and thus sets parent to this
    buildParamObject(params, paramPositions) {
      var i, key, len, param, paramIndex, paramObject, ref, val;
      paramObject = {};
      paramIndex = 0;
      for (i = 0, len = params.length; i < len; i++) {
        param = params[i];
        if (((ref = typeof param) === 'string' || ref === 'number' || ref === 'boolean') || Array.isArray(param)) {
          paramObject[paramPositions[paramIndex++]] = param;
        } else if (Object.prototype.toString.call(param) === '[object Object]') {
          for (key in param) {
            val = param[key];
            paramObject[key] = val;
          }
        }
      }
      paramObject.parent = this; //not a param, but common to everything that uses this method
      paramObject.root = this.root;
      return paramObject;
    }

    // set the dirty flag according to an object with all current changes
    // or, whatChanged could be a string to set as the dirty value
    setDirty(id, whatChanged) {
      var ch, drt, keys;
      ch = typeof whatChanged === 'string' ? whatChanged : (keys = Object.keys(whatChanged), keys.length === 1 ? `${id}:${keys[0]}` : 'multiple');
      drt = this.dirty === ch || this.dirty === '' ? ch : "multiple";
      return this.dirty = drt;
    }

    setClean() {
      return this.dirty = '';
    }

    shouldCallTriggerFunctionFor(dirty, attrName) {
      return dirty && dirty !== `${this.id}:${attrName}`;
    }

    // Any local properties that may need to recalculate if a foreign field changes.
    recalculateRelativeProperties() {
      var dirty;
      dirty = this.dirty;
      this.setClean();
      // visibility
      if (this.shouldCallTriggerFunctionFor(dirty, 'isVisible')) {
        this.isVisible = getBoolOrFunctionResult(this.visible);
      }
      
      // disabled status
      if (this.shouldCallTriggerFunctionFor(dirty, 'isDisabled')) {
        this.isDisabled = getBoolOrFunctionResult(this.disabled, false);
      }
      return this.trigger('recalculate');
    }

    // Add a new change properties handler to this object.
    // This change itself will trigger on change properties functions to run, including the just-added one!
    // If this trigger is not desired, set the second property to false
    onChangeProperties(f, trigger = true) {
      this.onChangePropertiesHandlers.push(this.bindPropFunction('onChangeProperties', f));
      if (trigger) {
        this.trigger('change');
      }
      return this;
    }

    //Deep copy this backbone model by creating a new one with the same attributes.
    //Overwrite each root attribute with the new root in the cloning form.
    cloneModel(newRoot = this.root, constructor = this.constructor, excludeAttributes = []) {
      var childClone, filteredAttributes, i, key, len, modelObj, myClone, newVal, ref, ref1, val;
      // first filter out undesired attributes from the clone
      filteredAttributes = {};
      ref = this.attributes;
      for (key in ref) {
        val = ref[key];
        if (indexOf.call(excludeAttributes, key) < 0) {
          filteredAttributes[key] = val;
        }
      }
      
      // now call the constructor with the desired attributes
      myClone = new constructor(filteredAttributes);
      ref1 = myClone.attributes;
      //some attributes need to be deep copied
      for (key in ref1) {
        val = ref1[key];
        //attributes that are form model objects need to themselves be cloned
        if (key === 'root') {
          myClone.set(key, newRoot);
        } else if (val instanceof ModelBase && (key !== 'root' && key !== 'parent')) {
          myClone.set(key, val.cloneModel(newRoot));
        } else if (Array.isArray(val)) {
          newVal = [];
          //array of form model objects, each needs to be cloned. Don't clone value objects
          if (val[0] instanceof ModelBase && key !== 'value') {
            for (i = 0, len = val.length; i < len; i++) {
              modelObj = val[i];
              childClone = modelObj.cloneModel(newRoot);
              //and if children/options are cloned, update their parent to this new object
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
    }

  };

  ModelBase.prototype.modelClassName = 'ModelBase';

  ModelBase.prototype.dirty = ''; //do as a local string not attribute so it is not included in @changed

  // Built-in functions for checking validity.
  ModelBase.prototype.validate = {
    required: function(value = this.value || '') {
      if (((function() {
        switch (typeof value) {
          case 'number':
          case 'boolean':
            return false; //these types cannot be empty
          case 'string':
            return value.length === 0;
          case 'object':
            return Object.keys(value).length === 0;
          default:
            return true; //null, undefined
        }
      })())) {
        return "This field is required";
      }
    },
    minLength: function(n) {
      return function(value = this.value || '') {
        if (value.length < n) {
          return `Must be at least ${n} characters long`;
        }
      };
    },
    maxLength: function(n) {
      return function(value = this.value || '') {
        if (value.length > n) {
          return `Can be at most ${n} characters long`;
        }
      };
    },
    number: function(value = this.value || '') {
      if (isNaN(+value)) {
        return "Must be an integer or decimal number. (ex. 42 or 1.618)";
      }
    },
    date: function(value = this.value || '', format = this.format) {
      if (value === '') {
        return;
      }
      if (!moment(value, format, true).isValid()) {
        return `Not a valid date or does not match the format ${format}`;
      }
    },
    email: function(value = this.value || '') {
      if (!value.match(/^[a-z0-9!\#$%&'*+\/=?^_`{|}~-]+(?:\.[a-z0-9!\#$%&'*+\/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/)) {
        return "Must be a valid email";
      }
    },
    url: function(value = this.value || '') {
      if (!value.match(/^(([A-Za-z]{3,9}:(?:\/\/)?)(?:[-;:&=\+\$,\w]+@)?[A-Za-z0-9.-]+|(?:www.|[-;:&=\+\$,\w]+@)[A-Za-z0-9.-]+)((?:\/[\+~%\/.\w-_]*)?\??(?:[-\+=&;%@.\w_]*)\#?(?:[\w]*))?$/)) {
        return "Must be a URL";
      }
    },
    dollars: function(value = this.value || '') {
      if (!value.match(/^\$(\d+\.\d\d|\d+)$/)) {
        return "Must be a dollar amount (ex. $3.99)";
      }
    },
    minSelections: function(n) {
      return function(value = this.value || '') {
        if (value.length < n) {
          return `Please select at least ${n} options`;
        }
      };
    },
    maxSelections: function(n) {
      return function(value = this.value || '') {
        if (value.length > n) {
          return `Please select at most ${n} options`;
        }
      };
    },
    selectedIsVisible: function(field = this) {
      var i, len, opt, ref;
      ref = field.options;
      for (i = 0, len = ref.length; i < len; i++) {
        opt = ref[i];
        if (opt.selected && !opt.isVisible) {
          return "A selected option is not currently available.  Please make a new choice from available options.";
        }
      }
    },
    template: function() { //ensure the template field contains valid mustache
      var e, template;
      if (!this.template) {
        return;
      }
      if (typeof this.template === 'object') {
        template = this.template.value;
      } else {
        template = this.parent.child(this.template).value;
      }
      try {
        Mustache.render(template, this.root.data);
      } catch (error) {
        e = error;
        return "Template field does not contain valid Mustache";
      }
    }
  };

  return ModelBase;

}).call(this);
