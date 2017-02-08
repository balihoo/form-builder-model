
# Top-Level API
Members on the form-builder-model package that allow for building and interacting with a form model.

* `fromCoffee(code [,data [,element [,imports]]])`

    Create a form builder model from the given the [model code](ModelCode.md) in CoffeeScript.
    
    During build, initial data may be supplied, which is then applied to the model after building.
    
    Providing a DOM element as the third parameter gives a target for sending form change and validation events, which some clients may choose to handle and communicate to the user.
    
    Finally, any required imports may be supplied as an object with keys for each import's reference name, and values as the built form to import.
    
    The result of fromCoffee is a model object.    

* `fromPackage(pkg [,data [,element]])`

    Also builds a model from model code, but the model and its imports are packaged up in one parameter.  The pkg object is usually obtained from the form builder getPackage path, and contains:
    
    * formid: the integer id of the form to build. Must appear in the forms property
    * forms: An array of form objects, each of which contains
        * formid: the integer formid
        * model: the CoffeeScript [model code](ModelCode.md) for this form
        * imports (optional): an array of objects, each of which contains
            * importformid: the formid of this import.  Must exist in pkg.forms
            * namespace: the reference name for this form
    * layout (optional): Layout required for outputting a creative form.  Note that form-builder-model does not substitute form values into a layout itself, that is handled by [Mustache](https://github.com/balihoo-anewman/mustache.js) as a separate step.
    * partials (optional): An object containing Mustache partials for the layout.
    * data (optional): initial data for the form. This works the same as the data parameter to the fromPackage function.
    
    A package contains a form as well as every imported form that it will require recursively.  In this way, all of the steps to create a fully built model can happen in one function call, rather than pre-building each model perhaps with several requests to form builder.

* `fromCode(code [,data [,element [,imports]]])`

    Same as fromCoffee, but takes code as JavaScript.  fromCoffee simply compiles CoffeeScript to JavaScript then calls this function.
    
    If you will build the same model many times and you want to save the compilation step, you could compile CoffeeScript yourself then call this function instead.
    
* `mergeData(dataA, dataB)`

    Merges two data objects together, for example if a form's input data should be an amalgam of different sources.  Merging data then applying all at once works the same as building a model and calling applyData multiple times.

* `modelTests = []`

    modelTests is an array of functions that the model code has defined for testing the built object.  The tests will not be run during build, they are only provided to those processes where testing the model would be appropriate.
    
    Tests that fail will call the error handler with a failure message result, which may be a string or error.
    
    The tests may modify the model as part of their test process, so the model should be rebuilt prior to every test.  This will also cause the modelTests array to be rebuilt!
    
    Testing procedure should then be something like this
    ```coffeescript
    formbuilder.fromCoffee modelCode #initial build to get the number of tests.
    numTests = formbuilder.modelTests.length
    for i in [0..numTests]
        try
            formbuilder.modelTests[i]() #call the test function
            formbuilder.fromCoffee modelCode # rebuild model for next test
        catch e
            #do something with the error
    ```
 
* `errorHandler(err)`

    Errors that occur when testing or running a model will be passed to an error handler function.  This default function will ensure that the message is an Error object and then throw it.  This might not be desirable, for example if a runtime error could not be caught.  You can overwrite the default error handler by setting it to a new function.
    
    ```coffeescript
    formbuilder = require 'balihoo-formbuilder-model'
    formbuilder.errorHandler = (err) ->
      msg = err.message or err
      displayErrorMessage(msg)
      disableSaveButtons()
    ```
    
    This function should take one parameter, which might be a string or Error object.  Keep in mind that required modules are singletons, so this change will be global.
    
* `getChanges(modelAfter, beforeData)`
    
    The same as calling modelAfter.getChanges(beforeData).  See below.

* `applyData(modelObject, inData, clear, purgeDefaults)`<a name='applyData'></a>        

    The same as calling modelObject.applyData(data [,clear] [,purgeDefaults]).  See below.

* `buildOutputData(model)`<a name='buildOutputData'></a> 

    The same as calling model.buildOutputData().  See below


# Model API
Once built, a model object has some functions that will be useful to processes that use it.

* `clear([purgeDefaults])`

    Clears out all values that have been set and restores all fields to their default values.  That is, any value that is specified in the model code as the default will be restored. Extra data supplied (as the second parameter to from* in the top level API) is the initial data, not the default value.


* `applyData(data [,clear] [,purgeDefaults])`

    Applies input data to the built model.  Any supplied values will completely overwrite matching fields in the model and fields not supplied in data will not be changed.
    
    To reset all fields to their default values prior to applying data, pass true as the clear parameter.  Default false.
    
    To reset all fields to blank, regardless of whether they had a default value, pass true as the purgeDefaults parameters.  Default false.


* `buildOutputData()`

    Generates a JSON object that represents the total value of this form model.


* `getChanges(initialData)`

    Compare the current state of the form with the initial state provided.
    
    Returns an object with two keys.
    
    * changes: an array of objects representing changes to the model object itself _without_ any transformations from [buildOutputData](#buildOutputData).  This is useful for communicating to the user which fields have changed using structure and title that they are familiar with.  Each object contains
        * name: The path to the changed field, in the same format as the patch path (below)
        * title: The [title](ModelCode.md#title) of the field
        * before: The initial value of the field
        * after: The final value of the field
    * patch: the raw [JSON patch](https://tools.ietf.org/html/rfc6902) (via [jiff](https://www.npmjs.com/package/jiff#diff)) between the current built output data and that from a previous state.  Does not include test operations.  This _does_ include any transformations performed by [beforeOutput](ModelCode.md#beforeInputOutput).  This will be an array of objects each containing
        * op: Operation (replace, etc)
        * path: The path to the json element that changed
        * value: The new value
    
    
    
* `cloneModel(newRoot = @root, constructor = @constructor, excludeAttributes=[])`

    Because our models are built in backbone with several triggers on various changes, it can be difficult to create a copy of your form model.  This method will perform a deep copy and update any references as necessary.
    
    Model changes will fire events in the root element.  If you want these events to go elsewhere, you may supply a different root element.
    
    Finally, you may NOT want to copy certain attributes.  Supply an array of those by name to exclude them from the clone, in which case each will receive the default value.
