// Generated by CoffeeScript 1.6.1
(function() {
  var JarNode, ScriptNode, StyleNode, coffeeScript, death, existsSync, fs, handlebars, nib, path, stylus,
    _this = this,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  path = require('path');

  fs = require('fs');

  coffeeScript = require('coffee-script');

  handlebars = require('handlebars');

  stylus = require('stylus');

  nib = require('nib');

  death = require('./util').death;

  existsSync = fs.existsSync || path.existsSync;

  JarNode = (function() {

    function JarNode() {}

    JarNode.prototype.dependencies = [];

    JarNode.prototype.contents = '';

    JarNode.prototype.outputName = '';

    JarNode.prototype.outputPath = '';

    JarNode.prototype.srcUrl = '';

    JarNode.prototype.type = '';

    return JarNode;

  })();

  module.exports.StyleNode = StyleNode = (function(_super) {

    __extends(StyleNode, _super);

    StyleNode.prototype.contentType = 'text/css';

    /*
    ...
    */


    function StyleNode(production, pathName, rootPath, remote) {
      var ext, file, _ref,
        _this = this;
      this.production = production;
      this.pathName = pathName;
      this.rootPath = rootPath;
      this.remote = remote != null ? remote : false;
      this.compileStylus = function(callback) {
        return StyleNode.prototype.compileStylus.apply(_this, arguments);
      };
      this.type = 'style';
      this.dirName = path.dirname(this.pathName);
      this.baseName = path.basename(this.pathName);
      this.outputPath = this.pathName.replace(this.rootPath, '').replace(this.baseName, '');
      _ref = this.baseName.split('.'), file = _ref[0], ext = _ref[1];
      this.outputName = "" + file + ".css";
    }

    /*
    Rebuild
    */


    StyleNode.prototype.build = function(callback) {
      if (this.remote) {
        this.outputPath = this.pathName;
      } else {
        return this.compileStylus(callback);
      }
      return callback();
    };

    /*
    ...
    */


    StyleNode.prototype.compileStylus = function(callback) {
      var _this = this;
      return fs.readFile(this.pathName, "utf8", function(err, data) {
        if (err) {
          throw err;
        }
        return stylus(data).set('compress', _this.production).set('include css', true).use(nib()).render(function(err, css) {
          if (err) {
            callback(err);
          }
          _this.contents = css;
          _this.waiting = false;
          return callback();
        });
      });
    };

    return StyleNode;

  })(JarNode);

  /*
  Represents an included file and a node within the dependency graph
  */


  module.exports.ScriptNode = ScriptNode = (function(_super) {

    __extends(ScriptNode, _super);

    ScriptNode.prototype.moduleId = "";

    ScriptNode.prototype.remote = false;

    ScriptNode.prototype.modularize = false;

    ScriptNode.prototype.contentType = 'application/javascript';

    /*
    ...
    */


    function ScriptNode(production, pathName, rootPath, modularize, remote) {
      this.production = production;
      this.pathName = pathName;
      this.rootPath = rootPath;
      this.modularize = modularize;
      this.remote = remote != null ? remote : false;
      this.type = 'script';
      this.build();
    }

    /*
    Rebuild
    */


    ScriptNode.prototype.build = function() {
      this.dependencies = [];
      if (this.remote) {
        return this.outputPath = this.pathName;
      } else {
        return this.resolveLocal();
      }
    };

    /*
    The local bizness
    */


    ScriptNode.prototype.resolveLocal = function() {
      var ext, file, _ref;
      if (!existsSync(this.pathName)) {
        death("Missing needed dependency: " + this.pathName);
      }
      this.dirName = path.dirname(this.pathName);
      this.baseName = path.basename(this.pathName);
      this.outputPath = this.pathName.replace(this.rootPath, '').replace(this.baseName, '');
      _ref = this.baseName.split('.'), file = _ref[0], ext = _ref[1];
      this.contents = fs.readFileSync(this.pathName, "utf8");
      switch (ext) {
        case "coffee":
          this.compileCoffeeScript();
          this.parseDependencies();
          if (this.modularize) {
            this.moduleWrap(file);
          }
          return this.outputName = "" + file + ".js";
        case "hbs":
          this.compileHandleBars();
          if (this.modularize) {
            this.moduleWrap(file);
          }
          return this.outputName = "" + file + ".js";
        case "js":
          if (this.modularize) {
            this.moduleWrap(file);
          }
          return this.outputName = "" + file + ".js";
      }
    };

    ScriptNode.prototype.compileHandleBars = function() {
      var content;
      content = handlebars.precompile(this.contents);
      return this.contents = "module.exports = Handlebars.template(" + content + ");";
    };

    ScriptNode.prototype.compileCoffeeScript = function() {
      return this.contents = coffeeScript.compile(this.contents, {
        bare: true
      });
    };

    /*
    Wrap it up in a requirejs AMD compliant define
    Using: simplified CommonJS wrapper
    */


    ScriptNode.prototype.moduleWrap = function(fileName) {
      var cleanPath;
      cleanPath = this.outputPath[0] === '/' ? this.outputPath.slice(1, this.outputPath.length) : this.outputPath;
      this.moduleId = "" + cleanPath + fileName;
      return this.contents = "define(\"" + this.moduleId + "\", [\"require\", \"exports\", \"module\"], function(require, exports, module) {\n  " + this.contents + "\n});";
    };

    /*
    resolve dependencies when including a dir
    */


    ScriptNode.prototype.resolveDirDependency = function(requirePath) {
      var f, files, fullPath, _i, _len, _results;
      files = fs.readdirSync(requirePath);
      _results = [];
      for (_i = 0, _len = files.length; _i < _len; _i++) {
        f = files[_i];
        fullPath = path.join("" + requirePath + "/" + f);
        if (fs.statSync(fullPath).isDirectory()) {
          _results.push(this.resolveDirDependency(fullPath));
        } else {
          _results.push(this.dependencies.push(fullPath));
        }
      }
      return _results;
    };

    /*
    resolve a specific file dependency
    */


    ScriptNode.prototype.resolveFileDependency = function(requirePath) {
      if (existsSync(requirePath)) {
        return this.dependencies.push(requirePath);
      } else {

      }
    };

    ScriptNode.prototype.resolveDependency = function(requireValue) {
      var requirePath, requireValueSplit;
      requireValueSplit = path.basename(requireValue).split('.');
      requirePath = path.join(this.dirName, "" + requireValue);
      if (existsSync(requirePath)) {
        if (fs.statSync(requirePath).isDirectory()) {
          return this.resolveDirDependency(requirePath);
        } else {
          return this.resolveFileDependency(requirePath);
        }
      } else {
        if (requireValueSplit.length === 1) {
          requirePath = path.join(this.dirName, "" + requireValue + ".coffee");
          if (!existsSync(requirePath)) {
            requirePath = path.join(this.dirName, "" + requireValue + ".hbs");
          }
        }
        return this.resolveFileDependency(requirePath);
      }
    };

    /*
    given some javascript script, parse it looking for "requires"
    */


    ScriptNode.prototype.parseDependencies = function() {
      var match, matches, requireValue, _i, _len, _results;
      matches = this.contents.match(/require.*?[\'\"].*?[\'\"]/g);
      if (matches == null) {
        return;
      }
      _results = [];
      for (_i = 0, _len = matches.length; _i < _len; _i++) {
        match = matches[_i];
        requireValue = match.match(/[\'\"].*[\'\"]/g);
        if (requireValue.length !== 1) {
          throw "Invalid require";
        }
        requireValue = requireValue[0].replace(/[\'\"]/g, '');
        _results.push(this.resolveDependency(requireValue));
      }
      return _results;
    };

    return ScriptNode;

  })(JarNode);

}).call(this);
