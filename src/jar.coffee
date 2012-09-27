path = require('path')
fs = require('fs')
uglify = require("uglify-js")
crypto = require 'crypto'
stylus = require 'stylus'
nib = require 'nib'

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

    @addStyleDependency(@options.style)

    if @production
      # @buildProduction(@vendorDependencies, 'vendor')
      # @buildProduction(@userDependencies, 'user', true)
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

  ###
  recursively walk these bitches
  ###
  walkUserDependencies: (node)->
    for dep in node.dependencies

      # check if already visited
      unless @userDependencies[dep]
        node = @addUserDependency(dep)
        @walkUserDependencies(node)

  addStyleDependency: (pathName)->
    sugar.info("add style dep: #{pathName}")
    node = new StyleNode(pathName, @options.dir)
    @styleDependencies[pathName] = node

    @watch(node)
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

      # sugar.warn("#{vendorPath}")
      # sugar.warn("#{vendorRootPath}")

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

  ###
  builds the production files
  ###
  buildProduction: (dependencies, description, minify = false)->
    buffer = ''
    for k, node of dependencies
      buffer += "\n/* #{node.outputName} */\n #{s.contents}"

    buffer = @minify(buffer) if minify

    hash = @hashContents(buffer)
    fileName = "#{description}-#{hash}.js"
    filePath = path.join(@buildPath, fileName)


    fs.writeFile(path.resolve(filePath), buffer, (err) ->
      throw err if err
      sugar.info("Blender write production: #{description}".blue)
    )

    src = "#{@buildHost}/#{fileName}"
    @jsTagList.push("\n<script type=\"text/javascript\" src=\"#{src}\"></script>")


  ###
  builds up the script tags
  ###
  buildDevelopment: (tagList, dependencies, description)->
    # tagList.push("\n<!-- blender #{description}-->")

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

    # tagList.push("\n<!-- end blender #{#{description}} -->\n")


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

    options.interval = 100
    @watchList.push(node.pathName)
    fs.watchFile(node.pathName, options, (curr, prev) =>
      if curr.mtime.getTime() isnt prev.mtime.getTime()
        @emitter.emit('change', this, node) 
    )

    @emitter.emit('add', this, node)
