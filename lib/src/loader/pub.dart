part of plugins.loader;

class Pub {
  
  final String path;
  final List<Package> _packages;

  /**
   * [cache] is the path to the cache directory. The default being
   * the retrieved path from cacheDir()
   */
  factory Pub({String cache}) {
    if (cache == null)
      cache = hostedCacheDir();
    var dir = new Directory(cache);
    if (!dir.existsSync())
      throw new Exception("Cache directory non-existant; $cache");
    var packs = dir.listSync(followLinks: false);
    var filtered = <Package>[];
    packs.forEach((FileSystemEntity e) {
      var p = e.path;
      if (FileSystemEntity.isDirectorySync(p)) {
        var base = Path.basename(p);
        var data = base.split("-");
        var name = data[0];
        var version = new Version.parse(data[1]);
        filtered.add(new Package(p, base, name, version));
      }
    });
    return new Pub._internal(cache, filtered);
  }
  
  Pub._internal(this.path, this._packages);
  
  PluginLoader resolve(String name) {
    var p = new Directory(Path.join(path, name));
    if (!p.existsSync())
      throw new Exception("Unable to resolve pub cache plugin at: $p");
    var loader = new PluginLoader(p);
    var packages = Path.join(p.path, "bin", "packages");
    if (!FileSystemEntity.isDirectorySync(packages))
      new Directory(packages).createSync();
    handleBinPackages(name, loader, packages);
    return loader;
  }

  void handleBinPackages(String baseName, PluginLoader plugin, String packageDir) {
    var depends = plugin.pubspec['dependencies'];
    var packages = getPackages(baseName, depends);
    for (var p in packages) {
      var dir = new Link(Path.join(packageDir, p.baseName.split("-")[0]));
      if (dir.existsSync()) {
        dir.deleteSync();
      }
      dir.createSync(Path.join(p.path, "lib"));
    }
  }
  
  List<Package> getPackages(String baseName, var depends) {
    var packages = <String, Package>{};
    if (depends != null) {
      _packages.forEach((pack) {
        if (pack.baseName == baseName)
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
    return packages;
  }
  
  static String hostedCacheDir({String host: "pub.dartlang.org"}) {
    var path = baseCacheDir();
    return Path.join(path, "hosted", host);
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

class Package {
  
  final String path;
  final String baseName;
  final String name;
  final Version version;

  Package(this.path, this.baseName, this.name, this.version);
}
