
# Top-Level API
Methods on the form-builder-model package that allow for building and interacting with a form model.

* mergeData(dataA, dataB)

    Merges two data objects together, for example if a form's input data should be an amalgam of different sources.  Merging data then applying all at once works the same as building a model and calling applyData multiple times.


* fromCoffee(code [,data [,element [,imports]]])

    Create a form builder model from the given the [model code](ModelCode.md) in CoffeeScript.
    
    During build, initial data may be supplied, which is then applied to the model after building.
    
    Providing a DOM element as the third parameter gives a target for sending form change and validation events, which some clients may choose to handle and communicate to the user.
    
    Finally, any required imports may be supplied as an object with keys for each import's reference name, and values as the built form to import.
    
    The result of fromCoffee is a model object.    


* fromPackage(pkg [,data [,element]])

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


* handleError(err)

# Model API
Once built, a model object has some functions that will be useful to processes that use it.

* clear()

    Clears out all values that have been set and restores all fields to their default values.  That is, any value that is specified in the model code as the default will be restored. Extra data supplied (as the second parameter to from* in the top level API) is the initial data, not the default value.


* applyData(data [,clear])

    Applies input data to the built model.  Any supplied values will completely overwrite matching fields in the model and fields not supplied in data will not be changed.
    
    To reset all fields to their default values prior to applying data, pass true as the clear parameter.  Default false.


* buildOutputData()

    Generates a JSON object that represents the total value of this form model.


* getChanges(initialData)

    Compare the current state of the form with the initial state provided.
    
    Returns an object with two keys.
    
    * changes: an array of objects, each containing
        * name: The path to the changed field
        * title: The title of the field
        * before: The initial value of the field
        * after: The final value of the field
    * patch: the raw [JSON patch](https://tools.ietf.org/html/rfc6902) (via [jiff](https://www.npmjs.com/package/jiff#diff)) between total before and after data.  Does not include test operations.