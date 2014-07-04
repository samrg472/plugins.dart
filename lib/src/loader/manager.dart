part of plugins.loader;

/**
 * Manages plugin loading and handling.
 */
class PluginManager {

  static const int QUIT = 0;
  static const int NORMAL = 1;

  /*
   * List implementation contains:
   * List[0] = Plugin
   * List[1] = StreamSubscription
   */
  final Map<String, List> _plugins = new Map();

  /**
   * Sets the data listener for the [plugin].
   */
  void listen(String plugin, void func(Map<String, dynamic> data)) {
    _plugins[plugin][1].onData(func);
  }

  void send(String plugin, Map<dynamic, dynamic> data, [int type = NORMAL]) {
    var wrapped = new Map();
    wrapped['type'] = type;
    wrapped['data'] = data;
    _plugins[plugin][0].sp.send(wrapped);
  }

  void sendAll(Map<dynamic, dynamic> data, [int type = NORMAL]) {
    var wrapped = new Map();
    wrapped['type'] = type;
    wrapped['data'] = data;
    for (List p in _plugins.values)
      p[0].sp.send(wrapped);
  }

  /**
   * The [PluginManager] will stop handling the [plugin]. The [PluginManager]
   * will send a stop signal to the [plugin] signifying it should halt.
   * Messages will no longer be sent to the plugin and all listeners will be
   * canceled.
   */
  void kill(String plugin) {
    Map temp = new Map();
    temp['type'] = 0; // Quit type
    _plugins[plugin][0].sp;
    _plugins[plugin][0].rp.close();
    _plugins[plugin][1].cancel();
  }

  /**
   * Properly adds the [loader] to the plugins registry. [args] can be
   * supplied to the spawned plugin.
   */
  Future load(PluginLoader loader, [List<String> args]) {
    var port = new ReceivePort();
    if (loader.name == null)
      throw new Exception("Unnamed plugin at: ${loader.directory.path}");
    Future<Isolate> pn = loader.load(port.sendPort, args);

    Completer completer = new Completer();

    pn.then((Isolate iso) {
      // UNSUPPORTED: iso.setErrorsFatal(true);
      var ss = port.listen(null);
      Timer t = new Timer(new Duration(seconds: 5), () {
        throw new Exception("Plugin '${loader.name}' failed to register in time");
      });

      ss.onData((data) {
        if (data is SendPort) {
          Plugin p = new Plugin(iso, loader.name, data, port);
          if (_plugins.containsKey(p.name)) {
            throw new Exception("Plugin '${p.name}' was already registered");
          }

          t.cancel();
          var wrapper = new List(2);
          _plugins[p.name] = wrapper;

          wrapper[0] = p;
          wrapper[1] = ss;
          ss.onData((data) {});
          completer.complete();
        }
      });
    });
    return completer.future;
  }

  /**
   * [directory] is the location of all the plugins. [args] can be provided to
   * all the spawned plugins. If individual arguments are sent to each plugin
   * see [load] for sending different arguments to each [PluginLoader].
   */
  Future loadAll(Directory directory, [List<String> args]) {
    List<Future> futures = [];
    directory.listSync(followLinks: false).forEach((fse) {
      if (!(fse is Directory))
        return;
      var loader = new PluginLoader(fse);
      futures.add(load(loader, args));
    });
    return Future.wait(futures);
  }
}

/**
 * Carries information about a given loaded plugin. Including the ports to
 * communicate with the plugin.
 */
class Plugin {

  /**
   * The spawned isolate of the plugin.
   */
  final Isolate isolate;

  /**
   * Plugin name determined from the pubspec.yaml
   */
  final String name;

  /**
   * Port for sending data to the plugin.
   */
  final SendPort sp;

  /**
   * Port for receiving data from the plugin.
   */
  final ReceivePort rp;

  Plugin(this.isolate, this.name, this.sp, this.rp);
}
