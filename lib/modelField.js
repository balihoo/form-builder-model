var ModelBase, ModelField, ModelOption, Mustache, globals, jiff,
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty,
  slice = [].slice,
  indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

ModelBase = require('./modelBase');

ModelOption = require('./modelOption');

globals = require('./globals');

Mustache = require('mustache');

jiff = require('jiff');


/*
  A ModelField represents a model object that render as a DOM field
  NOTE: The following field types are subclasses: image, tree, date
 */

module.exports = ModelField = (function(superClass) {
  extend(ModelField, superClass);

  function ModelField() {
    return ModelField.__super__.constructor.apply(this, arguments);
  }

  ModelField.prototype.modelClassName = 'ModelField';

  ModelField.prototype.initialize = function() {
    var ref2, ref3;
    this.setDefault('type', 'text');
    this.setDefault('options', []);
    this.setDefault('value', (function() {
      switch (this.get('type')) {
        case 'multiselect':
          return [];
        case 'bool':
          return false;
        case 'info':
        case 'button':
          return void 0;
        default:
          return (this.get('defaultValue')) || '';
      }
    }).call(this));
    this.setDefault('defaultValue', this.get('value'));
    this.set('isValid', true);
    this.setDefault('validators', []);
    this.setDefault('onChangeHandlers', []);
    this.setDefault('dynamicValue', null);
    this.setDefault('template', null);
    this.setDefault('autocomplete', null);
    this.setDefault('beforeInput', function(val) {
      return val;
    });
    this.setDefault('beforeOutput', function(val) {
      return val;
    });
    ModelField.__super__.initialize.apply(this, arguments);
    if ((ref2 = this.type) !== 'info' && ref2 !== 'text' && ref2 !== 'url' && ref2 !== 'email' && ref2 !== 'tel' && ref2 !== 'time' && ref2 !== 'date' && ref2 !== 'textarea' && ref2 !== 'bool' && ref2 !== 'tree' && ref2 !== 'color' && ref2 !== 'select' && ref2 !== 'multiselect' && ref2 !== 'image' && ref2 !== 'button' && ref2 !== 'number') {
      return globals.handleError("Bad field type: " + this.type);
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
      this.ensureSelectType();
      if ((this.optionsFrom.url == null) || (this.optionsFrom.parseResults == null)) {
        return globals.handleError('When fetching options remotely, both url and parseResults properties are required');
      }
      if (typeof ((ref3 = this.optionsFrom) != null ? ref3.url : void 0) === 'function') {
        this.optionsFrom.url = this.bindPropFunction('optionsFrom.url', this.optionsFrom.url);
      }
      if (typeof this.optionsFrom.parseResults !== 'function') {
        return globals.handleError('optionsFrom.parseResults must be a function');
      }
      this.optionsFrom.parseResults = this.bindPropFunction('optionsFrom.parseResults', this.optionsFrom.parseResults);
    }
    this.updateOptionsSelected();
    this.on('change:value', function() {
      var changeFunc, j, len1, ref4;
      ref4 = this.onChangeHandlers;
      for (j = 0, len1 = ref4.length; j < len1; j++) {
        changeFunc = ref4[j];
        changeFunc();
      }
      return this.updateOptionsSelected();
    });
    return this.on('change:type', function() {
      if (this.type === 'multiselect') {
        this.value = this.value.length > 0 ? [this.value] : [];
      } else if (this.previousAttributes().type === 'multiselect') {
        this.value = this.value.length > 0 ? this.value[0] : '';
      }
      if (this.options.length > 0 && !this.isSelectType()) {
        return this.type = 'select';
      }
    });
  };

  ModelField.prototype.getOptionsFrom = function() {
    var ref2, url;
    if (this.optionsFrom == null) {
      return;
    }
    url = typeof this.optionsFrom.url === 'function' ? this.optionsFrom.url() : this.optionsFrom.url;
    if (this.prevUrl === url) {
      return;
    }
    this.prevUrl = url;
    return typeof window !== "undefined" && window !== null ? (ref2 = window.formbuilderproxy) != null ? ref2.getFromProxy({
      url: url,
      method: this.optionsFrom.method || 'get',
      headerKey: this.optionsFrom.headerKey
    }, (function(_this) {
      return function(error, data) {
        var j, len1, mappedResults, opt, results1;
        if (error) {
          return globals.handleError(globals.makeErrorMessage(_this, 'optionsFrom', error));
        }
        mappedResults = _this.optionsFrom.parseResults(data);
        if (!Array.isArray(mappedResults)) {
          return globals.handleError('results of parseResults must be an array of option parameters');
        }
        _this.options = [];
        results1 = [];
        for (j = 0, len1 = mappedResults.length; j < len1; j++) {
          opt = mappedResults[j];
          results1.push(_this.option(opt));
        }
        return results1;
      };
    })(this)) : void 0 : void 0;
  };

  ModelField.prototype.validityMessage = void 0;

  ModelField.prototype.field = function() {
    var obj, ref2;
    obj = 1 <= arguments.length ? slice.call(arguments, 0) : [];
    return (ref2 = this.parent).field.apply(ref2, obj);
  };

  ModelField.prototype.group = function() {
    var obj, ref2;
    obj = 1 <= arguments.length ? slice.call(arguments, 0) : [];
    return (ref2 = this.parent).group.apply(ref2, obj);
  };

  ModelField.prototype.option = function() {
    var newOption, nextOpts, opt, optionObject, optionParams;
    optionParams = 1 <= arguments.length ? slice.call(arguments, 0) : [];
    optionObject = this.buildParamObject(optionParams, ['title', 'value', 'selected', 'bidAdj', 'bidAdjFlag']);
    this.ensureSelectType();
    nextOpts = (function() {
      var j, len1, ref2, results1;
      ref2 = this.options;
      results1 = [];
      for (j = 0, len1 = ref2.length; j < len1; j++) {
        opt = ref2[j];
        if (opt.title !== optionObject.title) {
          results1.push(opt);
        }
      }
      return results1;
    }).call(this);
    newOption = new ModelOption(optionObject);
    nextOpts.push(newOption);
    this.options = nextOpts;
    if (newOption.selected) {
      this.addOptionValue(newOption.value);
    }
    return this;
  };

  ModelField.prototype.postBuild = function() {
    this.defaultValue = this.value;
    return this.updateOptionsSelected();
  };

  ModelField.prototype.updateOptionsSelected = function() {
    var bid, i, j, len, len1, opt, ref, ref1, ref2, results, results1;
    if ((ref1 = this.type) === 'multiselect') {
      ref = this.options;
      results = [];
      i = 0;
      len = ref.length;
      while (i < len) {
        opt = ref[i];
        bid = this.hasValue(opt.value, opt.bidAdjFlag);
        if (opt.bidAdjFlag) {
          if (bid.bidValue && typeof bid.bidValue === 'string') {
            opt.bidAdj = bid.bidValue.lastIndexOf('/') !== -1 ? bid.bidValue.split("/").pop() : this.bidAdj;
          }
          results.push(opt.selected = bid.selectStatus);
        } else {
          results.push(opt.selected = bid);
        }
        i++;
      }
      return results;
    } else if ((ref1 = this.type) === 'tree') {
      ref2 = this.options;
      results1 = [];
      for (j = 0, len1 = ref2.length; j < len1; j++) {
        opt = ref2[j];
        results1.push(opt.selected = this.hasValue(opt.value));
      }
      return results1;
    }
  };

  ModelField.prototype.isSelectType = function() {
    var ref2;
    return (ref2 = this.type) === 'select' || ref2 === 'multiselect' || ref2 === 'image' || ref2 === 'tree';
  };

  ModelField.prototype.ensureSelectType = function() {
    if (!this.isSelectType()) {
      return this.type = 'select';
    }
  };

  ModelField.prototype.child = function(value) {
    var j, len1, o, ref2;
    if (Array.isArray(value)) {
      value = value.shift();
    }
    ref2 = this.options;
    for (j = 0, len1 = ref2.length; j < len1; j++) {
      o = ref2[j];
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
    var j, len1, opt, ref2;
    ref2 = this.options;
    for (j = 0, len1 = ref2.length; j < len1; j++) {
      opt = ref2[j];
      opt.setDirty(id, whatChanged);
    }
    return ModelField.__super__.setDirty.call(this, id, whatChanged);
  };

  ModelField.prototype.setClean = function(all) {
    var j, len1, opt, ref2, results1;
    ModelField.__super__.setClean.apply(this, arguments);
    if (all) {
      ref2 = this.options;
      results1 = [];
      for (j = 0, len1 = ref2.length; j < len1; j++) {
        opt = ref2[j];
        results1.push(opt.setClean(all));
      }
      return results1;
    }
  };

  ModelField.prototype.recalculateRelativeProperties = function() {
    var dirty, j, k, len1, len2, opt, ref2, ref3, results1, validator, validityMessage, value;
    dirty = this.dirty;
    ModelField.__super__.recalculateRelativeProperties.apply(this, arguments);
    if (this.shouldCallTriggerFunctionFor(dirty, 'isValid')) {
      validityMessage = void 0;
      if (this.template) {
        validityMessage || (validityMessage = this.validate.template.call(this));
      }
      if (this.type === 'number') {
        validityMessage || (validityMessage = this.validate.number.call(this));
      }
      if (!validityMessage) {
        ref2 = this.validators;
        for (j = 0, len1 = ref2.length; j < len1; j++) {
          validator = ref2[j];
          if (typeof validator === 'function') {
            validityMessage = validator.call(this);
          }
          if (typeof validityMessage === 'function') {
            return globals.handleError("A validator on field '" + this.name + "' returned a function");
          }
          if (validityMessage) {
            break;
          }
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
          return globals.handleError("dynamicValue on field '" + this.name + "' returned a function");
        }
        this.set('value', value);
      }
    }
    if (this.shouldCallTriggerFunctionFor(dirty, 'options')) {
      this.getOptionsFrom();
    }
    ref3 = this.options;
    results1 = [];
    for (k = 0, len2 = ref3.length; k < len2; k++) {
      opt = ref3[k];
      results1.push(opt.recalculateRelativeProperties());
    }
    return results1;
  };

  ModelField.prototype.addOptionValue = function(val, bidAdj, bidAdjFlag) {
    var findMatch, ref;
    findMatch = void 0;
    ref = void 0;
    if ((ref = this.type) === 'multiselect' || ref === 'tree') {
      if (bidAdjFlag) {
        if (!Array.isArray(this.value)) {
          this.value = [this.value];
        }
        findMatch = this.value.findIndex(function(e) {
          return e === val;
        });
        if (findMatch !== -1) {
          if (bidAdj) {
            return this.value[findMatch] = val + '/' + bidAdj;
          }
        } else {
          if (bidAdj) {
            return this.value.push(val + '/' + bidAdj);
          } else {
            return this.value.push(val);
          }
        }
      } else {
        if (!Array.isArray(this.value)) {
          this.value = [this.value];
        }
        if (!(indexOf.call(this.value, val) >= 0)) {
          this.value.push(val);
        }
      }
    } else {
      return this.value = val;
    }
  };

  ModelField.prototype.removeOptionValue = function(val, bidAdjFlag) {
    var ref;
    ref = void 0;
    if ((ref = this.type) === 'multiselect' || ref === 'tree') {
      if (bidAdjFlag) {
        return this.value = this.value.filter(function(e) {
          if (typeof e === 'string') {
            e = e.lastIndexOf('/') !== -1 ? e.split("/").shift() : e;
          }
          return e !== val;
        });
      } else {
        if (indexOf.call(this.value, val) >= 0) {
          this.value = this.value.filter(function(v) {
            return v !== val;
          });
        }
      }
    } else if (this.value === val) {
      return this.value = '';
    }
  };

  ModelField.prototype.hasValue = function(val, bidAdjFlag) {
    var findMatch, ref;
    findMatch = void 0;
    ref = void 0;
    if ((ref = this.type) === 'multiselect' || ref === 'tree') {
      if (bidAdjFlag) {
        findMatch = this.value.findIndex(function(e) {
          if (typeof e === 'string') {
            e = e.lastIndexOf('/') !== -1 ? e.split("/").shift() : e;
          }
          return e === val;
        });
        if (findMatch !== -1) {
          return {
            'bidValue': this.value[findMatch],
            'selectStatus': true
          };
        } else {
          return {
            'selectStatus': false
          };
        }
      } else {
        return indexOf.call(this.value, val) >= 0;
      }
    } else {
      return val === this.value;
    }
  };

  ModelField.prototype.buildOutputData = function(_, skipBeforeOutput) {
    var out, value;
    value = (function() {
      switch (this.type) {
        case 'number':
          out = +this.value;
          if (isNaN(out)) {
            return null;
          } else {
            return out;
          }
          break;
        case 'info':
        case 'button':
          return void 0;
        case 'bool':
          return !!this.value;
        default:
          return this.value;
      }
    }).call(this);
    if (skipBeforeOutput) {
      return value;
    } else {
      return this.beforeOutput(value);
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
    var existingOption, j, k, l, len1, len2, len3, o, optValue, ref2, ref3, ref4, results1, v;
    if (!this.isSelectType()) {
      return;
    }
    if (typeof this.value === 'string') {
      ref2 = this.options;
      for (j = 0, len1 = ref2.length; j < len1; j++) {
        o = ref2[j];
        if (o.value === this.value) {
          existingOption = o;
        }
      }
      if (!existingOption) {
        return this.option(this.value, {
          selected: true
        });
      }
    } else if (Array.isArray(this.value)) {
      ref3 = this.value;
      results1 = [];
      for (k = 0, len2 = ref3.length; k < len2; k++) {
        v = ref3[k];
        existingOption = null;
        ref4 = this.options;
        for (l = 0, len3 = ref4.length; l < len3; l++) {
          o = ref4[l];
          optValue = v;
          if (o.bidAdjFlag) {
            optValue = v.lastIndexOf('/') !== -1 ? v.split("/").shift() : v;
          }
          if (o.value === optValue) {
            existingOption = o;
          }
        }
        if (!existingOption) {
          results1.push(this.option(v, {
            selected: true
          }));
        } else {
          results1.push(void 0);
        }
      }
      return results1;
    }
  };

  ModelField.prototype.applyData = function(inData, clear, purgeDefaults) {
    if (clear == null) {
      clear = false;
    }
    if (purgeDefaults == null) {
      purgeDefaults = false;
    }
    if (clear) {
      this.clear(purgeDefaults);
    }
    if (inData != null) {
      this.value = this.beforeInput(jiff.clone(inData));
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
    try {
      return this.value = Mustache.render(template, this.root.data);
    } catch (error1) {

    }
  };

  return ModelField;

})(ModelBase);
