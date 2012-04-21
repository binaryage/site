# BinaryAge Site

This is an umbrella project to organize all sites *.binaryage.com.

  * local development server
  * maintenance utilities
  * mass deploying
  
### Prerequisities

  * [ruby](http://www.ruby-lang.org), rake, [rubygems](http://rubygems.org)
  * [node.js](http://nodejs.org), [npm](http://npmjs.org)
  
**Recommended**:

  * [brew](http://mxcl.github.com/homebrew)
  * [rvm](http://beginrescueend.com)
  * [nvm](https://github.com/creationix/nvm)
  
### Init steps

    git clone git@github.com:binaryage/site.git
	cd site
	rake init
	
### Launch development server

  * make sure you have your /etc/hosts properly configured, see `rake hosts`

To run the dev server:

    rake