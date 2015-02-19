part of plugins.loader;

class Pub {
  
  final Map<String, _PubHost> _hosts;

  /**
   * [cache] is the path to the cache directory. The default being
   * the retrieved path from cacheDir()
   */
  factory Pub() {
    var hosts = _PubHost.resolveAllHosts();
    return new Pub._internal(hosts);
  }
  
  Pub._internal(this._hosts);

  /**
   * Resolves a hosted package.
   */
  PluginLoader resolveHosted(String name, String hostName) {
    var host = _hosts[hostName];
    if (host == null)
      throw new Exception("Unable to resolve pub cache host: $host");
    var depend = new _Dependency(name, host);
    return depend.resolve();
  }
  
  static String hostedCacheDir() {
    var path = baseCacheDir();
    return Path.join(path, "hosted");
  }
  
  static String baseCacheDir() {
    var path;
    var home = Platform.environment['PUB_CACHE'];
    if (home != null) {
      path = home;
    } else if (Platform.isWindows) {
      home = Platform.environment['APPDATA'];
      path = Path.join(home, "Pub", "Cache");
    } else {
      home = Platform.environment['HOME'];
      path = Path.join(home, ".pub-cache");
    }
    return path;
  }
}

class _Dependency {
  
  final String name;
  final _PubHost host;
  
  //List<_Dependency> get dependencies => _dependencies;
  //List<_Dependency> _dependencies;
  
  _Dependency(this.name, this.host);

  /**
   * Resolves a hosted package.
   */
  PluginLoader resolve() {
    var p = new Directory(Path.join(host.path, name));
    if (!p.existsSync())
      throw new Exception("Unable to resolve pub cache plugin at: $p");
    var loader = new PluginLoader(p);
    var packages = Path.join(p.path, "bin", "packages");
    _handleBinPackages(loader, packages);
    return loader;
  }

  void _handleBinPackages(PluginLoader plugin, String packageDir) {
    var depends = plugin.pubspec['dependencies'];
    var packages = getPackages(depends);
    for (var p in packages) {
      var link = new Link(Path.join(packageDir, p.baseName.split("-")[0]));
      if (link.existsSync()) {
        // Ensure the most up to date package is always used
        link.deleteSync();
      }
      link.createSync(Path.join(p.path, "lib"), recursive: true);
    }
  }

  List<Package> getPackages(var depends) {
    var packages = <String, Package>{};
    if (depends != null) {
      host.packages.forEach((pack) {
        if (pack.baseName == name)
          return;
        var depend = depends[pack.name];
        if (depend != null) {
          var wanted = new VersionConstraint.parse(depend);
          if (wanted.allows(pack.version)) {
            var p = packages[pack.baseName];
            if (p == null || (pack.version.compareTo(p.version) > 0)) {
              packages[pack.baseName] = pack;
            }
          }
        }
      });
    }
    // TODO: handle dependency overrides
    // TODO: handle transitive dependencies
    // TODO: handle dependencies on other pub servers
    // TODO: handle dependencies on git
    return packages.values;
  }
}

class _PubHost {
  
  final String name;
  final String path;
  final List<Package> packages;
  
  _PubHost(this.name, this.path, this.packages);
  
  static _PubHost resolveHost(String host) {
    var hosted = Path.join(Pub.hostedCacheDir(), host);
    var packages = <Package>[];
    if (FileSystemEntity.isDirectorySync(hosted)) {
      var hostDir = new Directory(hosted);
      hostDir.listSync(followLinks: false).forEach((entity) {
        var packagePath = entity.path;
        if (FileSystemEntity.isDirectorySync(packagePath)) {
          var base = Path.basename(packagePath);
          var data = base.split("-");
          var name = data[0];
          var version = new Version.parse(data[1]);
          packages.add(new Package(packagePath, base, name, version));
        }
      });
    }
    return new _PubHost(host, hosted, packages);
  }
  
  static Map<String, _PubHost> resolveAllHosts() {
    var hosts = <String, _PubHost>{};
    var hosted = Pub.hostedCacheDir();
    if (FileSystemEntity.isDirectorySync(hosted)) {
      new Directory(hosted).listSync(followLinks: false).forEach((hostEntity) {
        var baseName = Path.basename(hostEntity.path);
        hosts[baseName] = resolveHost(baseName);
      });
    }
    return hosts;
  }
}

class Package {
  
  final String path;
  final String baseName;
  final String name;
  final Version version;

  Package(this.path, this.baseName, this.name, this.version);
}
