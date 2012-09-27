###
Helper to show easier to read exceptions
###
module.exports.death = (msg)->
  sugar.error("Blender: #{msg}".red)
  throw('--')
