var ModelField, ModelFieldDate, moment,
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty;

ModelField = require('./modelField');

moment = require('moment');

module.exports = ModelFieldDate = (function(superClass) {
  extend(ModelFieldDate, superClass);

  function ModelFieldDate() {
    return ModelFieldDate.__super__.constructor.apply(this, arguments);
  }

  ModelFieldDate.prototype.initialize = function() {
    this.setDefault('format', 'M/D/YYYY');
    ModelFieldDate.__super__.initialize.apply(this, arguments);
    return this.validator(this.validate.date);
  };

  ModelFieldDate.prototype.dateToString = function(date, format) {
    if (date == null) {
      date = this.value;
    }
    if (format == null) {
      format = this.format;
    }
    return moment(date).format(format);
  };

  ModelFieldDate.prototype.stringToDate = function(str, format) {
    if (str == null) {
      str = this.value;
    }
    if (format == null) {
      format = this.format;
    }
    return moment(str, format, true).toDate();
  };

  return ModelFieldDate;

})(ModelField);
