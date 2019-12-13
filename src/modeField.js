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
    var ref, ref1;
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
    if ((ref = this.type) !== 'info' && ref !== 'text' && ref !== 'url' && ref !== 'email' && ref !== 'tel' && ref !== 'time' && ref !== 'date' && ref !== 'textarea' && ref !== 'bool' && ref !== 'tree' && ref !== 'color' && ref !== 'select' && ref !== 'multiselect' && ref !== 'image' && ref !== 'button' && ref !== 'number') {
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
      if (typeof ((ref1 = this.optionsFrom) != null ? ref1.url : void 0) === 'function') {
        this.optionsFrom.url = this.bindPropFunction('optionsFrom.url', this.optionsFrom.url);
      }
      if (typeof this.optionsFrom.parseResults !== 'function') {
        return globals.handleError('optionsFrom.parseResults must be a function');
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
          return globals.handleError(globals.makeErrorMessage(_this, 'optionsFrom', error));
        }
        mappedResults = _this.optionsFrom.parseResults(data);
        if (!Array.isArray(mappedResults)) {
          return globals.handleError('results of parseResults must be an array of option parameters');
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
    var newOption, nextOpts, opt, optionObject, optionParams;
    optionParams = 1 <= arguments.length ? slice.call(arguments, 0) : [];
    optionObject = this.buildParamObject(optionParams, ['title', 'value', 'selected']);
    this.ensureSelectType();
    nextOpts = (function() {
      var i, len, ref, results;
      ref = this.options;
      results = [];
      for (i = 0, len = ref.length; i < len; i++) {
        opt = ref[i];
        if (opt.title !== optionObject.title) {
          results.push(opt);
        }
      }
      return results;
    }).call(this);
    newOption = new ModelOption(optionObject);
    nextOpts.push(newOption);
    this.options = nextOpts;

    //if new option has selected:true, set this field's value to that
    //don't remove from parent value if not selected. Might be supplied by field value during creation.
    // Pass in bid Adjustment from string
  

    if (newOption.selected) {
      console.log("option value:",newOption.value)
      this.addOptionValue(newOption.value);
    }
    return this;
  };

  ModelField.prototype.postBuild = function() {
    this.defaultValue = this.value;
    return this.updateOptionsSelected();
  };

  ModelField.prototype.updateOptionsSelected = function() {
    var bidAdj, bidValue, i, len, opt, ref, ref1, result;
    ref = this.options;
    result = [];
      for (i = 0, len = ref.length; i < len; i++) {
        opt = ref[i];
        if ((ref1 = this.type) === 'multiselect' || ref1 === 'tree') {
          const bidValue = this.hasValue(opt.value);
          console.log("updateOptionsSelect bid Value", bidValue)
          if (bidValue.bidAdjValue) {
          bidAdj = bidValue.bidAdjValue.lastIndexOf('/') !== -1 ? bidValue.bidAdjValue.split('/')[1] : "+0%";
          opt.bidAdj = bidAdj
          console.log("updateOptionsSelect bid Adj",bidAdj)

          }
          result.push(opt.selected = bidValue.selectStatus);
        } else {
          result.push(opt.selected = this.hasValue(opt.value));
        }
      }
      return result;
    };


  ModelField.prototype.isSelectType = function() {
    var ref;
    return (ref = this.type) === 'select' || ref === 'multiselect' || ref === 'image' || ref === 'tree';
  };

  ModelField.prototype.ensureSelectType = function() {
    if (!this.isSelectType()) {
      return this.type = 'select';
    }
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
      if (this.template) {
        validityMessage || (validityMessage = this.validate.template.call(this));
      }
      if (this.type === 'number') {
        validityMessage || (validityMessage = this.validate.number.call(this));
      }
      if (!validityMessage) {
        ref = this.validators;
        for (i = 0, len = ref.length; i < len; i++) {
          validator = ref[i];
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
    ref1 = this.options;
    results = [];
    for (j = 0, len1 = ref1.length; j < len1; j++) {
      opt = ref1[j];
      results.push(opt.recalculateRelativeProperties());
    }
    return results;
  };

  ModelField.prototype.addOptionValue = function(val, bidAdj) {
    if (['multiselect','tree'].includes(this.type)) {
      console.log("addOption val:",val, "bidAdj:", bidAdj)
      if (!Array.isArray(this.value)) {
        this.value = [this.value];
      }
      const findMatch = this.value.findIndex(e => {
        console.log ("comparing findMatch:", e, val)
       return  ( e == val || e.search(val) !== -1 || e.match(val) )
      });
      console.log("addOption value findMatch",findMatch)
      if ((findMatch !== -1) && (bidAdj != null)) {
          return this.value[findMatch] = (val + "/" + bidAdj);
      } else {
        if (bidAdj != null) {
          console.log("no match found and PUSHING a bid")
          return this.value.push((val + "/" + bidAdj));
        } else { 
          console.log("no match found and not pushing a bid")
          return this.value.push(val);
        }
      }
    } else { //single-select
      return this.value = val;
    }
  };

  ModelField.prototype.removeOptionValue = function(val) {
    var ref;
    if ((ref = this.type) === 'multiselect' || ref === 'tree') {
      
        return this.value = this.value.filter(function(v) {
          return (v.search(val) == -1 || !v.match(val) )
        });
      
    } else if (this.value === val) {
      return this.value = '';
    }
  };

  ModelField.prototype.hasValue = function(val) {
    if (['multiselect','tree'].includes(this.type)) {
      const findMatch = this.value.findIndex(e => {
        console.log ("comparing findMatch:", e, val)
        
       return  ( e == val ||e.search(val) !== -1 || e.match(val) )
      });
      console.log("has value match:",findMatch)
      if (findMatch !== -1) {
        return {"bidAdjValue": this.value[findMatch],
              "selectStatus": true} ;
      } else {
        return {"selectStatus": false };
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
    var existingOption, i, j, k, len, len1, len2, o, ref, ref1, ref2, results, v;
    if (!this.isSelectType()) {
      return;
    }
    if (typeof this.value === 'string') {
      ref = this.options;
      for (i = 0, len = ref.length; i < len; i++) {
        o = ref[i];
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
      ref1 = this.value;
      results = [];
      for (j = 0, len1 = ref1.length; j < len1; j++) {
        v = ref1[j];
        existingOption = null;
        ref2 = this.options;
        for (k = 0, len2 = ref2.length; k < len2; k++) {
          o = ref2[k];
          if (o.value === v) {
            existingOption = o;
          }
        }
        if (!existingOption) {
          results.push(this.option(v, {
            selected: true
          }));
        } else {
          results.push(void 0);
        }
      }
      return results;
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
    var error1, template;
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
