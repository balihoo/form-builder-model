gulp = require 'gulp'
coffee = require 'gulp-coffee'
coffeelint = require 'gulp-coffeelint'
mocha = require 'gulp-mocha'
istanbul = require 'gulp-istanbul'
argv = require('yargs').argv

src = './src/*.coffee'

gulp.task 'lint', ->
  gulp.src(src)
  .pipe(coffeelint('./coffeelint.json'))
  .pipe(coffeelint.reporter())

gulp.task 'compile', gulp.series('lint', ->
  gulp.src(src)
  .pipe(
    coffee({bare:true})
    .on 'error', console.log
  )
  .pipe gulp.dest('lib')
)  

# runs all coffee tests in the test directory.
# alternatively, specify --file <filename> to run a single file or alternate file pattern.
gulp.task 'test', gulp.series('compile', ->
  src = argv.file or 'test/**/*.coffee'
  gulp.src src
    .pipe mocha()
)

gulp.task 'default', gulp.series('test')