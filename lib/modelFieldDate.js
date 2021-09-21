var ModelField, ModelFieldDate, moment;

ModelField = require('./modelField');

moment = require('moment');

module.exports = ModelFieldDate = class ModelFieldDate extends ModelField {
  initialize() {
    this.setDefault('format', 'M/D/YYYY');
    super.initialize({
      objectMode: true
    });
    return this.validator(this.validate.date);
  }

  // Convert date to string according to this format
  dateToString(date = this.value, format = this.format) {
    return moment(date).format(format);
  }

  // Convert string in this format to a date. Could be an invalid date.
  stringToDate(str = this.value, format = this.format) {
    return moment(str, format, true).toDate();
  }

};
