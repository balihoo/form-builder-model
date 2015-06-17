gulp = require 'gulp'
coffee = require 'gulp-coffee'
coffeelint = require 'gulp-coffeelint'
mocha = require 'gulp-mocha'
istanbul = require 'gulp-istanbul'

gulp.task 'compile', ->
  gulp.src('./src/*.coffee')
  .pipe(
    coffee({bare:true})
    .on 'error', console.log
  )
  .pipe gulp.dest('./')

gulp.task 'test', ['compile'], ->
  gulp.src 'test/*.coffee'
    .pipe mocha()
  