# BinaryAge Site

This is an umbrella project to organize all sites *.binaryage.com.

  * local development server
  * maintenance utilities
  * mass deploying
  
### The idea

The idea is to have one repo with all sub-sites as separate repositories, each tracked as a git submodule. Individual sub-sites have usually dependencies on [shared](/binaryage/shared) files and [layouts](/binaryage/layouts) - again tracked as git submodules. This should give us tools to reconstruct the whole site to any point in the history while having granular control of commit rights to parts of the site and nice transparency using GitHub.

    .
    ├── asepsis-web
    │   ├── _layouts
    │   └── shared
    │   ├── index.md
    |   ...
    ├── blog
    │   ├── _layouts
    │   └── shared
    │   ├── index.md
    |   ...
    ├── drydrop
    ...
  
### Prerequisities

  * [ruby](http://www.ruby-lang.org), [rake](http://rake.rubyforge.org), [rubygems](http://rubygems.org)
  * [node.js](http://nodejs.org), [npm](http://npmjs.org)
  
**Recommended** (optional):

  * [brew](http://mxcl.github.com/homebrew)
  * [rvm](http://beginrescueend.com)
  * [nvm](https://github.com/creationix/nvm)
  
### Bootstrap local development

    git clone git@github.com:binaryage/site.git
    cd site
    rake init
    
### Launch development server

  * make sure you have your /etc/hosts properly configured, see `rake hosts`

**To run the full dev server**:

    rake
    
**To run the dev server only for selected sub-sites**:

    rake serve what=www,totalspaces,blog

### Deployment

Just push your changes to GitHub. [GitHub Pages](//pages.github.com) will do the deployment automatically. Don't forget to push submodules first if you have modified some shared stuff.