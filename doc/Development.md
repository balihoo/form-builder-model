

# Development of this project

## Requirements

* npm - I use v1.4.3.  Different versions can store packages in very different ways, so be aware of that if you use something different.
* node - 0.10.26.  Note that the package in the apt repos is much older, and there are much newer ones available.  Newer 10.x versions are probably ok.
* gulp - Part of the required packages, but is useful to have a global version too. `npm install -g gulp`


# Using this project in another project
Currently, we cannot npm install this tool directly because the code is hosted in a private repository and we don't want to store those credentials in our package.jsons.
Instead, use your own credentials to fetch this then use npm to install from the local disk.

1. git clone this repo
2. from your project, `npm install [this project directory]`
3. require('form-builder-model')

You will then want to bundle this node_module with your deployment.  That is, your .gitignore or .npmignore file will often exclude all node_modules.  Make it exclude all but this one, since it can't be fetched later.

Yes, this is a pain.  We will shortly move this to a public package which will make things much easier.

# Bundling for the browser

If you want to build your models in the browser, [browserify](https://www.npmjs.com/package/browserify) can bundle everything up for you.
Due to the way backbone is structured, you'll need to either have the jquery npm module installed, or explicitly exclude it when bundling.

	browserify [path to]/formbuilder.js -o [output file] --exclude jquery