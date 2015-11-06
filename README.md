# [form-builder-model](https://github.com/balihoo/form-builder-model)

Standalone code for building form builder models without any UI bindings.
This project can build a model and produce a Backbone object hierarchy.
This model can then be rendered with ui components in the main [form-builder](https://github.com/balihoo/form-builder) package, or used by itself for processing input and generating JSON output.

# Typical Use

	var http = require('some http client');
	var formbuilder = require('form-builder-model');
	
	http.get('<formbuilderurl>/<formid>/package', function(err, result) {
	  var model = formbuilder.fromPackage(result.body);
	  model.applyData({foo:'bar'});
	  var output = model.buildOutputData();
	});

For more on building and processing saved forms, see the [API Docs](doc/API.md)

For help with authoring forms, see the [Model Code Docs](doc/ModelCode.md)

To develop this project or projects that use it, see [Development](doc/Development.md)

