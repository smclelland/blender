fs = require('fs')
path = require('path')

# global.sugar = require('k-sugar')
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
    options.common.verbose = if options.common.verbose? then options.common.verbose else false

    if @production
      if options.common.production_host? 
        options.common.url_path = "http://#{options.common.production_host}/#{options.common.url_path}" 
      else
        options.common.url_path = '' unless options.common.url_path?
    else
      # optionally allow changing of the root in the generated url
      options.common.url_path = '/blender' unless options.common.url_path?

    # process the jars
    for name, jarOptions of options
      continue if name == 'common'

      jarOptions.vendors ?= []
      jarOptions.js_build_dir = options.common.js_build_dir
      jarOptions.css_build_dir = options.common.css_build_dir
      jarOptions.minify ?= true
      jarOptions.verbose = options.common.verbose

      # merge in the common vendors
      if !jarOptions.common? || jarOptions.common
        jarOptions.vendors = _.union(options.common.vendors, jarOptions.vendors)

      # construct a new named jar
      @jars[name] = jar = new Jar(name, @emitter, options.common.url_path, @production, jarOptions)
      jar.build((err)=>
        @rebuildUrlIndex()
      )

  ###
  express middleware
  ###
  middleWare: (req, res, next) =>
    return next() unless 'GET' == req.method

    urlRoot = @options.common.url_path
    return next() unless req.url.slice(0, urlRoot.length) == urlRoot

    urlPath = req.url.split('/')

    fileExt = urlPath[urlPath.length - 1].split('.')[1]

    # make sure we're responsible for handling this one
    node = @nodeIndex[req.url]
    return next() unless node

    # sugar.info("Blender serve: #{req.url}".blue)

    res.set('Content-Type', node.contentType)
    res.send(node.contents)


  ###
  will it blend?
  ###
  blend: (app, options)->
    # sugar.info("=> Blender")

    @init(options)
      
    # set up view helpers
    app.locals.blenderJs = (name)=>
      @jars[name].jsTags

    app.locals.blenderCss = (name)=>
      @jars[name].cssTags

    # bind the middleware
    app.use(@middleWare)

module.exports = new Blender()








