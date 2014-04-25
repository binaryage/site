var fs = require("fs");
var gulp = require('gulp');
var livereload = require('gulp-livereload');

var cache = [];
var lr = livereload();

// livereload task
// we have to compare file content for changes, because our jekyll stuff may write out same content
gulp.task('watch', function() {
  var w = gulp.watch('/tmp/binaryage-site/serve/**/*.{css,js,html}');
  w.on('change', function(file) {
    var cachedContent = cache[file.path];
    var newContent = fs.readFileSync(file.path, "utf8");
    var contentChanged = newContent != cachedContent;
    if (contentChanged) {
      cache[file.path] = newContent;
      console.log("! "+file.path);
      lr.changed(file.path);
    }
  });
});

gulp.task('default', ['watch']);