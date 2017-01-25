ModelBase = require './modelBase'

module.exports = class ModelOption extends ModelBase
  initialize: ->
    @setDefault 'value', @get 'title'
    # No two options on a field should have the same title.  This would be confusing during render.
    # Even if not rendered, title can be used as primary key to determine when duplicate options should be avoided.
    @setDefault 'title', @get 'value'
    # selected is used to set default value and also to store current value.
    @setDefault 'selected', false
    @setDefault 'path', [] #for tree. Might should move to subclass
    super

    # if selected is changed, make sure parent matches
    # this change likely comes from parent value changing, so be careful not to infinitely recurse.
    @on 'change:selected', ->
      if @selected
        @parent.addOptionValue @value
      else # not selected
        @parent.removeOptionValue @value