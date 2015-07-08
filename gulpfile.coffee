gulp = require 'gulp'
coffee = require 'gulp-coffee'
coffeelint = require 'gulp-coffeelint'
mocha = require 'gulp-mocha'
istanbul = require 'gulp-istanbul'
argv = require('yargs').argv
coffeelint = require 'gulp-coffeelint'

src = './src/*.coffee'

gulp.task 'lint', ->
  gulp.src(src)
  .pipe(coffeelint('./coffeelint.json'))
  .pipe(coffeelint.reporter())

gulp.task 'compile', ['lint'], ->
  gulp.src(src)
  .pipe(
    coffee({bare:true})
    .on 'error', console.log
  )
  .pipe gulp.dest('./')

# runs all coffee tests in the test directory.
# alternatively, specify --file <filename> to run a single file or alternate file pattern.
gulp.task 'test', ['compile'], ->
  src = argv.file or 'test/*.coffee'
  gulp.src src
    .pipe mocha()
  