# BinaryAge Site

This is an umbrella project to organize sites under *.binaryage.com.

  * local development server
  * maintenance utilities
  * mass deploying
  
### The idea

The idea is to have one repo with all subdomains as separate repositories, each tracked as am individual git submodule. Individual sites have usually a dependency on [base](/binaryage/base) - again tracked as a git submodule. This should give us tools to reconstruct the whole site to any point in the history while having granular control of commit rights to parts of the site. Nice transparency via GitHub is a bonus.

    .
    ├── totalfinder-web
    │   ├── base
    │   ├── index.md
    |   ...
    ├── www
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
    
### Launch development server

  * make sure you have your /etc/hosts properly configured, see `rake hosts`

**To run the full dev server**:

    rake
    
**To run the dev server only for selected sub-sites**:

    rake serve what=www,totalspaces,blog

### Deployment

Just push your changes into `source` branch on GitHub. We have setup post-recieve hook which will build whole web and then push baked static site files back into `gh-pages` branch. [GitHub Pages](//pages.github.com) will do the deployment to S3 automatically. <span style="color:red">Don't forget to push submodules first if you have modified some shared stuff.</span>

### Update from remote

If you want to get incrementally to remote state without doing `rake init`, you may reset your repo to remote state via `rake reset`. <span style="color:red">This will destroy your local changes!!!.</span>

Alternatively you may always use your git-fu to non-destructively pull from remotes (`git submodule` is your friend).