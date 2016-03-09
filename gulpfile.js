var fs = require("fs");
var gulp = require('gulp');
var livereload = require('gulp-livereload');

var cache = [];

// livereload task
// we have to compare file content for changes, because our jekyll stuff may write out the same results
gulp.task('watch', function() {
  livereload.listen();
  var w = gulp.watch('/tmp/binaryage-site/serve/**/*.{css,js,html}');
  w.on('change', function(file) {
    try {
      var cachedContent = cache[file.path];
      var newContent = fs.readFileSync(file.path, "utf8");
      var contentChanged = newContent != cachedContent;
      if (contentChanged) {
        cache[file.path] = newContent;
        // console.log("! "+file.path);
        livereload.changed(file.path);
      }
    } catch (e) {
      console.error(e);
    }
  });
});

gulp.task('default', ['watch']);