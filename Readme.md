# Blender - asset manager

 Blender is an asset builder and asset pipeline for building modern web apps.

## Why?

Liked the concepts of Piler, liked aspects of the Rails Asset Pipeline, liked how Brunch & Yeomen have
the concept of an "HTML5 app", which can be built.

Compiles my favorites from each.

## Features

  - Client side modules w/ server side dependency
  
  - Handlebars (precompiled) templates are treated as first class

  - Multiple sub-apps each with it's own dependency chain
    - Name spacing
    - Common and app specific vendor scripts.  i.e. Admin requires backbone.js but the main site does not
  
  - CDN support
  
  - Automatic wrapping in requirejs, AMD compliant modules
    - Optional wrapping of vendor provided 
  
  - Production builds
    - Two script production builds with MD5 tags (vendor.js and user.js)
    - Minification support 

  - Development builds
    - sub-app level file watching and rebuilding
    - Served through Express 3 middleware
    - Each file is preserved, one script tag per file
    - File watching

## Usage

```coffeescript
  ###
  Fire up the blender
  ###
  blender.blend app,     
    common:
      # optional path added to your scripts /scripts/admin/...
      url_root: '/scripts'

      # path to production builds
      build_dir: './test/public'

      # common vendor scripts to include in the build process
      # prefix with "http://" to designate remote
      vendors: [
        # use cdn
        'http://code.jquery.com/jquery-1.8.2.min.js' 
        './test/vendor/almond.js'
        './test/vendor/handlebars.js'
      ]

    # each additional name is treated as a name-space (i.e. admin/client/web)
    admin: # namespace
      # where the files live for this sub-app
      dir: './test/app_admin'

      # the main.js or .coffee file to begin dependency checking
      main: 'main'

      # the main style sheet (stylus) for this app
      style: 'styles/main'

      # any specialized vendors files to include within this name space
      # surround with [] to modularize. '[./xyz.js]'
      vendors: [
      ]

```


```html
<html>
  <head>
        
    <!-- blender style-->
    <link rel="stylesheet" href="/scripts/admin/styles/main.css">
    <!-- end blender  -->

        
    <!-- blender vendor-->
    <script type="text/javascript" src="http://code.jquery.com/jquery-1.8.2.min.js"></script>
    <script type="text/javascript" src="/scripts/admin/jquery.js"></script>
    <script type="text/javascript" src="/scripts/admin/almond.js"></script>
    <script type="text/javascript" src="/scripts/admin/handlebars.js"></script>
    <!-- end blender  -->

    <!-- blender user-->
    <script type="text/javascript" src="/scripts/admin/main.js"></script>
    <script type="text/javascript" src="/scripts/admin/models/test.js"></script>
    <script type="text/javascript" src="/scripts/admin/models/hope.js"></script>
    <script type="text/javascript" src="/scripts/admin/templates/temp.js"></script>
    <!-- end blender  -->

    <script>require("main");</script>

  </head>
  <body>Something is going down here</body>
</html>
```


## License

(The MIT License)

Copyright (c) 2012 Steve McLelland

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.