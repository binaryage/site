# BinaryAge Site

This is an umbrella project to organize sites under *.binaryage.com.

  * local development server
  * maintenance utilities
  * mass deploying
  
### The idea

The idea is to have one repo with all subdomains as separate repositories, each tracked as am individual git submodule. Individual sites have usually a dependency on [base](/binaryage/base) - again tracked as a git submodule. This should give us tools to reconstruct the whole site to any point in the history while having granular control of commit rights to parts of the site. Nice transparency via GitHub is a bonus.

    .
    ├── www
    │   ├── base
    │   ├── index.md
    |   ...
    ├── totalfinder-web
    │   ├── base
    │   ├── index.md
    |   ...
    ├── totalspaces-web
    │   ├── base
    │   ├── index.md
    |   ...
    ├── blog
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
    
Init task does [several things](https://github.com/binaryage/site/blob/master/rakefile#L120-153):
  
  * fetches all submodules
  * update push remote urls to be writable
  * hard-links all base submodules into www/base
  
Hard-linking is essential for local development. Changes you make under base are then effective in all repos.

    .
    ├── www
    │   ├── base (real folder)
    │   ├── index.md
    |   ...
    ├── totalfinder-web
    │   ├── base (hard link to ../www/base)
    │   ├── index.md
    |   ...
    ├── totalspaces-web
    │   ├── base (hard link to ../www/base)
    │   ├── index.md
    |   ...
    ├── blog
    ...

    
### Launch development server

  * make sure you have your /etc/hosts properly configured, see `rake hosts`

**To run the full dev server**:

    rake
    
**To run the dev server only for selected sub-sites**:

    rake serve what=www,totalspaces,blog

### Deployment

Just push your changes into `web` branch on GitHub and you are done. 

We have setup post-recieve hook which will build whole web site and then will push baked static site files back into `gh-pages` branch. [GitHub Pages](//pages.github.com) will do the deployment automatically. <span style="color:red">Don't forget to push "base" submodule first if you have modified some shared stuff.</span>

### Update from remote

If you want to get incrementally to remote state without doing `rake init`, you may reset your repo to remote state via `rake reset`. <span style="color:red">This will destroy your local changes!!!.</span>

Alternatively you may always use your git-fu to non-destructively pull from remotes (`git submodule` is your friend).