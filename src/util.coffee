###
Helper to show easier to read exceptions
###
module.exports.death = (msg)->
  # sugar.error("Blender: #{msg}".red)
  throw(msg)

module.exports.homeDir = ->
  process.env[(if (process.platform == 'win32') then 'USERPROFILE' else 'HOME')]