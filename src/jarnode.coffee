path = require('path')
fs = require('fs')

coffeeScript = require('coffee-script')
handlebars = require 'handlebars'
stylus = require 'stylus'
nib = require 'nib'
death = require('./util').death

class JarNode
  dependencies   : []
  contents       : '' # compiled content
  outputName     : '' # final file name x.js
  outputPath     : '' # virtual path to use to serve files /whatever/
  srcUrl         : ''
  type           : ''


module.exports.StyleNode = class StyleNode extends JarNode
  contentType    : 'text/css'

  ###
  ...
  ###
  constructor: (@pathName, @rootPath, @remote = false)->
    @type = 'style'
    @dirName = path.dirname(@pathName)
    @baseName = path.basename(@pathName)
    @outputPath = @pathName.replace(@rootPath, '').replace(@baseName, '')

    [file, ext] = @baseName.split('.')
    @outputName = "#{file}.css"

  ###
  Rebuild
  ###
  build: (callback)->
    if @remote
      @outputPath = @pathName
    else
      return @compileStylus(callback)

    return callback()

  ###
  ...
  ###
  compileStylus: (callback)=>
    fs.readFile(@pathName, "utf8", (err, data)=>
      throw err if (err)

      stylus(data)
        .set('compress', @production)
        # .set('linenos', true)
        .use(nib())
        .render((err, css)=>
          callback(err) if (err)
          @contents = css

          @waiting = false
          return callback()
        )
    )


###
Represents an included file and a node within the dependency graph
###
module.exports.ScriptNode = class ScriptNode extends JarNode
  moduleId       : "" # way to identify the AMD modules
  remote         : false
  modularize     : false
  contentType    : 'application/javascript'

  ###
  ...
  ###
  constructor: (@pathName, @rootPath, @modularize, @remote = false)->
    @type = 'script'
    @build()

  ###
  Rebuild
  ###
  build: ->
    @dependencies = []

    if @remote
      @outputPath = @pathName
    else
      @resolveLocal()

  ###
  The local bizness
  ###
  resolveLocal: ->
    death "Missing needed dependency: #{@pathName}" unless fs.existsSync(@pathName)

    @dirName = path.dirname(@pathName)
    @baseName = path.basename(@pathName)
    @outputPath = @pathName.replace(@rootPath, '').replace(@baseName, '')

    # sugar.line
    # sugar.info("> pathName: #{@pathName}")
    # sugar.info("> dirName: #{@dirName}")
    # sugar.info("> rootPath: #{@rootPath}")
    # sugar.info("> outputPath: #{@outputPath}\n")

    # console.log "rootPath: => #{@rootPath}"
    # console.log "pathName: => #{@pathName}"
    # console.log "baseName: => #{@baseName}"
    # console.log "outputPath: => #{@outputPath}\n\n"

    [file, ext] = @baseName.split('.')

    @contents = fs.readFileSync(@pathName, "utf8")

    switch ext
      when "coffee"
        # compile it first, this makes commenting of require statements possible
        @compileCoffeeScript()
        @parseDependencies()
        @moduleWrap(file) if @modularize
        @outputName = "#{file}.js"

      when "hbs"
        @compileHandleBars()
        
        @moduleWrap(file) if @modularize
        @outputName = "#{file}.js"

      when "js"
        @moduleWrap(file) if @modularize
        @outputName = "#{file}.js"


  compileHandleBars: ->
    content = handlebars.precompile(@contents)
    # "\nEmber.TEMPLATES[module.id] = Ember.Handlebars.template(#{content});\n module.exports = module.id;"
    @contents = "module.exports = Handlebars.template(#{content});"

  compileCoffeeScript: ->
    @contents = coffeeScript.compile(@contents, bare: yes)


  ###
  Wrap it up in a requirejs AMD compliant define
  Using: simplified CommonJS wrapper
  ###
  moduleWrap: (fileName)->
    # path may need cleanup to result in xxxx/
    cleanPath = if @outputPath[0] == '/' then @outputPath.slice(1, @outputPath.length) else @outputPath
    @moduleId = "#{cleanPath}#{fileName}"
    @contents = """
      define("#{@moduleId}", ["require", "exports", "module"], function(require, exports, module) {
        #{@contents}
      });
    """

  ###
  resolve dependencies when including a dir
  ###
  resolveDirDependency: (requirePath)->

    # an entire dir dependency
    files = fs.readdirSync(requirePath)

    for f in files
      fullPath = path.join("#{requirePath}/#{f}")

      # if we're dealing with a dir, dig in
      if fs.statSync(fullPath).isDirectory()
        @resolveDirDependency(fullPath)
      else
        @dependencies.push(fullPath)

  ###
  resolve a specific file dependency
  ###
  resolveFileDependency: (requirePath)->
    # support reading in a single folder of dependencies (only one level deep)
    if fs.existsSync(requirePath)

      # single file dependency
      @dependencies.push(requirePath)
    else
      sugar.error("\n** Can not resolve require dependency in: [#{requirePath}] **\n")


  resolveDependency: (requireValue)->
    requireValueSplit = path.basename(requireValue).split('.')
    requirePath = path.join(@dirName, "#{requireValue}")

    if fs.existsSync(requirePath)
      if fs.statSync(requirePath).isDirectory()
        @resolveDirDependency(requirePath)
      else
        @resolveFileDependency(requirePath)

    else
      # make an assumption that we want to include coffee script
      if requireValueSplit.length == 1
        requirePath = path.join(@dirName, "#{requireValue}.coffee")

        unless fs.existsSync(requirePath)
          requirePath = path.join(@dirName, "#{requireValue}.hbs")

      @resolveFileDependency(requirePath)


  ###
  given some javascript script, parse it looking for "requires"
  ###
  parseDependencies: ->

    # look for require(...) or require '' etc and extract the value
    matches = @contents.match(/require.*?[\'\"].*?[\'\"]/g)
    return unless matches?

    for match in matches
      requireValue = match.match(/[\'\"].*[\'\"]/g)
      throw "Invalid require" if requireValue.length != 1

      # strip off the quotes
      requireValue      = requireValue[0].replace(/[\'\"]/g, '')

      @resolveDependency(requireValue)
