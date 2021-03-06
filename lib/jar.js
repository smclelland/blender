// Generated by CoffeeScript 1.6.1
(function() {
  var Jar, ScriptNode, StyleNode, async, crypto, death, existsSync, fs, nib, path, stylus, uglify, util, zlib;

  path = require('path');

  fs = require('fs');

  uglify = require("uglify-js");

  crypto = require('crypto');

  stylus = require('stylus');

  nib = require('nib');

  async = require('async');

  zlib = require('zlib');

  existsSync = fs.existsSync || path.existsSync;

  ScriptNode = require('./jarnode').ScriptNode;

  StyleNode = require('./jarnode').StyleNode;

  death = require('./util').death;

  util = require('./util');

  /*
  graph made with an adjacency list
  */


  module.exports = Jar = (function() {

    Jar.prototype.rootNode = null;

    Jar.prototype.styleDependencies = {};

    Jar.prototype.userDependencies = {};

    Jar.prototype.vendorDependencies = {};

    Jar.prototype.jsTagList = [];

    Jar.prototype.cssTagList = [];

    Jar.prototype.nodeIndex = {};

    Jar.prototype.vendors = [];

    Jar.prototype.modularize = false;

    Jar.prototype.watchList = [];

    function Jar(name, emitter, urlRoot, production, options) {
      var _this = this;
      this.name = name;
      this.emitter = emitter;
      this.urlRoot = urlRoot;
      this.production = production;
      this.options = options;
      options.dir = path.resolve(options.dir);
      options.main = path.join(options.dir, "" + options.main + ".coffee");
      if (options.style != null) {
        options.style = path.join(options.dir, "" + options.style + ".styl");
        if (!existsSync(options.style)) {
          death("Missing main style sheet: " + options.style);
        }
      }
      if (!existsSync(options.main)) {
        death("Missing main: " + options.main);
      }
      this.emitter.on('change', function(jar, node) {
        return _this.onChange(jar, node);
      });
    }

    /*
    main build process
    */


    Jar.prototype.build = function(callback) {
      var startTime,
        _this = this;
      startTime = new Date().getTime();
      this.styleDependencies = {};
      this.userDependencies = {};
      this.vendorDependencies = {};
      this.jsTagList = [];
      this.cssTagList = [];
      this.nodeIndex = [];
      this.unwatchAll();
      this.rootNode = this.addUserDependency(this.options.main);
      this.walkUserDependencies(this.rootNode);
      return async.series([
        function(callback) {
          return _this.addVendorDependencies(_this.options.vendors, callback);
        }, function(callback) {
          if (_this.options.style != null) {
            return _this.addStyleDependency(_this.options.style, callback);
          } else {
            return callback();
          }
        }, function(callback) {
          var endTime, packagedDependencies;
          if (_this.production) {
            if (_this.options["package"]) {
              packagedDependencies = _.extend(_this.userDependencies, _this.vendorDependencies);
              _this.buildProductionScript(packagedDependencies, "" + _this.name + "_packaged", _this.options.minify);
            } else {
              _this.buildProductionScript(_this.vendorDependencies, "" + _this.name + "_vendor", _this.options.minify);
              _this.buildProductionScript(_this.userDependencies, "" + _this.name + "_user", _this.options.minify);
            }
            _this.buildProductionStyle(_this.styleDependencies, 'style');
          } else {
            _this.buildDevelopment(_this.jsTagList, _this.vendorDependencies, 'vendor');
            _this.buildDevelopment(_this.jsTagList, _this.userDependencies, 'user');
            _this.buildDevelopment(_this.cssTagList, _this.styleDependencies, 'style');
          }
          _this.buildInitialize();
          _this.jsTags = _this.jsTagList.join('');
          _this.cssTags = _this.cssTagList.join('');
          endTime = new Date().getTime();
          return callback();
        }
      ], callback);
    };

    /*
    recursively walk these bitches
    */


    Jar.prototype.walkUserDependencies = function(node) {
      var dep, _i, _len, _ref, _results;
      _ref = node.dependencies;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        dep = _ref[_i];
        if (!this.userDependencies[dep]) {
          node = this.addUserDependency(dep);
          _results.push(this.walkUserDependencies(node));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    Jar.prototype.log = function(msg) {};

    /*
    ...
    */


    Jar.prototype.addStyleDependency = function(pathName, callback) {
      var node,
        _this = this;
      this.log("add style dep: " + pathName);
      node = new StyleNode(this.production, pathName, this.options.dir);
      return node.build(function(err) {
        if (err) {
          return callback(err);
        }
        _this.styleDependencies[pathName] = node;
        _this.watch(node);
        return callback();
      });
    };

    /*
    */


    Jar.prototype.addUserDependency = function(pathName) {
      var node;
      this.log("add user dep: " + pathName);
      node = new ScriptNode(this.production, pathName, this.options.dir, this.modularize);
      this.userDependencies[pathName] = node;
      this.watch(node);
      return node;
    };

    /*
    Look for bower ./components  
    # http://sindresorhus.com/bower-components/
    */


    Jar.prototype.resolveBowerDependencies = function(vendors) {
      var bowerDir, name, resolve, results, rootComponents, _i, _len, _ref;
      results = {};
      bowerDir = path.resolve('./components');
      resolve = function(componentJson, checkDependency) {
        var baseName, componentDir, componentFile, depComponentFile, depComponentJson, ext, k, mainFile, mainFileMin, mainVal, name, version, _ref, _ref1, _results;
        if (componentJson._id != null) {
          componentDir = path.join(bowerDir, componentJson.name);
          componentFile = path.join(componentFile, 'component.json');
          mainVal = componentJson.main;
          if (_.isArray(componentJson.main)) {
            mainVal = _.first(componentJson.main);
          }
          mainFile = path.join(componentDir, mainVal);
          if (this.production) {
            baseName = path.basename(componentJson.main);
            _ref = baseName.split('.'), name = _ref[0], ext = _ref[1];
            mainFileMin = path.join(componentDir, "" + name + "-min." + ext);
            if (existsSync(mainFileMin)) {
              mainFile = mainFileMin;
            }
          }
          results[componentJson.name] = {
            main: mainFile,
            dependencies: (function() {
              var _results;
              _results = [];
              for (k in componentJson.dependencies) {
                _results.push(k);
              }
              return _results;
            })()
          };
        }
        _ref1 = componentJson.dependencies;
        _results = [];
        for (name in _ref1) {
          version = _ref1[name];
          depComponentFile = path.join(bowerDir, name, 'component.json');
          if (!existsSync(depComponentFile)) {
            death("Missing bower dependency [" + name + "] (forgot to add it to ./component.json or 'bower install')");
          }
          depComponentJson = JSON.parse(fs.readFileSync(depComponentFile));
          if (checkDependency) {
            if (_.indexOf(vendors, name) !== -1) {
              _results.push(resolve(depComponentJson, false));
            } else {
              _results.push(void 0);
            }
          } else {
            _results.push(resolve(depComponentJson, false));
          }
        }
        return _results;
      };
      if (existsSync(bowerDir)) {
        rootComponents = {
          dependencies: {}
        };
        _ref = fs.readdirSync(bowerDir);
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          name = _ref[_i];
          if (name[0] !== '.') {
            rootComponents.dependencies[name] = null;
          }
        }
        resolve(rootComponents, true);
      } else {

      }
      console.log(results);
      return results;
    };

    /*
    ./vendor
    */


    Jar.prototype.addVendorDependencies = function(vendors, callback) {
      var isJs, isRemote, modularize, node, pathName, vendorPath, vendorRootPath, _i, _len;
      for (_i = 0, _len = vendors.length; _i < _len; _i++) {
        pathName = vendors[_i];
        isJs = pathName.substring(pathName.length - 3, pathName.length) === '.js';
        isRemote = pathName.substring(0, 7) === "http://";
        modularize = false;
        vendorPath = pathName;
        if (!isRemote) {
          if (pathName[0] === '[' && pathName[pathName.length - 1] === ']') {
            vendorPath = pathName.slice(1, pathName.length - 1);
            modularize = true;
          }
          vendorPath = path.resolve(vendorPath);
          this.log("add vendor local: " + vendorPath);
        } else {
          this.log("add vendor remote: " + vendorPath);
        }
        vendorRootPath = path.dirname(vendorPath);
        node = new ScriptNode(this.production, vendorPath, vendorRootPath, modularize, isRemote);
        this.vendorDependencies[pathName] = node;
        if (!isRemote) {
          this.watch(node);
        }
      }
      return callback();
    };

    /*
    make a nice MD5 hash for the file names in production
    */


    Jar.prototype.hashContents = function(contents) {
      var sum;
      sum = crypto.createHash('sha1');
      sum.update(contents);
      return sum.digest('hex').substring(16, 0);
    };

    /*
    uglify that crap for prod
    */


    Jar.prototype.minify = function(buffer) {
      return uglify.minify(buffer, {
        fromString: true
      }).code;
    };

    /*
    fires in the final script which kicks off the entire process
    */


    Jar.prototype.buildInitialize = function() {
      return this.jsTagList.push("\n<script>require(\"" + this.rootNode.moduleId + "\");</script>\n");
    };

    /*
    ..
    */


    Jar.prototype.writeProductionFile = function(filePath, buffer) {
      var err;
      err = fs.writeFileSync(path.resolve(filePath), buffer);
      if (err) {
        throw err;
      }
      return zlib.gzip(buffer, function(err, result) {
        return fs.writeFile(path.resolve("" + filePath + ".gz"), result, function(err) {
          if (err) {
            throw err;
          }
        });
      });
    };

    /*
    builds the production files
    */


    Jar.prototype.buildProductionStyle = function(dependencies, description) {
      var buffer, fileName, filePath, hash, key, node;
      buffer = '';
      for (key in dependencies) {
        node = dependencies[key];
        if (node.remote) {
          this.cssTagList.push("\n<link rel=\"stylesheet\" href=\"" + key + "\" type=\"text/css\" media=\"screen\">");
        } else {
          buffer += node.contents;
        }
      }
      if (buffer.length > 0) {
        hash = this.hashContents(buffer);
        fileName = "" + description + "-" + hash + ".css";
        this.cssTagList.push("\n<link rel=\"stylesheet\" href=\"" + this.urlRoot + "/styles/" + fileName + "\" type=\"text/css\" media=\"screen\">");
        if (!existsSync(this.options.css_build_dir)) {
          fs.mkdirSync(this.options.css_build_dir);
        }
        filePath = path.join(this.options.css_build_dir, fileName);
        return this.writeProductionFile(filePath, buffer);
      }
    };

    /*
    builds the production files
    */


    Jar.prototype.buildProductionScript = function(dependencies, description, minify) {
      var buffer, fileName, filePath, hash, key, localNodes, node, _i, _len;
      if (minify == null) {
        minify = false;
      }
      localNodes = [];
      for (key in dependencies) {
        node = dependencies[key];
        if (node.remote) {
          this.jsTagList.push("\n<script type=\"text/javascript\" src=\"" + key + "\"></script>");
        } else {
          localNodes.push(node);
        }
      }
      if (localNodes.length > 0) {
        buffer = '';
        for (_i = 0, _len = localNodes.length; _i < _len; _i++) {
          node = localNodes[_i];
          if (node.pathName.search('.min') === -1 && minify) {
            buffer += this.minify(node.contents);
          } else {
            buffer += node.contents;
          }
        }
        hash = this.hashContents(buffer);
        fileName = "" + description + "-" + hash + ".js";
        this.jsTagList.push("\n<script type=\"text/javascript\" src=\"" + this.urlRoot + "/scripts/" + fileName + "\"></script>");
        if (!existsSync(this.options.js_build_dir)) {
          fs.mkdirSync(this.options.js_build_dir);
        }
        filePath = path.join(this.options.js_build_dir, fileName);
        return this.writeProductionFile(filePath, buffer);
      }
    };

    /*
    builds up the script tags
    */


    Jar.prototype.buildDevelopment = function(tagList, dependencies, description) {
      var name, node, src;
      tagList.push("\n<!-- blender " + description + "-->");
      for (name in dependencies) {
        node = dependencies[name];
        if (node.remote) {
          src = node.outputPath;
        } else {
          src = path.join(this.urlRoot, this.name, node.outputPath, node.outputName);
        }
        switch (node.type) {
          case 'script':
            tagList.push("\n<script type=\"text/javascript\" src=\"" + src + "\"></script>");
            break;
          case 'style':
            tagList.push("\n<link rel=\"stylesheet\" href=\"" + src + "\" type=\"text/css\" media=\"screen\">");
            break;
          default:
            death('unknown node type');
        }
        if (!node.remote) {
          this.nodeIndex[src] = node;
        }
      }
      return tagList.push("\n<!-- end blender " + " -->\n");
    };

    /*
    when a file change event happens, rebuild the entire tree
    sub-optimal but, good enough for now
    */


    Jar.prototype.onChange = function(jar, node) {
      var _this = this;
      return this.build(function(err) {
        return _this.emitter.emit('jar_rebuild', _this, node);
      });
    };

    /*
    unwatcher
    */


    Jar.prototype.unwatchAll = function() {
      var f, _i, _len, _ref;
      _ref = this.watchList;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        f = _ref[_i];
        fs.unwatchFile(f);
      }
      return this.watchList = [];
    };

    /*
    watcher watcher
    */


    Jar.prototype.watch = function(node) {
      var options,
        _this = this;
      options = {
        persistent: this.options.persistent
      };
      this.watchList.push(node.pathName);
      options.interval = 100;
      fs.watchFile(node.pathName, options, function(curr, prev) {
        if (curr.mtime.getTime() !== prev.mtime.getTime()) {
          return _this.emitter.emit('change', _this, node);
        }
      });
      return this.emitter.emit('add', this, node);
    };

    return Jar;

  })();

}).call(this);
