fs            = require 'fs'
path          = require 'path'
util          = require 'util'
{print}       = require 'util'
{spawn, exec} = require 'child_process'

package_name = 'blender'

execute = (cmd) ->
  e = exec cmd
  e.stdout.on 'data', (data) -> print data.toString()
  e.stderr.on 'data', (data) -> print data.toString()

build = (watch = false) ->
  print "#{package_name}: building for "
  
  cmd = "coffee -c"

  if process.env.NODE_ENV? and process.env.NODE_ENV is 'production'
    print "#{process.env.NODE_ENV}\n"
  else
    print "development\n"
    
  cmd += " -w" if watch
  cmd += " -o 'lib' 'src'"
  
  execute(cmd)

#run = (debug) ->
#  build(true)
#
#  nodemon_options = ['./lib/app.js']
#  nodemon_options.push('--debug') if debug
#  nodemon = spawn 'nodemon', nodemon_options
#  nodemon.stdout.on 'data', (data) -> print data.toString()
#  nodemon.stderr.on 'data', (data) -> print data.toString()

task 'install', 'Installs and configures everything the server needs', ->
  # print "#{server_name} -> install\n"

  install_options = ['install']
  npm = spawn 'npm', install_options
  npm.stdout.on 'data', (data) -> print data.toString()
  npm.stderr.on 'data', (data) -> print data.toString()

task 'build', 'Compile CoffeeScript source files', ->
  print "#{package_name} build\n"
  build()

task 'test', 'Compile CoffeeScript source files', ->
  print "#{package_name} test\n"

  cmd = "nodemon ./test/app.coffee"
  execute(cmd)

#  coffee -o ./lib -c -w ./src &
#  NODE_ENV=debug nodemon ./lib/app.js
#task 'run', 'Run the server', ->
#  print "#{package_name} run\n"
#  run(false)

#task 'test', 'Run the test suite', ->
#  build ->
#    require.paths.unshift __dirname + "/lib"
    #{reporters} = require 'nodeunit'
    #process.chdir __dirname
    #reporters.default.run ['test']
