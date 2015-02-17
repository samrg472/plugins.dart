part of plugins.loader;

/**
 * Plugins have the same directory layout as a Dart package. The pubspec.yaml
 * defines the plugin name. The plugin entry point is "main.dart" and must
 * contain a "pubspec.yaml" with a name alongside it. From the entry point,
 * then plugin can then call in code from its "lib" directory as a package.
 */
class PluginLoader {

  /**
   * The location of the plugin.
   */
  final Directory directory;

  bool _packages;
  String _name;
  var _conf;

  /**
   * Gets the parsed pubspec. Returns null if there is no pubspec.yaml found.
   */
  get pubspec {
    if (_conf != null) return _conf;
    var loc = Path.joinAll([directory.absolute.path, "pubspec.yaml"]);
    var file = new File(loc);
    if (!file.existsSync()) return null;
    return _conf = loadYaml(file.readAsStringSync());
  }

  /**
   * Verifies the packages are in the bin folder, if packages are detected in
   * the top level directory of the bin.
   */
  bool get packages {
    if (_packages != null) return _packages;
    var dir = new Directory(Path.join(directory.path, "bin", "packages"));
    if (!dir.existsSync()) {
      var path = Path.join(directory.path, "packages");
      if (!new Directory(path).existsSync()) {
        return _packages = false;
      } else {
        path = _convertPossibleLink(path);
        var link = new Link(dir.path);
        link.createSync(path);
      }
    }
    return _packages = true;
  }

  /**
   * Name of the plugin, returns null if there is no pubspec.yaml found.
   */
  String get name {
    if (_name != null) return _name;
    else if (pubspec != null) return pubspec['name'];
    else return null;
  }

  /**
   * [directory] is the path to the plugin location.
   */
  PluginLoader(this.directory, [this._name = null]);

  /**
   * [port] is needed in order for the plugin to send data back to the loader.
   * It is recommended to use [PluginManager.load] instead of calling this
   * directly.
   */
  Future<Isolate> load(SendPort port, [List<String> args = null, String path = null]) {
    args = args != null ? args : [];
    path = path != null ? path : Path.joinAll([directory.absolute.path, "bin", "main.dart"]);
    return Isolate.spawnUri(new Uri.file(path), args, port);
  }

  String _convertPossibleLink(String path) {
    while (FileSystemEntity.isLinkSync(path)) {
      path = new Link(path).targetSync();
    }
    return path;
  }
}
