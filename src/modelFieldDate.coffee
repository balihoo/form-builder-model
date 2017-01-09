ModelField = require './modelField'
moment = require 'moment'

module.exports = class ModelFieldDate extends ModelField
  initialize: ->
    @setDefault 'format', 'M/D/YYYY'
    super
    @validator @validate.date

  # Convert date to string according to this format
  dateToString: (date = @value, format = @format) ->
    moment(date).format format
  # Convert string in this format to a date. Could be an invalid date.
  stringToDate: (str = @value, format = @format) ->
    moment(str, format, true).toDate()