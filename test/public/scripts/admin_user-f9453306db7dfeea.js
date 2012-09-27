define("main", ["require", "exports", "module"], function(require, exports, module) {
  var test;

test = require('models/test');

test = require('models/hope');

require('templates/temp');

console.log("fire upxdddddddssssssdd");

});define("models/test", ["require", "exports", "module"], function(require, exports, module) {
  
module.exports = function(test) {
  return console.log("testxxdaadddxddd");
};

});define("models/hope", ["require", "exports", "module"], function(require, exports, module) {
  
console.log("good place");

});define("templates/temp", ["require", "exports", "module"], function(require, exports, module) {
  module.exports = Handlebars.template(function (Handlebars,depth0,helpers,partials,data) {
  helpers = helpers || Handlebars.helpers;
  


  return "<b>temp</b>";});
});