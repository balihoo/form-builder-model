# Model Code

Model code is written in [CoffeeScript](http://coffeescript.org/) and includes extensions to create fields and supporting properties.

# Disclaimer

Each of these features was written for a specific use case but we try to guess at general uses and allow those.  We have tests that ensure our specific use cases work, but if you try to do something crazy it may not work. Talk with a developer if you need help hacking or establishing where the boundaries are.

There are also things in the plumbing of model code that may be accessible but are not documented here.  Anything not in this document may be changed at any time in a way that breaks your form.  Don't use undocumented features.

## Quick Links
* How do I create a [field of type X](#fieldtypes)?
* [What stuff](#referenceable) can I include in my [dynamicValue](#dynamicValue) function (or other dynamic function)?

# General Use
Form objects are most easily created by calling the desired function and passing named properties for that object.  For example

```coffeescript
field title:'This is a Demo', name:'demo', type:'text', value:'initialValue'
```
Some functions allow parameters to be supplied in the right order rather than labeling each propery.  For example, the following is equivalent to the previous example.

```coffeescript
field 'This is a Demo', 'demo', 'text', 'initialValue'
```    
Such positional parameters will be described where available.

It is important to differentiate between Properties which are supplied when the object is created and Functions, which can be called on an object after it is created.

# Fields<a name="fields"></a>
Fields represent some input that will be present in the output of the form.  

Fields are created with the `field()` function with default positional parameters title, name, type, value

```coffeescript
field title:'First Name', name:'fname'
field title:'Last Name', name:'lname'
```

Don't create two fields with the same name in the same place, as this wouldn't result in valid JSON.

```coffeescript
field 'foo'
field 'foo' #not okay, this field will be ignored.
group 'bar'
    .field 'foo' #okay, different spot in JSON
```
## Field Properties
* **title** *string* - Text to display next to this field. Default: same as name.
* **name** *string* - The name of this field as it will appear in the input and output JSON.
* **type** *string* - The display type of the field.  Default is 'text'.  See [field types](#fieldtypes).
* **value** - The current value of the field which will appear in the form output.  Setting this when creating a field will set its default value.  The data type depends on the field type.
* **description** *string* - Adds a description directly below a field's input. This is preferred over creating a field of type 'info' for instructions because info fields do not appear directly adjacent to the field they describe.
* **dynamicValue** *function* <a name="dynamicValue"></a>- Allows you to set the value of this field based on other form properties.  This will overwrite the field's value when computed.

```coffeescript
field 'name'
field 'greeting', dynamicValue: ->
  "Hello there " + @root.child('name').value
```
* **visible** *function or bool* <a name="fieldVisible"></a>- Everything is visible:true by default. Set visible to false for invisible, or a function that returns a boolean for conditional visibility. Whether or not an object is currently visible is stored in the isVisible property.

```coffeescript
field 'lookHere'                            #defalt visible is true
field 'dontLookHere', visible: false        #never visible, but will appear in the output data
field 'maybeLookHere', visible: ->
  root.child('lookHere').value is 'maybe'   #visible if the value of the first field is 'maybe'
```
* **validators** *array of functions* - These can be set when creating a field or added to a field one at a time with the `.validator` function.  Validator functions return an error message if the field is not valid, otherwise something falsy.

```coffeescript
field 'a', validators: [validate.required, validate.minLength 3]
field 'b'
  .validator validate.required
  .validator validate.minLength 3
  .validator ->
    if @value isnt "happy"
      'Value can only be "happy"!'
```
* **onChangeHandlers** *array of functions* - Functions to call any time this field's value changes.  Useful for having this change trigger some specific action elsewhere.  Unlike other dynamic functions, these are only called when this field's value changes, not whenever anything anywhere changes.  Can also be appended to with the `.onChange()` function.
* **onChangePropertiesHandlers** *array of functions* <a name="onChangePropertiesHandlers"></a>- Functions to call any time ANY property changes on this field.  Can also be appended to with the `.onChangeProperties()` function.
* **optionsFrom** *object* - Allows a field to fetch options from a remote url.  optionsFrom is an object that contains the following
    * **url** *string or function* - The url to fetch.  Can be a static string or a function that returns a string.  Requests to this url are cached across all fields, and thus must not depend on any resulting fields that may change for the same request such as timestamp.
    * **headerKey** *string* - Optionally attach headers that may be required on the remote resource, such as headers.  Headers are stored on the form builder server, are referenced by headerKey, and have access limited by user brands.  These keys can currently only be added or maintained by filing a story with product.
    * **parseResults** *function* - parseResults is a function that takes the results from the remote url and returns an array of option parameters.  That is, each entry in the resulting array should be either a string for title and value, or an object that includes title, value, selected.

    It is important to note that this parseResult function is only called each time the url changes. This would be important if the results depend on the value of some other field.  Changes to that field would trigger the optionsFrom to be reevaluated, but if the url doesn't change then the parseResults will NOT be called and the same options will remain.
    
    As with other options, don't return two entries that would have the same value.
```coffeescript
urlPart = field 'Url Part'
.option 'thing1', selected:true
.option 'thing2'
.option 'thing3'

field 'Getting Options Remotely', optionsFrom:
  url: ->
    "http://some.remote.url.fake/path/#{urlPart.value}"
  headerKey: 'remoteUrlCredential'
  parseResults: (results) ->
    t.name for t in results
```
      
# Field Functions
Call these functions to alter a current field in some way.

* **option()** - Appends a new Option to the field.  Default positional params are title, value, selected.

    Options on select and multiselect fields could have the following properties.
  
    * **title** - Display text for this option. Default: same as value. At least one of title or value is required.
    * **value** - The value the field should have if this option is selected. Default: same as title. At least one of title or value is required.  Do not create two options on the same field with the same value.
    * **selected** *bool* - Set to true for an option to be selected by default.  Default:false
    * **visible** *bool or function* - Works mostly the same as [on a field](#fieldVisible), except that options on fields of type image or tree may not be set to invisible.  This is due their complex rendering which makes it difficult for options to come and go.
    
    ```coffeescript
    field 'foo'
      .option title:'first option', value:'first', selected:true
      .option title:'second option', value:'second'
      .option title:'no choice', value:'none'
    ```
    Image options have different properties, see below.
* **validator()** - Appends a new validation function to the field.

```coffeescript
field 'foo'
  .validator validate.required
  .validator ->
    if @value is 'bar' then 'Value cannot be bar!'
```
* **onChange()** - Appends a new function to run when the field's value changes.  The dynamicValue function is likely more useful for making a value relative, but this allows other properties to be influenced.

```coffeescript
field 'name'
  .onChange ->
    c.title = "What is your favorite color, #{@value}?"
    
c = field name:'color'
```
* **onChangeProperties()** - Append a new function to run whenever any property changes.

```coffeescript
prompt = field type:'info', title:'Choose from the following 0 options'
 
field 'choices'
  .onChangeProperties ->
    prompt.title = "Choose from the following #{@options.length} options"
    
.option 'first'
.option 'second'
```


## Field Types<a name='fieldtypes'></a>
There are many types of fields that can be created.  If a certain type allows extra properties, those are displayed under that type.

* **text** - A simple, one-line input box for text.  This is the default type.
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


# Groups<a name="groups"></a>
Groups are used to contain other form objects, including fields and other groups.  In this way, a hierarchical form may be created that generates a full JSON output that can match a required structure.  Groups will also serve to visually segregate sections of a form.

Groups are built using the `group` function, with default positional parameters title, name, description.

```coffeescript
group 'grandparent'
  .group 'parent'
    .field 'child'
```
As with fields, do not create two groups with the same name in the same place.

## Group Properties
* **title** *string* - Text to display for this group. Default: same as name.
* **name** *string* - The name of this group as it will appear in the input and output JSON.  This will be the key whose value is an object containing all of its children.
* **visible** *bool or function* - Works the same as [on a field](#fieldVisible)
* **display** *string* - The only possible value to set is "inline", which displays all of its fields in a row instead of one on each row.
* **repeating** *bool* - Makes this group a [Repeating Group](#repeatingGroups), see that section for details.  Default:false

## Group Functions
The main purpose of groups is to contain other groups and fields.  Groups and fields are created as children of a given group by calling the respective function on that group.  The group and field functions are the same as on the root of the form except they are preceeded by a dot to show which the parent group should be.

```coffeescript
field 'a'
group 'A Group'
.field 'b'
field 'c'
```
In this example, b is nested beneath 'A Group', while a and c are at the root level.
* **field()** - Add a field beneath this group.  See the [field specs](#fields).
* **group()** - Add a group beneath this group.  See the [group specs](#groups).


# Repeating Groups <a name="repeatingGroups"></a>
Repeating groups are like a cross between Groups and Fields.  Like a group, they contain children which can be any combination of fields and subgroups.  Unlike a group however, these chidren only serve as a template for each section that should be added when the plus button is pressed.  Repeating groups, like Fields, have a value, which is an array of all the repeated sections added to the group and their values.
   
## Repeating Group Properties
The only difference between creating a regular group and a repeating group is the presense of the repeating property, which is set to true.

```coffeescript
group 'repeater', repeating:true
  .field 'first', value:1
  .field 'second', value:2
```
## Repeating Group Functions
* **add** - Adds a new copy of the repeating group prototype to this value.
* **delete(index)** - Deletes an instance of the repeating group from the value.

These functions are usually only called by pressing the groups buttons in the UI, but can be useful for setting up initial state.

```coffeescript
r = group name:'repeater', title:'Choose 3 things', repeating:true
  .field 'thing', value:1

r.add()
r.add()
r.add()

r.value         # [{thing:1},{thing:1},{thing:1}]
```

# Dynamic Functions
Some properties can be set as functions that allow you to have a form's state depend on other parts of the form.  For example, one set of options may be visible only if they make sense based on the value in another field.

Each field will have its context set to the current object.  In other words, when a function attached to a field or group runs, it can reference itself with `this` (or `@`)

It is important to note that these functions are run very often, usually when anything at all on the form changes.  A well-behaved function will

* Always return the same value given the same input.
* Not have any side effects.  Only return what is intended, don't directly alter anything else or your form will likely freeze.
* Run quickly.  If they take too long, the form can get slow and sluggish.
    

## Referenceable Properties<a name="referenceable"></a>
Any property that is possible to set on a field or group can be referenced later by dynamic functions.  There are also some properties that cannot be directly set, but might be useful to read later.

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

```coffeescript
group 'level1'
  .group 'level2'
    .field 'a', value:'stuff'
    .field 'b', value:'things'

root.child('level1').child('level2').child('a').value    # stuff
root.child('level1.level2.b').value                      # things

field 'c'
    .option title:'first', value:'1'

console.log root.child('c.1').title                      # first
```
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
Some forms are used in many places, and a breaking change would affect many workflows.  Tests may be added that ensure the form functions as desired, so that further changes must still adhere to this base functionality.  Form authors should not save forms with failing tests as this indicates a workflow will break.

Tests are written in model code and evaluated every time the code changes.
* **test()** - Pass a function that executes some tests.  To pass a test return nothing, but to fail you can throw and error or fail an assertion.
* **assert()** - Pass a condition as a boolean and a message if that condition fails (is false).

```coffeescript
field 'first'
field 'second'

test ->
    assert root.children.length is 3, 'must have 3 fields in the form'
```

More advanced tests can apply values to the form and test the form's output.  Multiple calls to test will not interfere with each other.

```coffeescript
first =  field 'first'
second = field 'second', dynamicValue: ->
  first.value + " is the word"

test ->
  first.value = 'bird'
  assert second.value is 'bird is the word', 'bbbbbird bird bird, bird is the word'

test ->
  assert second.value is ' is the word', 'default value is nonsense'
```