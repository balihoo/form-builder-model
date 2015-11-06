# Model Code

Model code is written in [CoffeeScript](http://coffeescript.org/) and includes extensions to create fields and supporting properties.

## Quick Links
* How do I create a [field of type X](#fieldtypes)?
* [What stuff](#referenceable) can I include in my [dynamicValue](#dynamicValue) function (or other dynamic function)?

# General Use
Form objects are most easily created by calling the desired function and passing named properties for that object.  For example

    field title:'This is a Demo', name:'demo', type:'text', value:'initialValue'
    
Some functions allow parameters to be supplied in the right order rather than labeling each propery.  For example, the following is equivalent to the previous example.

    field 'This is a Demo', 'demo', 'text', 'initialValue'
    
Such defaults will be described where available.


# Fields
Fields represent some input that will be present in the output of the form.

## Field Properties
* **name** *string* - The name of this field as it will appear in the input and output JSON.
* **title** *string* - Text to display next to this field. Default: same as name.
* **value** - The current value of the field which will appear in the form output.  Setting this when creating a field will set its default value.  The data type depends on the field type.
* <a name="dynamicValue"></a> **dynamicValue** *function* - Allows you to set the value of this field based on other form properties.  This will overwrite the field's value when computed.


	field 'name'
	field 'greeting', dynamicValue: ->
	  "Hello there " + @root.child('name').value
* <a name="fieldVisible"></a> **visible** *function or bool* - Everything is visible:true by default. Set visible to false for invisible, or a function that returns a boolean for conditional visibility. Whether or not an object is currently visible is stored in the isVisible property.
* **validators** *array of functions* - These can be set when creating a field or added to a field one at a time with the `.validator` function.  Validator functions return an error message if the field is not valid, otherwise something falsy.


    field 'a', validators: [validate.required, validate.minLength 3]
    field 'b'
      .validator validate.required
      .validator validate.minLength 3
      .validator ->
        if @value isnt "happy"
          'Value can only be "happy"!'
        
      
* **onChangeHandlers** *array of functions* - Functions to call any time this field's value changes.  Useful for having this change trigger some specific action elsewhere.  Unlike other dynamic functions, these are only called when this field's value changes, not whenever anything anywhere changes.  Can also be appended to with the `.onChange()` function.
      
# Field Functions
Call these functions to alter a current field in some way.

* **option()** - Appends a new Option to the field.

    Options on select and multiselect fields could have the following properties
  
    * **title** - Display text for this option. Default: same as value. At least one of title or value is required.
    * **value** - The value the field should have if this option is selected. Default: same as title. At least one of title or value is required.
    * **selected** *bool* - Set to true for an option to be selected by default.  Default:false
    * **visible** *bool or function* - Works mostly the same as [on a field](#fieldVisible), except that options on fields of type image or tree may not be set to invisible.  This is due their complex rendering which makes it difficult for options to come and go.
    
    Image options have different properties, see below.
* **validator()** - Appends a new validation function to the field. 
* **onChange()** - Appends a new function to run when the field's value changes.


## <a name='fieldtypes'></a>Field Types
There are many types of fields that can be created.  The default is 'text', but any other may be supplied when creating a field.  If a certain type allows extra properties, those are displayed under that type.


* **text** - A simple, one-line input box for text.
* **textarea** - Multi-line text entry.
* **bool** - A check box whose value is true (checked) or false (unchecked)
* **select** - The user selects from one of many options.  These options may be displayed in different ways based on some properties of the field.  Select is the default type when a field has any options.
* **multiselect** - The same as select except the user may select more than one option.
* **image** - The user selects an image from available choices or optionally can upload their own image.  
    * **allowUpload** *bool* - Set to true to allow users to upload their own local images.  Default: false.
    * **companyID** *int or string** - Uploaded images must belong to a certain company in Marketer.  If allowUpload is true, this property is required.
    * **imagesPerPage** *int* - Number of images to show on each page of the image carousel.  Default: 4
    
    The options of an image field are not a simple title and value, but rather an object containing image properties.
    
    * **fileID** *int* - The file ID, usually used to reference the file ID in Marketer.
    * **fileUrl** *string* - The hosted location of the full sized image, which will be used when fulfilling this form.
    * **thumbnailUrl** *string* - Optional thumbnail to speed up the image picker control. Default: same as fileUrl.  This url must be accessible by those viewing the form!
    
    Options on an image field must always be visible; you can't set visible:false or visible:function that returns false like on other field types.
    
* **tree** - represents a hierarchy of options.  The user expands categories to find options to move into a separate selection pane.

    Options on tree field must always be visible; you can't set visible:false or visible:function that returns false like on other field types.
* **color** - The user selects a color using a color picker.
* **info** - This pseudo-field doesn't allow any input or output, but can be used to display its title property as instructions to the user.
* **time** - Select a time of day including optional timezone.
    * **timezones** *array of string* - Time fields may optionally include a timezone, chosen from a list provided with this property.
* **date** - Select a date.


# Groups
Groups are used to contain other form objects, including fields and other groups.  In this way, a hierarchical form may be created that generates a full JSON output that can match a required structure.  Groups will also serve to visually segregate sections of a form.

## Group Properties

* **name** *string* - The name of this group as it will appear in the input and output JSON.  This will be the key whose value is an object containing all of its children.
* **title** *string* - Text to display for this group. Default: same as name.
* **visible** *bool or function* - Works the same as [on a field](#fieldVisible)
* **display** *string* - The only possible value to set is "inline", which displays all of its fields in a row instead of one on each row.
* **repeating** *bool* - Makes this group a [Repeating Group](#repeatingGroups), see that section for details.  Default:false

## Group Functions

# <a name="repeatingGroups"></a>Repeating Groups
Repeating groups are like a cross between Groups and Fields.  Like a group, they contain children which can be any combination of fields and subgroups.  Unlike a group however, these chidren only serve as a template for each section that should be added when the plus button is pressed.  Repeating groups, like Fields, have a value, which is an array of all the repeated sections added to the group and their values.
   
## Repeating Group Properties
The only difference between creating a regular group and a repeating group is the presense of the repeating property, which is set to true.


    group 'repeater', repeating:true
      .field 'first', value:1
      .field 'second', value:2

## Repeating Group Functions
* **add** - Adds a new copy of the repeating group prototype to this value.
* **delete(index)** - Deletes an instance of the repeating group from the value.

These functions are usually only called by pressing the groups buttons in the UI, but can be useful for setting up initial state.


    r = group name:'repeater', title:'Choose 3 things', repeating:true
      .field 'thing', value:1
      
    r.add()
    r.add()
    r.add()
    
    r.value         # [{thing:1},{thing:1},{thing:1}]


# Dynamic Functions
Some properties can be set as functions that allow you to have a form's state depend on other parts of the form.  For example, one set of options may be visible only if they make sense based on the value in another field.

Each field will have its context set to the current object.  In other words, when a function attached to a field or group runs, it can reference itself with this (or @)

It is important to note that these functions are run very often, usually when anything at all on the form changes.  A well behaved form will have functions that

* Always return the same value given the same input.
* Don't have any side effects.  Only return what is intended, don't directly alter anything else or your form will likely freeze.
* Run quickly.  If they take too long, the form can get slow and sluggish.

* **onChangePropertiesHandlers** *array of functions* - Can be set when creating an object or added one at a time with the `.onChangeProperties` function.


    field 'a', onChangePropertiesHandlers:[-> console.log "something changed in #{@title}!"]
    

## <a name="referenceable"></a>Referenceable Properties
Any property that is possible to set on a field or group can be referenced later by dynamic functions.  There are also some properties that cannot  or should not be directly set, but might be useful to read later.

* **isVisible** *bool* - true if the object is currently visible, false if invisible
* **parent** *Group or Field* - link to the form object that contains this one.  Every object has a parent except for the root.
* **defaultValue** - Fields will know what the default value was, even if changed later.
* **options** *array of Option objects* - Contains all options on the current field.  Note this is an Option object, not a simple string.
* **isValid** *bool* - The total validity state of this portion of the form.

    Fields are valid if they pass all of their validators functions.
  
    Groups are valid if each field that they contain recursively is valid. So the whole form is valid if the root group's isValid property is true.
* **validityMessage** *string* - If the Field is currently failing a validation, this is the message returned by that function. Note that a Field may fail several functions, this will contain the message from only the first failure.
* **children** *array of group/field* - Groups have a list of all the groups and/or fields created directly within them.
* **child()** - The child function allows you to drill down into child properties by name.  It can be used to find a child one level down at a time, or multiple levels my separating each level with a dot.  Fields have options instead of children, and although they don't have a name property they can be found by value.


    group 'level1'
      .group 'level2'
        .field 'a', value:'stuff'
        .field 'b', value:'things'
        
    root.child('level1').child('level2').child('a').value    # stuff
    root.child('level1.level2.b').value                      # things
    
    field 'c'
        .option title:'first', value:'1'
    
    console.log root.child('c.1').title                      # first

## Globals

These are avaiable from any context, including dynamic functions

* **root** *Group* - The topmost group that contains all your stuff.
* **validate** *object* - This object contains many common validation functions which can be referenced by name.
    * **required** - the field must have some value or selection
    * **minLength(num)** - the length of the value is at least num
    * **maxLength(num)** - the length of the value is at most num
    * **email** - the value looks like a valid email address
    * **url** - the value looks like a valid url
    * **dollars** - the value is formatted in USD.  Starts with a $ and has reasonable digits.
    * **minSelections(num)** - the minimum number of selections on a multiselect field.
    * **maxSelections(num)** - the maximum number of selections on a multiselect field.
    * **selectedIsVisible** - for select and multiselect fields, ensures the selected option is currently visible.
* **Mustache** *object* - [Mustache](https://github.com/balihoo-anewman/mustache.js) is available for filling in placeholders.
* **_** *object* - The [underscore](http://underscore.org) library is available. 
    
# Testing

