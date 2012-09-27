http = require("http")
path = require("path")
stylus = require 'stylus'
express = require("express")
blender = require("../src/blender")
buffertolls = require('buffertools')
nib = require("nib")

app = express()
app.configure ->

  app.set "port", process.env.PORT or 3000
  app.set "views", "./app/views"
  app.set "view engine", "jade"

  # app.use(stylus.middleware(
  #   src: __dirname + '/app_admin/styles'
  #   dest: __dirname + '/public'
  #   compile: (str, path)->
  #     return stylus(str).set('filename', path).use(nib())
  #   )
  # )

  ###
  Fire up the blender
  ###
  blender.blend app,     
    common:
      host: '/scripts'
      build_dir: './test/public'
      vendors: [
        # use cdn
        'http://code.jquery.com/jquery-1.8.2.min.js' 
        './vendor/jquery.js'
        './vendor/almond.js'
        './vendor/handlebars.js'
      ]
    admin: # namespace
      dir: './test/app_admin'
      main: 'main'
      style: 'styles/main'
      vendors: [
        # './vendor/xyz.js'
      ]

  app.use express.favicon()
  app.use express.logger("dev")
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use express.static("#{__dirname}/public")
  app.use app.router

# pretty print template output
app.locals.pretty = true

app.configure "development", ->
  app.use express.errorHandler()

app.configure "production", ->
  app.use express.errorHandler()

app.get("/", (req, res)->
  res.render("#{__dirname}/app/index.jade",
    layout: false
  )
)

app.on "listening", =>
  console.log "listening"


http.createServer(app).listen(app.get("port"), @listener)