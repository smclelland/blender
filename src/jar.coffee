path = require('path')
fs = require('fs')
uglify = require("uglify-js")
crypto = require 'crypto'
stylus = require 'stylus'
nib = require 'nib'
async = require 'async'
zlib = require('zlib')
# bower = require('bower')


{ScriptNode} = require('./jarnode')
{StyleNode} = require('./jarnode')

death = require('./util').death
util = require('./util')

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
  build: (callback)->
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

    async.series([
      (callback)=>
        @addVendorDependencies(@options.vendors, callback)

      # set up styles
      (callback)=>
        if @options.style?
          return @addStyleDependency(@options.style, callback) 
        else
          return callback()
      ,
      # build everything
      (callback)=>
        if @production
          if @options.package
            sugar.warn("Common packages are included in #{@name} package") if @options.common

            # merge the two dependency lists together
            packagedDependencies = _.extend(@userDependencies, @vendorDependencies)
            @buildProductionScript(packagedDependencies, "#{@name}_packaged", @options.minify)
          else
            @buildProductionScript(@vendorDependencies, "#{@name}_vendor", @options.minify)
            @buildProductionScript(@userDependencies, "#{@name}_user", @options.minify)
          
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

        return callback()
    ], callback)

  ###
  recursively walk these bitches
  ###
  walkUserDependencies: (node)->
    for dep in node.dependencies

      # check if already visited
      unless @userDependencies[dep]
        node = @addUserDependency(dep)
        @walkUserDependencies(node)

  ###
  ...
  ###
  addStyleDependency: (pathName, callback)->
    sugar.info("add style dep: #{pathName}")
    node = new StyleNode(pathName, @options.dir)
    node.build((err)=>
      return callback(err) if (err)

      @styleDependencies[pathName] = node
      @watch(node)

      return callback()
    )

  ###
  
  ###
  addUserDependency: (pathName)->
    sugar.info("add user dep: #{pathName}")
    node = new ScriptNode(pathName, @options.dir, @modularize)
    @userDependencies[pathName] = node

    @watch(node)
    return node


  ###
  Look for bower ./components  
  # http://sindresorhus.com/bower-components/
  ###
  resolveBowerDependencies: (vendors)->
    results = {}
    bowerDir = path.resolve('./components')

    resolve = (componentJson, checkDependency)->
      # make sure we have this component in our results
      if componentJson._id?
        componentDir = path.join(bowerDir, componentJson.name)
        componentFile = path.join(componentFile, 'component.json')

        # some use an array of main files, use the first one in that case
        mainVal = componentJson.main
        if _.isArray(componentJson.main)
          mainVal = _.first(componentJson.main)

        mainFile = path.join(componentDir, mainVal)
        if @production
          baseName = path.basename(componentJson.main)
          [name, ext] =  baseName.split('.')

          # attempt to use the minified version (if it exists) in production
          mainFileMin = path.join(componentDir, "#{name}-min.#{ext}")
          mainFile = mainFileMin if fs.existsSync(mainFileMin)

        results[componentJson.name] =
          main: mainFile
          dependencies: (k for k of componentJson.dependencies)

      for name, version of componentJson.dependencies
        # try two different path styles (/component and /component.js)
        depComponentFile = path.join(bowerDir, name, 'component.json')
        unless fs.existsSync(depComponentFile)
          death "Missing bower dependency [#{name}] (forgot to add it to ./component.json or 'bower install')"

        depComponentJson = JSON.parse(fs.readFileSync(depComponentFile))

        # verify that this is being included
        if checkDependency
          if (_.indexOf(vendors, name) != -1)
            # recursively resolve subdependency
            resolve(depComponentJson, false)
        else
          resolve(depComponentJson, false)
          
    # use the ./components folder to build up a virtual object that looks like ./component.json
    # this is done becasue the names don't match 1:1
    if fs.existsSync(bowerDir)
      rootComponents =
        dependencies: {}

      for name in fs.readdirSync(bowerDir) when name[0] isnt '.'
        rootComponents.dependencies[name] = null

      resolve(rootComponents, true)
    else
      sugar.warn("No bower components.json found in project root")

    console.log results
    return results

  ###
  ./vendor
  ###
  addVendorDependencies: (vendors, callback)->
    # bowerDependencies = @resolveBowerDependencies(vendors)

    #inject any missing bower dependencies, above the parent, into the vendors list
    # for name, bd of bowerDependencies
    #   for depName in bd.dependencies
    #     parentIndex = _.indexOf(vendors, name)

    #     if _.indexOf(vendors, depName) == -1
    #       vendors.splice(parentIndex, 0, depName)

    for pathName in vendors
      isJs = (pathName.substring(pathName.length - 3, pathName.length) == '.js')
      isRemote = (pathName.substring(0, 7) == "http://")

      modularize = false
      vendorPath = pathName

      # if !isJs && !isRemote
      #   componentName = pathName
      #   bowerComponent = bowerDependencies[componentName]
      #   throw "Could not resolve bower component path: #{componentName}" unless bowerComponent

      #   sugar.info("add vendor bower: #{bowerComponent.main}")
      #   vendorPath = bowerComponent.main

      if !isRemote
        # check for surrounding [] to indicate that it should be modularized
        if pathName[0] == '[' && pathName[pathName.length - 1] == ']'
          vendorPath = pathName.slice(1, pathName.length - 1)
          modularize = true

        vendorPath = path.resolve(vendorPath)

        sugar.info("add vendor local: #{vendorPath}")
      else
        sugar.info("add vendor remote: #{vendorPath}")

      vendorRootPath = path.dirname(vendorPath)

      node = new ScriptNode(vendorPath, vendorRootPath, modularize, isRemote)
      @vendorDependencies[pathName] = node

      @watch(node) unless isRemote

    callback()

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
    ast = pro.ast_mangle(ast)
    ast = pro.ast_squeeze(ast)
    pro.gen_code(ast)


  ###
  fires in the final script which kicks off the entire process
  ###
  buildInitialize: ->
    @jsTagList.push("\n<script>require(\"#{@rootNode.moduleId}\");</script>\n")

  ###
  ..
  ###
  writeProductionFile: (filePath, buffer)->
    err = fs.writeFileSync(path.resolve(filePath), buffer)
    throw err if err

    # store a gzipped version of the file alongside
    zlib.gzip(buffer, (err,result)->
      fs.writeFile(path.resolve("#{filePath}.gz"), result, (err) ->
        throw err if err
      )
    )

  ###
  builds the production files
  ###
  buildProductionStyle: (dependencies, description)->
    buffer = ''

    for key, node of dependencies
      # remote files are simple URLs, otherwise buffer up the content
      if node.remote
        @cssTagList.push("\n<link rel=\"stylesheet\" href=\"#{key}\" type=\"text/css\" media=\"screen\">")
      else
        buffer += node.contents

    if buffer.length > 0
      hash = @hashContents(buffer)

      fileName = "#{description}-#{hash}.css"
      @cssTagList.push("\n<link rel=\"stylesheet\" href=\"#{@urlRoot}/styles/#{fileName}\" type=\"text/css\" media=\"screen\">")

      # make sure the dir exists
      fs.mkdirSync(@options.css_build_dir) unless fs.existsSync(@options.css_build_dir)
      filePath = path.join(@options.css_build_dir, fileName)

      @writeProductionFile(filePath, buffer)

  ###
  builds the production files
  ###
  buildProductionScript: (dependencies, description, minify = false)->
    localNodes = []

    for key, node of dependencies
      # remote files are simple URLs, otherwise buffer up the content
      if node.remote
        @jsTagList.push("\n<script type=\"text/javascript\" src=\"#{key}\"></script>")
      else
        # node.contents = ''
        # console.log node
        localNodes.push(node)

    if localNodes.length > 0
      buffer = ''

      for node in localNodes
        # skip minification if it already contains ".min" in the name
        if node.pathName.search('.min') == -1 && minify
          buffer += @minify(node.contents)
        else
          buffer += node.contents

      hash = @hashContents(buffer)

      fileName = "#{description}-#{hash}.js"
      @jsTagList.push("\n<script type=\"text/javascript\" src=\"#{@urlRoot}/scripts/#{fileName}\"></script>")

      fs.mkdirSync(@options.js_build_dir) unless fs.existsSync(@options.js_build_dir)
      filePath = path.join(@options.js_build_dir, fileName)

      @writeProductionFile(filePath, buffer)


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



