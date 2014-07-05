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
   * Sets the data listener for the [plugin] to [onData]. Any previous listener
   * will be overridden.
   */
  void listen(String plugin,
              void onData(String plugin, Map<dynamic, dynamic> data)) {
    _plugins[plugin][1].onData((Map<dynamic, dynamic> data) {
      onData(plugin, data);
    });
  }

  /**
   * Sets the data listener for all plugins to [onData]. Any previous listeners
   * will be overridden.
   */
  void listenAll(void onData(String plugin, Map<dynamic, dynamic> data)) {
    for (List p in _plugins.values) {
      p[1].onData((Map<dynamic, dynamic> data) {
        onData(p[0].name, data);
      });
    }
  }

  /**
   * Sends a message to [plugin]. The [data] is what the [plugin] will
   * receive. [type] can be specified to do anything specific.
   */
  void send(String plugin, Map<dynamic, dynamic> data, [int type = NORMAL]) {
    var wrapped = new Map();
    wrapped['type'] = type;
    wrapped['data'] = data;
    _plugins[plugin][0].sp.send(wrapped);
  }

  /**
   * Sends a message to all plugins. The [data] is what all plugins will
   * receive. [type] can be specified to do anything specific.
   */
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
    temp['type'] = QUIT;
    _plugins[plugin][0].sp.send(temp);
    _plugins[plugin][0].rp.close();
    _plugins[plugin][1].cancel();
    _plugins[plugin] = null;
  }

  /**
   * The [PluginManager] will stop handling all loaded plugins in the system.
   * A stop signal will be sent to all plugins signifying it should stop. All
   * ports will then be closed and all listeners will be canceled.
   */
  void killAll() {
    Map temp = new Map();
    temp['type'] = QUIT;
    for (List p in _plugins.values) {
      p[0].sp.send(temp);
      p[0].rp.close();
      p[1].cancel();
      _plugins[p[0].name] = null;
    }
  }

  /**
   * Properly adds the [loader] to the plugins registry. [args] can be
   * supplied to the spawned plugin.
   * Returns a [Future] with a [Plugin] as the value.
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
          completer.complete(p);
        }
      });
    });
    return completer.future;
  }

  /**
   * [directory] is the location of all the plugins. [args] can be provided to
   * all the spawned plugins. If individual arguments are sent to each plugin
   * see [load] for sending different arguments to each [PluginLoader].
   * Returns a [Future] with a [List] of [Future]'s as obtained from [load].
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
 * communicate with the plugin. It is recommended to use [PluginManager] to
 * interact with a [Plugin].
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

  @override
  String toString() {
    return name;
  }
}
