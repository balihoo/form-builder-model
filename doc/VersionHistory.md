# Version History

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