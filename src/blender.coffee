fs = require('fs')
path = require('path')

global.sugar = require('sugar')
global._ = require('underscore')
debug = require('debug')('blender')

{EventEmitter} = require('events')
Jar = require('./jar')
death = require('./util').death

class Blender
  jars: {}
  options: null
  production: false
  nodeIndex: {}

  constructor: ->
    @emitter = new EventEmitter()

    # listen for jar changes and additions
    @emitter.on('jar_rebuild', (jar, node)=>@onJarRebuild(jar, node))

  onJarRebuild: (jar, node)->
    @rebuildUrlIndex()

  ###
  Rebuild the index used during dev lookups
  ###
  rebuildUrlIndex: ->
    @nodeIndex = []
    for name, jar of @jars

      # build up a global index
      for src, node of jar.nodeIndex
        @nodeIndex[src] = node

  ###
  get 'er all set
  ###
  init: (@options)->
    @production = process.env.NODE_ENV is "production"

    # resolve full path to build dir
    options.common.js_build_dir = path.resolve("#{path.join(options.common.build_dir, 'scripts')}" )
    options.common.css_build_dir = path.resolve("#{path.join(options.common.build_dir, 'styles')}")

    # optionally allow changing of the root in the generated url
    options.common.url_root = '/blender' unless options.common.url_root?

    # process the jars
    for name, jarOptions of options
      continue if name == 'common'

      # merge in the common vendors
      jarOptions.vendors ?= []
      jarOptions.vendors = _.union(options.common.vendors, jarOptions.vendors)

      # construct a new named jar
      @jars[name] = jar = new Jar(name, @emitter, options.common.url_root, @production, jarOptions)
      jar.build()

    @rebuildUrlIndex()


  ###
  express middleware
  ###
  middleWare: (req, res, next) =>
    return next() unless 'GET' == req.method

    urlRoot = @options.common.url_root
    return next() unless req.url.slice(0, urlRoot.length) == urlRoot

    urlPath = req.url.split('/')
    debug(urlPath)

    fileExt = urlPath[urlPath.length - 1].split('.')[1]

    # make sure we're responsible for handling this one
    node = @nodeIndex[req.url]
    return next() unless node

    sugar.info("Blender serve: #{req.url}".blue)

    # console.log "URL: #{req.url}"
    # for k,v of @nodeIndex
    #   console.log "KEY: #{k} #{v.pathName}"

    res.set('Content-Type', 'application/javascript')
    res.send(node.contents)

  ###
  will it blend?
  ###
  blend: (app, options)->
    debug("blending")
    sugar.info("=> Blender")

    @init(options)
      
    # set up view helpers
    app.locals.blenderJs = (name)=>
      @jars[name].jsTags

    app.locals.blenderCss = (name)=>
      @jars[name].cssTags

    # bind the middleware
    app.use(@middleWare)

module.exports = new Blender()








