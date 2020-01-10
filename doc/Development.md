

# Development of this project

## Requirements

* npm - tested with npm v6.4.1 -  Different versions can store packages in very different ways, so be aware of that if you use something different.
* node - 0.10.26, tested up to v10.14.1 - Note that the package in the apt repos is much older, and there are much newer ones available.  Newer 10.x versions are probably ok.
* gulp - Part of the required packages, but is useful to have a global version too. `npm install -g gulp`

## Git and npm

Use the standard git-branch-merge workflow to update master, then `npm publish`

This package is published to the public npm repositories, then referenced from other places by version there.  So follow [semver](http://semver.org/) policies with the package name, then npm publish when you have something working.

Depending on the features added, you may need to then update the reference in these places:

* form builder
* fulfillment lambda functions (both fb functions).  May be skipped if the change is only in support of rendering in the plugin.

# Using this project in another project

1. npm install 'balihoo-form-builder-model' (or in package.json)
1. require('balihoo-form-builder-model')

# Bundling for the browser

If you want to build your models in the browser, [browserify](https://www.npmjs.com/package/browserify) can bundle everything up for you.
Due to the way backbone is structured, you'll need to either have the jquery npm module installed, or explicitly exclude it when bundling.

	browserify [path to]/formbuilder.js -o [output file] --exclude jquery