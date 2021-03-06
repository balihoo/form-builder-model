# Version History

# 2.2.1
- Fix a bug where applying a value to a multiselect field where some of those values aren't options would sometimes not add all new values as options.

# 2.2.0
- Add the ability for the `disabled` property be a function, and to appear on groups.  Added property `isDisabled`, which provides current disabled status as a boolean.

# 2.1.9
- Fix a bug when applying a value to a field with options when that value isn't one of the choices.  It would correctly set the field's value and add that value as an option, but the option object was not initially set as `selected`.

# 2.1.8
- A few minor fixes that affect rendering of groups.

# 2.1.7
- Fix a bug where `getChanges` always showed data types of object or array as changed.

# 2.1.6
- It was possible for a data object to be modified when passed to `applyData`.  We now clone the parameter to prevent this.

# 2.1.5
- The introduction of `beforeOutput` allows forms to output data in a format that breaks `getChanges`.  This fix formally defines that the `changes` section of the `getChanges` result shall not include any transformations from `beforeOutput`.

# 2.1.4
- A bug when cloning repeating groups would not clone child elements correctly.

# 2.1.3
- Fix a bug where buildOutputData on repeating groups failed.  This was introduced in 2.1.2.

# 2.1.2
- Remove the name attribute from repeating group value instances so that it won't appear in rendered forms.  This restores an old behavior that was accidentally changed.

# 2.1.1
- Minor doc updates and add a test.

# 2.1.0
- beforeInput and beforeOutput property functions.

# 2.0.4
- Refactor by breaking up into multiple source files.

# 2.0.3
- Fix an issue where fields with optionsFrom that didn't find any options would remain a text field.  Now optionsFrom defaults a field's type to select regardless of whether any options are returned.

# 2.0.2
- Add a modelClassName property, which is needed for determining which class an object belongs to in IE.

# 2.0.1
- Fix a bug where default values are not saved for fields in a repeating group.

# 2.0.0
- Several speedups for building large tree fields and fields with many options in general

There is one minor breaking change when building a field, then later during runtime adding another option with selected:true, perhaps as the result of some user action. Prior to 2.0.0 that new option would add itself to the field's defaultValue, affecting the restored value when clear() is called. From 2.0.0 onward, options with selected:true will only be part of the defaultValue if they are there during build time.

# 1.9.0
- Add Image upload limitations for dimensions and file size.

# 1.8.1
- Add npm script prepublish

# 1.8.0
- Tree control rework.

# 1.7.4
- Don't modify parameters when building from package.  This caused a problem when the same package is reused with 
different data.

# 1.7.3
- Fix a bug where template fields with invalid Mustache would fail and prevent future changes. This was a problem in the UI where a user would type the value of a template, but become stuck when that incomplete value is invalid and no longer able to be changed.

# 1.7.2
- Make date field stringToDate parse in strict mode.

# 1.7.1
- Fix a bug where applying a null value to a form that previously held an object would throw an error. This also exposed a related bug where previous values were affecting later applyData calls.

# 1.7.0
- Add format parameter to date fields.

# 1.6.0
- Add number field type.

# 1.5.0
- Add field disabled property, which adds disabled to the rendered html.

# 1.4.5
- Republish after mistaken merge target.

## 1.4.4
- Allow emit function to send events from imports.

## 1.4.3
- Republish

## 1.4.2
- Prevent adding duplicate options to a field.

## 1.4.1
- When applying a value to a field with options, make sure that value is among that field's options.  This was an issue in the UI specifically when a new image was uploaded to an image field, then that form was reloaded with that previous value.  The field had the correct value, but it did not show in the rendered field.

## 1.4.0
- Add autocomplete field property.

## 1.3.3
- Fix a bug where adding an option with selected:true to an image field did not set the field's value to that option.

## 1.3.2
- Images with allowUpload:true no longer require the companyID property. The presence of this property indicates that images shoudl be uploaded to Marketer under the given companyID, while its absence indicates that images should be uploaded to Form Builder.

## 1.3.1
- Fix a bug that caused values being set in the model code to be cleared out. Values defined in the model code should be treated as default values.

## 1.3.0
- Added a new button field type to support triggering events within rendered forms. This allows applications that are embedding forms to listen for and react to form-defined events.

## 1.2.1
- Default build data to an empty object to prevent NPE in model code that references this data.

## 1.2.0
- Added optional purgeDefaults parameter to the clear functions to allow all values to be cleared instead of reseting to default values.

## 1.1.5
- Further bugfix for getting options from url where string urls were never fetched.

## 1.1.4
- Fix a bug with throttling multiple fields that fetch options from a url.

## 1.1.3
- Added an additional test to verify that model data is properly merged each time applyData is called.

## 1.1.2
- Added a new field property named "template". This new property abstracts mustache rendering away from form builder users by allowing them to define two related fields: one field that contains the mustache template and a second field that references the first field name in its template property. The second field will then output rendered mustache as its value.

## 1.1.1
- Fixed a bug where a field created without a value property would have an undefined defaultValue property.  This caused an issue when that value was later changed, then cloneModel was called.  This clone would see the value and set the defaultValue to the same, which did not match the undefined defaultValue property in the initial object.  Changed so that both value and defaultValue will always contain something, which prevents overwriting missing properties on clone.

  Also changed related issue where providing both defaultValue and value would cause the defaultValue to overwrite the value property.  This is undesirable as defaultValue is only used for reference and resetting to default later, not during field construction.

- Fixed a bug where options that are selected by default are not added to the field's defaultValue property, which affects the way such fields are rendered.
