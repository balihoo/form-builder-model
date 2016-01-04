# Version History

## 1.1.2
- Added a new field property named "template". This new property abstracts mustache rendering away from form builder users by allowing them to define two related fields: one field that contains the mustache template and a second field that references the first field name in its template property. The second field will then output rendered mustache as its value.

## 1.1.1
- Fixed a bug where a field created without a value property would have an undefined defaultValue property.  This caused an issue when that value was later changed, then cloneModel was called.  This clone would see the value and set the defaultValue to the same, which did not match the undefined defaultValue property in the initial object.  Changed so that both value and defaultValue will always contain something, which prevents overwriting missing properties on clone.

  Also changed related issue where providing both defaultValue and value would cause the defaultValue to overwrite the value property.  This is undesirable as defaultValue is only used for reference and resetting to default later, not during field construction.

- Fixed a bug where options that are selected by default are not added to the field's defaultValue property, which affects the way such fields are rendered.