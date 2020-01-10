
/*
 * Attributes common to groups and fields.
 */
var Backbone, ModelBase, Mustache, _, getBoolOrFunctionResult, globals, moment, newid,
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty,
  indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

Backbone = require('backbone');

_ = require('underscore');

globals = require('./globals');

moment = require('moment');

Mustache = require('mustache');

newid = (function() {
  var incId;
  incId = 0;
  return function() {
    incId++;
    return "fbid_" + incId;
  };
})();


/* Some properties may be booleans or functions that return booleans
  Use this function to determine final boolean value.
  prop - the property to evaluate, which may be something primitive or a function
  deflt - the value to return if the property is undefined
 */

getBoolOrFunctionResult = function(prop, deflt) {
  if (deflt == null) {
    deflt = true;
  }
  if (typeof prop === 'function') {
    return !!prop();
  }
  if (prop === void 0) {
    return deflt;
  }
  return !!prop;
};

module.exports = ModelBase = (function(superClass) {
  extend(ModelBase, superClass);

  function ModelBase() {
    return ModelBase.__super__.constructor.apply(this, arguments);
  }

  ModelBase.prototype.modelClassName = 'ModelBase';

  ModelBase.prototype.initialize = function() {
    var fn, key, ref, val;
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
    this.bindPropFunctions('disabled');
    this.makePropArray('onChangePropertiesHandlers');
    this.bindPropFunctions('onChangePropertiesHandlers');
    return this.on('change', function() {
      var ch, changeFunc, i, len, ref1;
      if (!globals.runtime) {
        return;
      }
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
      } catch (error) {
        err = error;
        message = globals.makeErrorMessage(model, propName, err);
        return globals.handleError(message);
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
      if (((ref = typeof param) === 'string' || ref === 'number' || ref === 'boolean') || Array.isArray(param)) {
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
      this.isVisible = getBoolOrFunctionResult(this.visible);
    }
    if (this.shouldCallTriggerFunctionFor(dirty, 'isDisabled')) {
      this.isDisabled = getBoolOrFunctionResult(this.disabled, false);
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
      if (((function() {
        switch (typeof value) {
          case 'number':
          case 'boolean':
            return false;
          case 'string':
            return value.length === 0;
          case 'object':
            return Object.keys(value).length === 0;
          default:
            return true;
        }
      })())) {
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
      if (isNaN(+value)) {
        return "Must be an integer or decimal number. (ex. 42 or 1.618)";
      }
    },
    date: function(value, format) {
      if (value == null) {
        value = this.value || '';
      }
      if (format == null) {
        format = this.format;
      }
      if (value === '') {
        return;
      }
      if (!moment(value, format, true).isValid()) {
        return "Not a valid date or does not match the format " + format;
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
    },
    template: function() {
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

  ModelBase.prototype.cloneModel = function(newRoot, constructor, excludeAttributes) {
    var childClone, filteredAttributes, i, key, len, modelObj, myClone, newVal, ref, ref1, val;
    if (newRoot == null) {
      newRoot = this.root;
    }
    if (constructor == null) {
      constructor = this.constructor;
    }
    if (excludeAttributes == null) {
      excludeAttributes = [];
    }
    filteredAttributes = {};
    ref = this.attributes;
    for (key in ref) {
      val = ref[key];
      if (indexOf.call(excludeAttributes, key) < 0) {
        filteredAttributes[key] = val;
      }
    }
    myClone = new constructor(filteredAttributes);
    ref1 = myClone.attributes;
    for (key in ref1) {
      val = ref1[key];
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
