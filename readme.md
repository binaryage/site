# BinaryAge Site

This is an umbrella project to organize sites under [*.binaryage.com](http://www.binaryage.com).

  * local development server
  * maintenance utilities
  * deploying utilities

### The idea

The idea is to have one repo with all subdomains as separate repositories, each tracked as an individual git submodule. 
Individual sites have usually a dependency on [shared](/binaryage/shared) - again tracked as a git submodule. 
This should give us tools to reconstruct the whole site to any point in history while having granular control of commit 
rights to individual subdomains of the site. Transparency via GitHub is a bonus.

    .
    ├── www
    │   ├── shared
    │   ├── index.md
    |   ...
    ├── totalfinder-web
    │   ├── shared
    │   ├── index.md
    |   ...
    ├── totalspaces-web
    │   ├── shared
    │   ├── index.md
    |   ...
    ├── blog
    ...

### Shared stuff

Files which should be shared by all sites should go into [shared](/binaryage/shared) repo.

  * [layouts](https://github.com/binaryage/shared/tree/master/layouts) - jekyll layout files, these won't be present in the 
  generated site
  * [includes](https://github.com/binaryage/shared/tree/master/includes) - various includes for layout files, these won't be 
  present in the generated site
  * [root](https://github.com/binaryage/shared/tree/master/root) - these will be generated and then moved to the 
  root level of the site, useful for generating the same page for all sites, like 404.html
  * [img](https://github.com/binaryage/shared/tree/master/img) - shared images
  * [css](https://github.com/binaryage/shared/tree/master/css) - shared css files, we use stylus for preprocessing and 
  concatenation
  * [js](https://github.com/binaryage/shared/tree/master/js) - shared javascript/coffeescript files, we have defined 
  [.list file](https://github.com/binaryage/shared/blob/master/js/code.list) for concatenation
  * ...

### Prerequisities

  * [nginx](http://nginx.org)
  * [ruby](http://www.ruby-lang.org), [rake](http://rake.rubyforge.org), [rubygems](http://rubygems.org)
  * [node.js](http://nodejs.org), [yarn](https://yarnpkg.com)

### Bootstrap local development

    git clone git@github.com:binaryage/site.git
    cd site
    rake init

The `init` task does [several things](https://github.com/binaryage/site/blob/master/rakefile):

  * inits and updates all git submodules
  * pins all submodules to latest web branch tips

### Launch development server

  * make sure you have your `/etc/hosts` properly configured, see `rake hosts`

**To run the full dev server**:

in one terminal session run nginx proxy:

    rake proxy

in another terminal session run the jekyll debug server:

    rake serve what=www,totalspaces,blog

Note that live reloading and css watching is enabled by default. Using [browser-sync](https://browsersync.io).

### Deployment

Just make changes in some sub-site repo and push your changes into its `web` branch.

We have setup `hookgun` as post-recieve hook which will build the sub-site and then will push baked static site files back 
into its `gh-pages` branch. [GitHub Pages](//pages.github.com) will do the deployment automatically. It will also move 
pointer of submodule here in the `site` repo.

Don't forget to push `shared` submodule first if you have modified some shared stuff.

### Update from remote

If you want to get incrementally to remote state without doing `rake init`, you may reset your repo to remote state via 
`rake reset` (**will destroy your local changes!!!**).

Alternatively you may always use your git-fu to non-destructively pull from remotes (`git submodule foreach` is your friend).
