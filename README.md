# form-builder-model

Standalone code for building form builder models without any UI bindings.
This project is intended to build a model and produce a Backbone object hierarchy.
This model can then be rendered with ui components in the main form-builder package.

# Installation

For now, installation can be done manually.

1. git clone this repo
2. from your project, npm install [this project directory]
3. require('form-builder-model')

In the near future, you should be able to put an entry in your package.json with 
credentials to pull this private repo directly.

## Bundling for the browser

If you want to build your models in the browser, [browserify](https://www.npmjs.com/package/browserify) can bundle everything up for you.
Due to the way backbone is structured, you'll need to either have the jquery npm module installed, or exclude it when bundling.

	browserify [path to]/formbuilder.js -o [output file] --exclude jquery

# Use

The main purpose of the form-builder-model package is to take form code in some format and produce a backbone model of form objects.

## fromCoffee(code, data, element, imports)
Build a single model object from Coffeescript code
### code - model code in Coffeescript.
### data (optional) - initialization data for the model.  Supplying this is equivalent to building without data, then calling applyData.
### element (optional) - if rendering, this element will receive validation and recalculating events as the state of the model chagnes.
### imports (optional) - an object whose keys are the namespace of any imports, and the value is the build model for that namespace.  Supplying this parameter will require fetching and building each import for this form before building this form.

## fromPackage(package, data, element)
Build a model from a pacakge containing all forms that will be needed.  This method has the advantange of not requiring several fetches to the server to retrieve and build imports prior to building this model.
### package
* formid (int or string)
* forms (array of object).  Each object contains
	* formid (int)
	* model (string) coffeescript model code
	* imports (array of object).  Each object contains
		* importformid (int)
		* namespace (string)
* data (object, optional) - may be supplied in the package or as a separate parameter
### data (optional) - initialization data for the model.  Supplying this is equivalent to building without data, then calling applyData.
### element (optional) - if rendering, this element will receive validation and recalculating events as the state of the model chagnes.

## fromCode(code, data, element, imports)
The same as fromCoffee, except code is supplied in JavaScript format.

## applyData(model, data)

Apply input data to a built model object

## buildOutputData(model)

Product output data for the build model.
Also available as a property function of the build model.

# Typical Use

	var http = require('some http client');
	var formbuilder = require('form-builder-model');
	
	http.get('formbuilderurl/formid/package', function(err, result) {
	  var model = formbuilder.fromPackage(result.body);
	  model.applyData({foo:'bar'});
	  var output = model.buildOutputData();
	  
	  console.log(output);
	});

# Model Functions

Todo

As wiki, or as separate markup file(s).  Should be exported to standard web page for hosting to those without access to this repo.


