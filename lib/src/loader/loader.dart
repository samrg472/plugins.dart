part of plugins.loader;

/**
 * Plugins have the same directory layout as a Dart package. The pubspec.yaml
 * defines the plugin name. The plugin entry point is "main.dart" and must
 * contain a "pubspec.yaml" with a name alongside it. From the entry point,
 * then plugin can then call in code from its "lib" directory as a package.
 */
class PluginLoader {

  /**
   * The location of the plugin
   */
  final Directory directory;

  String _name;

  /**
   * Name of the plugin, returns null if there is no pubspec.yaml found
   */
  String get name {
    if (_name != null)
      return _name;
    var loc = path.joinAll([directory.absolute.path, "pubspec.yaml"]);
    var file = new File(loc);
    if (!file.existsSync())
      return null;
    var conf = loadYaml(file.readAsStringSync());
    return _name = conf['name'];
  }

  PluginLoader(this.directory);

  /**
   * [port] is needed in order for the plugin to send data back to the loader.
   * It is recommended to use [PluginManager.load] instead of calling this
   * directly.
   */
  Future<Isolate> load(SendPort port, List<String> args) {
    args = args == null ? [] : args;
    var loc = path.joinAll([directory.absolute.path, "main.dart"]);
    return Isolate.spawnUri(new Uri.file(loc), args, port);
  }
}
