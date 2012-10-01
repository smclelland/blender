path = require('path')
fs = require('fs')
uglify = require("uglify-js")
crypto = require 'crypto'
stylus = require 'stylus'
nib = require 'nib'
async = require 'async'

{ScriptNode} = require('./jarnode')
{StyleNode} = require('./jarnode')

death = require('./util').death

###
graph made with an adjacency list
### 
module.exports = class Jar
  rootNode           : null
  styleDependencies  : {}
  userDependencies   : {}  # adjacency list for the dependency graph
  vendorDependencies : {}  # adjacency list for the dependency graph
  jsTagList          : []  # list of final tags <script...
  cssTagList         : []  # list of final tags <script...
  nodeIndex          : {}  # index for fast node lookup during dev mod
  vendors            : []
  modularize         : true
  watchList          : []

  constructor: (@name, @emitter, @urlRoot, @production, @options)->

    options.dir   = path.resolve(options.dir)
    options.main  = path.join(options.dir, "#{options.main}.coffee")

    if options.style?
      options.style = path.join(options.dir, "#{options.style}.styl")
      death "Missing main style sheet: #{options.style}" unless fs.existsSync(options.style)

    death "Missing main: #{options.main}" unless fs.existsSync(options.main)

    # listen for jar changes and additions
    @emitter.on('change', (jar, node)=>@onChange(jar, node))




  ###
  main build process
  ###
  build: ->
    startTime = new Date().getTime()
  
    # clean out
    @styleDependencies = {}
    @userDependencies = {}
    @vendorDependencies = {}
    @jsTagList = []
    @cssTagList = []
    @nodeIndex = []

    @unwatchAll()

    # rebuild
    @rootNode = @addUserDependency(@options.main)
    @walkUserDependencies(@rootNode)

    for v in @options.vendors
      @addVendorDependency(v)

    async.series([
      (callback)=>
        @addStyleDependency(@options.style, callback) if @options.style?
      ,
      (callback)=>
        if @production
          if @options.package
            sugar.warn("Common packages are included in #{@name} package") if @options.common

            # merge the two dependency lists together
            packagedDependencies = _.extend(@userDependencies, @vendorDependencies)
            @buildProduction(packagedDependencies, "#{@name}_packaged", @options.minify)
          else
            @buildProduction(@vendorDependencies, "#{@name}_vendor", false)
            @buildProduction(@userDependencies, "#{@name}_user", @options.minify)
          
          @buildProductionStyle(@styleDependencies, 'style')

        else
          @buildDevelopment(@jsTagList, @vendorDependencies, 'vendor')
          @buildDevelopment(@jsTagList, @userDependencies, 'user')
          @buildDevelopment(@cssTagList, @styleDependencies, 'style')


        @buildInitialize()

        # cache up the final tags
        @jsTags = @jsTagList.join('')
        @cssTags = @cssTagList.join('')

        endTime = new Date().getTime()
        sugar.info("Blender rebuild [#{@name}]: ".blue, "#{(endTime - startTime)}ms".grey)
    ])


  ###
  recursively walk these bitches
  ###
  walkUserDependencies: (node)->
    for dep in node.dependencies

      # check if already visited
      unless @userDependencies[dep]
        node = @addUserDependency(dep)
        @walkUserDependencies(node)

  addStyleDependency: (pathName, callback)->
    sugar.info("add style dep: #{pathName}")
    node = new StyleNode(pathName, @options.dir)
    node.build((err)=>
      @styleDependencies[pathName] = node
      @watch(node)
      callback(err)
    )
    return node

  ###
  
  ###
  addUserDependency: (pathName)->
    sugar.info("add user dep: #{pathName}")
    node = new ScriptNode(pathName, @options.dir, @modularize)
    @userDependencies[pathName] = node

    @watch(node)
    return node

  ###
  ./vendor
  ###
  addVendorDependency: (pathName)->
    # support remote vendor urls
    remote = (pathName.substring(0, 7) == "http://")
    modularize = false
    vendorPath = pathName

    unless remote
      # check for surrounding [] to indicate that it should be modularized
      if pathName[0] == '[' && pathName[pathName.length - 1] == ']'
        vendorPath = pathName.slice(1, pathName.length - 1)
        modularize = true

      vendorPath = path.resolve(vendorPath)
      vendorRootPath = path.dirname(vendorPath)

    node = new ScriptNode(vendorPath, vendorRootPath, modularize, remote)
    @vendorDependencies[pathName] = node

    @watch(node) unless remote

    return node

  ###
  make a nice MD5 hash for the file names in production
  ###
  hashContents: (contents)->
    sum = crypto.createHash('sha1')
    sum.update(contents)

    # only preserve 16 chars (should be enough uniqueness)
    return sum.digest('hex').substring(16, 0)

  ###
  uglify that crap for prod
  ###
  minify: (buffer)->
    jsp = uglify.parser
    pro = uglify.uglify

    ast = jsp.parse(buffer)

    # todo: these push it further... needs playing around with
    # ast = pro.ast_mangle(ast)
    # ast = pro.ast_squeeze(ast)
    pro.gen_code(ast)


  ###
  fires in the final script which kicks off the entire process
  ###
  buildInitialize: ->
    @jsTagList.push("\n<script>require(\"#{@rootNode.moduleId}\");</script>\n")

  buildProductionStyle: (dependencies, description)->

    buffer = ''
    for key, node of dependencies
      sugar.info("CONTENTS")
      sugar.info(node.contents)

      if node.remote
        @cssTagList.push("\n<link rel=\"stylesheet\" href=\"#{key}\" type=\"text/css\" media=\"screen\">")
      else
        buffer += node.contents

    if buffer.length > 0
      hash = @hashContents(buffer)

      fileName = "#{description}-#{hash}.css"
      @cssTagList.push("\n<link rel=\"stylesheet\" href=\"#{@urlRoot}/#{fileName}\" type=\"text/css\" media=\"screen\">")

      filePath = path.join(@options.js_build_dir, fileName)

      fs.writeFile(path.resolve(filePath), buffer, (err) ->
        throw err if err
        sugar.info("Blender write production: #{description}".blue)
      )


  ###
  builds the production files
  ###
  buildProduction: (dependencies, description, minify = false)->
    buffer = ''

    for key, node of dependencies
      if node.remote
        @jsTagList.push("\n<script type=\"text/javascript\" src=\"#{key}\"></script>")
      else
        buffer += node.contents

    if buffer.length > 0
      buffer = @minify(buffer) if minify
      hash = @hashContents(buffer)

      fileName = "#{description}-#{hash}.js"
      @jsTagList.push("\n<script type=\"text/javascript\" src=\"#{@urlRoot}/#{fileName}\"></script>")

      filePath = path.join(@options.js_build_dir, fileName)

      fs.writeFile(path.resolve(filePath), buffer, (err) ->
        throw err if err
        sugar.info("Blender write production: #{description}".blue)
      )


  ###
  builds up the script tags
  ###
  buildDevelopment: (tagList, dependencies, description)->
    tagList.push("\n<!-- blender #{description}-->")

    for name, node of dependencies
      # support url pass-through
      if node.remote
        src = node.outputPath
      else
        src = path.join(@urlRoot, @name, node.outputPath, node.outputName)

      switch node.type
        when 'script' then tagList.push("\n<script type=\"text/javascript\" src=\"#{src}\"></script>")
        when 'style'  then tagList.push("\n<link rel=\"stylesheet\" href=\"#{src}\" type=\"text/css\" media=\"screen\">")
        else 
          death('unknown node type')

      # keep an index of locals around for quick lookups
      @nodeIndex[src] = node unless node.remote

    tagList.push("\n<!-- end blender #{#{description}} -->\n")


  ###
  when a file change event happens, rebuild the entire tree
  sub-optimal but, good enough for now
  ###
  onChange: (jar, node)->
    @build()
    @emitter.emit('jar_rebuild', this, node)

  ###
  unwatcher
  ###
  unwatchAll: ->
    for f in @watchList
      fs.unwatchFile(f)

    @watchList = []

  ###
  watcher watcher
  ###
  watch: (node)->
    options = { persistent: @options.persistent }

    @watchList.push(node.pathName)

    options.interval = 100
    fs.watchFile(node.pathName, options, (curr, prev) =>
      @emitter.emit('change', this, node)  if curr.mtime.getTime() isnt prev.mtime.getTime()
    )

    @emitter.emit('add', this, node)






