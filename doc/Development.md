

# Development of this project

## Requirements

* npm - I use v1.4.3.  Different versions can store packages in very different ways, so be aware of that if you use something different.
* node - 0.10.26.  Note that the package in the apt repos is much older, and there are much newer ones available.  Newer 10.x versions are probably ok.
* gulp - Part of the required packages, but is useful to have a global version too. `npm install -g gulp`

# Using this project in another project

1. npm install 'balihoo-form-builder-model' (or in package.json)
1. require('balihoo-form-builder-model')

# Bundling for the browser

If you want to build your models in the browser, [browserify](https://www.npmjs.com/package/browserify) can bundle everything up for you.
Due to the way backbone is structured, you'll need to either have the jquery npm module installed, or explicitly exclude it when bundling.

	browserify [path to]/formbuilder.js -o [output file] --exclude jquery