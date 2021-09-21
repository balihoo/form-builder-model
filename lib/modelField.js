var ModelBase, ModelField, ModelOption, Mustache, globals, jiff;

ModelBase = require('./modelBase');

ModelOption = require('./modelOption');

globals = require('./globals');

Mustache = require('mustache');

jiff = require('jiff');

/*
  A ModelField represents a model object that render as a DOM field
  NOTE: The following field types are subclasses: image, tree, date
*/
module.exports = ModelField = (function() {
  class ModelField extends ModelBase {
    initialize() {
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
      this.setDefault('defaultValue', this.get('value')); //used for control type and clear()
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
      super.initialize({
        objectMode: true
      });
      //difficult to catch bad types at render time.  error here instead
      if ((ref2 = this.type) !== 'info' && ref2 !== 'text' && ref2 !== 'url' && ref2 !== 'email' && ref2 !== 'tel' && ref2 !== 'time' && ref2 !== 'date' && ref2 !== 'textarea' && ref2 !== 'bool' && ref2 !== 'tree' && ref2 !== 'color' && ref2 !== 'select' && ref2 !== 'multiselect' && ref2 !== 'image' && ref2 !== 'button' && ref2 !== 'number') {
        return globals.handleError(`Bad field type: ${this.type}`);
      }
      this.bindPropFunctions('dynamicValue');
      // multiselects are arrays, others are strings.  If typeof value doesn't match, convert it.
      while ((Array.isArray(this.value)) && (this.type !== 'multiselect') && (this.type !== 'tree') && (this.type !== 'button')) {
        this.value = this.value[0];
      }
      if (typeof this.value === 'string' && (this.type === 'multiselect')) {
        this.value = [this.value];
      }
      //bools are special too.
      if (this.type === 'bool' && typeof this.value !== 'bool') {
        this.value = !!this.value; //convert to bool
      }
      this.makePropArray('validators');
      this.bindPropFunctions('validators');
      //onChangeHandlers functions for field value changes only.  For any property change, use onChangePropertiesHandlers
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
      // if type changes, need to update value
      return this.on('change:type', function() {
        if (this.type === 'multiselect') {
          this.value = this.value.length > 0 ? [this.value] : [];
        } else if (this.previousAttributes().type === 'multiselect') {
          this.value = this.value.length > 0 ? this.value[0] : '';
        }
        // must be *select if options present
        if (this.options.length > 0 && !this.isSelectType()) {
          return this.type = 'select';
        }
      });
    }

    getOptionsFrom() {
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
      }, (error, data) => {
        var j, len1, mappedResults, opt, results1;
        if (error) {
          return globals.handleError(globals.makeErrorMessage(this, 'optionsFrom', error));
        }
        mappedResults = this.optionsFrom.parseResults(data);
        if (!Array.isArray(mappedResults)) {
          return globals.handleError('results of parseResults must be an array of option parameters');
        }
        this.options = [];
        results1 = [];
        for (j = 0, len1 = mappedResults.length; j < len1; j++) {
          opt = mappedResults[j];
          results1.push(this.option(opt));
        }
        return results1;
      }) : void 0 : void 0;
    }

    field(...obj) {
      return this.parent.field(...obj);
    }

    group(...obj) {
      return this.parent.group(...obj);
    }

    option(...optionParams) {
      var newOption, nextOpts, opt, optionObject;
      optionObject = this.buildParamObject(optionParams, ['title', 'value', 'selected', 'bidAdj', 'bidAdjFlag']);
      // when adding an option to a field, make sure it is a *select type
      this.ensureSelectType();
      // If this option already exists, replace.  Otherwise append
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
      //if new option has selected:true, set this field's value to that
      //don't remove from parent value if not selected. Might be supplied by field value during creation.
      if (newOption.selected) {
        this.addOptionValue(newOption.value);
      }
      return this;
    }

    postBuild() {
      // options may have changed the starting value, so update the defaultValue to that
      this.defaultValue = this.value; //todo: NO! need to clone this in case value isnt primitive
      //update each option's selected status to match the field value
      return this.updateOptionsSelected();
    }

    updateOptionsSelected() {
      var bid, i, len, opt, ref, ref1, results;
      ref = this.options;
      results = [];
      i = 0;
      len = ref.length;
      while (i < len) {
        opt = ref[i];
        if ((ref1 = this.type) === 'multiselect' || ref1 === 'tree') {
          bid = this.hasValue(opt.value);
          if (bid.bidValue) {
            opt.bidAdj = bid.bidValue.lastIndexOf('/') !== -1 ? bid.bidValue.split("/").pop() : this.bidAdj;
          }
          results.push(opt.selected = bid.selectStatus);
        } else {
          results.push(opt.selected = this.hasValue(opt.value));
        }
        i++;
      }
      return results;
    }

    // returns true if this type is one where a value is selected. Otherwise false
    isSelectType() {
      var ref2;
      return (ref2 = this.type) === 'select' || ref2 === 'multiselect' || ref2 === 'image' || ref2 === 'tree';
    }

    // certain operations require one of the select types.  If its not already, change field type to select
    ensureSelectType() {
      if (!this.isSelectType()) {
        return this.type = 'select';
      }
    }

    // find an option by value.  Uses the same child method as groups and fields to find constituent objects
    child(value) {
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
    }

    // add a new validator function
    validator(func) {
      this.validators.push(this.bindPropFunction('validator', func));
      this.trigger('change');
      return this;
    }

    // add a new onChangeHandler function that triggers when the field's value changes
    onChange(f) {
      this.onChangeHandlers.push(this.bindPropFunction('onChange', f));
      this.trigger('change');
      return this;
    }

    setDirty(id, whatChanged) {
      var j, len1, opt, ref2;
      ref2 = this.options;
      for (j = 0, len1 = ref2.length; j < len1; j++) {
        opt = ref2[j];
        opt.setDirty(id, whatChanged);
      }
      return super.setDirty(id, whatChanged);
    }

    setClean(all) {
      var j, len1, opt, ref2, results1;
      super.setClean({
        objectMode: true
      });
      if (all) {
        ref2 = this.options;
        results1 = [];
        for (j = 0, len1 = ref2.length; j < len1; j++) {
          opt = ref2[j];
          results1.push(opt.setClean(all));
        }
        return results1;
      }
    }

    recalculateRelativeProperties() {
      var dirty, j, k, len1, len2, opt, ref2, ref3, results1, validator, validityMessage, value;
      dirty = this.dirty;
      super.recalculateRelativeProperties({
        objectMode: true
      });
      // validity
      // only fire if isValid changes.  If isValid stays false but message changes, don't need to re-fire.
      if (this.shouldCallTriggerFunctionFor(dirty, 'isValid')) {
        validityMessage = void 0;
        //certain validators are automatic on fields with certain properties
        if (this.template) {
          validityMessage || (validityMessage = this.validate.template.call(this));
        }
        if (this.type === 'number') {
          validityMessage || (validityMessage = this.validate.number.call(this));
        }
        //if no problems yet, try all the user-defined validators
        if (!validityMessage) {
          ref2 = this.validators;
          for (j = 0, len1 = ref2.length; j < len1; j++) {
            validator = ref2[j];
            if (typeof validator === 'function') {
              validityMessage = validator.call(this);
            }
            if (typeof validityMessage === 'function') {
              return globals.handleError(`A validator on field '${this.name}' returned a function`);
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
      // Fields with a template property can't also have a dynamicValue property.
      if (this.template && this.shouldCallTriggerFunctionFor(dirty, 'value')) {
        this.renderTemplate();
      } else {
        //dynamic value
        if (typeof this.dynamicValue === 'function' && this.shouldCallTriggerFunctionFor(dirty, 'value')) {
          value = this.dynamicValue();
          if (typeof value === 'function') {
            return globals.handleError(`dynamicValue on field '${this.name}' returned a function`);
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
    }

    addOptionValue(val, bidAdj) {
      var findMatch, ref;
      findMatch = void 0;
      ref = void 0;
      if ((ref = this.type) === 'multiselect' || ref === 'tree') {
        if (!Array.isArray(this.value)) {
          this.value = [this.value];
        }
        findMatch = this.value.findIndex(function(e) {
          if (typeof e === 'string') {
            return e.search(val) !== -1;
          } else {
            return e === val;
          }
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
        return this.value = val;
      }
    }

    removeOptionValue(val) {
      var ref;
      ref = void 0;
      if ((ref = this.type) === 'multiselect' || ref === 'tree') {
        return this.value = this.value.filter(function(e) {
          if (typeof e === 'string') {
            return e.search(val) === -1;
          } else {
            return e !== val;
          }
        });
      } else if (this.value === val) {
        return this.value = '';
      }
    }

    hasValue(val) {
      var findMatch, ref;
      findMatch = void 0;
      ref = void 0;
      if ((ref = this.type) === 'multiselect' || ref === 'tree') {
        findMatch = this.value.findIndex(function(e) {
          if (typeof e === 'string') {
            return e.search(val) !== -1;
          } else {
            return e === val;
          }
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
        return val === this.value;
      }
    }

    buildOutputData(_, skipBeforeOutput) {
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
    }

    clear(purgeDefaults = false) {
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
    }

    ensureValueInOptions() {
      var existingOption, j, k, l, len1, len2, len3, o, ref2, ref3, ref4, results1, v;
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
            if (o.value === v) {
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
    }

    applyData(inData, clear = false, purgeDefaults = false) {
      if (clear) {
        this.clear(purgeDefaults);
      }
      if (inData != null) {
        return this.value = this.beforeInput(jiff.clone(inData));
      }
    }

    //HUB-2766 this is no longer necessary as we now have biding changing option
    //@ensureValueInOptions()
    renderTemplate() {
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
    }

  };

  ModelField.prototype.modelClassName = 'ModelField';

  ModelField.prototype.validityMessage = void 0;

  return ModelField;

}).call(this);
