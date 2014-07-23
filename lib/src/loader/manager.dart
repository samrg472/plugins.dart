part of plugins.loader;

/**
 * Manages plugin loading and handling.
 */
class PluginManager {

  /*
   * List implementation contains:
   * List[0] = Plugin
   * List[1] = StreamSubscription
   * List[2] = Function
   */
  final Map<String, List> _plugins = new Map();
  final RequestManager _requests = new RequestManager();

  /**
   * Gets a [List] of all the loaded plugin names.
   */
  List<String> get plugins {
    var p = [];
    p.addAll(_plugins.keys);
    return p;
  }

  /**
   * Returns an instance of the available plugin, null if there is no such
   * plugin.
   */
  Plugin plugin(String plugin) {
    List p = _plugins[plugin];
    return p != null ? p[0] : null;
  }

  /**
   * Sets the data listener for the [plugin] to [onData]. Any previous listener
   * will be overridden.
   */
  void listen(String plugin,
                void onData(String plugin, Map<dynamic, dynamic> data)) {
    var p = _plugins[plugin];
    p[1].onData((Map<dynamic, dynamic> _data) {
      if (_data['type'] == SendType.GET) {
        int uid = _data['uid'];
        String command = _data['command'];
        Map<dynamic, dynamic> unwrapped = _data['data'];
        p[2](p[0].name, new Request(p[0].sp, uid, command, unwrapped));
      } else {
        if ((_data['uid'] != null) && (_data['command'] != null))
          _requests.complete(_data['uid'], _data['command'], _data['data']);
        else
          onData(p[0].name, _data['data']);
      }
    });
  }

  /**
   * Sets the data listener for all plugins to [onData]. Any previous listeners
   * will be overridden.
   */
  void listenAll(void onData(String plugin, Map<dynamic, dynamic> data)) {
    for (String p in _plugins.keys)
      listen(p, onData);
  }

  /**
   * Listens to [GET] requests.
   */
  void listenRequest(String plugin, void onData(String plugin, Request data)) {
    _plugins[plugin][2] = onData;
  }

  /**
   * Listens to [GET] requests on all plugins.
   */
  void listenAllRequest(void onData(String plugin, Request data)) {
    for (String p in _plugins.keys)
      listenRequest(p, onData);
  }

  /**
   * Sends a message to [plugin]. The [data] is what the [plugin] will
   * receive. [type] can be specified to do anything specific.
   */
  void send(String plugin, Map<dynamic, dynamic> data, [int type = SendType.NORMAL]) {
    var wrapped = <String, dynamic>{};
    wrapped['type'] = type;
    wrapped['data'] = data;
    _plugins[plugin][0].sp.send(wrapped);
  }

  /**
   * Sends a message to all plugins. The [data] is what all plugins will
   * receive. [type] can be specified to do anything specific.
   */
  void sendAll(Map<dynamic, dynamic> data, [int type = SendType.NORMAL]) {
    var wrapped = <String, dynamic>{};
    wrapped['type'] = type;
    wrapped['data'] = data;
    for (List p in _plugins.values)
      p[0].sp.send(wrapped);
  }

  /**
   * Get data from the plugin
   */
  Future<Map<dynamic, dynamic>> get(String plugin,
                                    String command, Map<dynamic, dynamic> data) {
    Completer<Map<dynamic, dynamic>> com = new Completer<Map>();

    var wrapped = <String, dynamic>{};
    wrapped['type'] = SendType.GET;
    wrapped['uid'] = _requests.queue(com);
    wrapped['command'] = command;
    wrapped['data'] = data;
    _plugins[plugin][0].sp.send(wrapped);

    return com.future;
  }

  /**
   * The [PluginManager] will stop handling the [plugin]. The [PluginManager]
   * will send a stop signal to the [plugin] signifying it should halt.
   * Messages will no longer be sent to the plugin and all listeners will be
   * canceled.
   */
  void kill(String plugin) {
    Map temp = new Map();
    temp['type'] = SendType.QUIT;
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
    temp['type'] = SendType.QUIT;
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
  Future load(PluginLoader loader, {List<String> args}) {
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
          Plugin p = new Plugin(iso, loader.pubspec, data, port);
          if (_plugins.containsKey(p.name)) {
            throw new Exception("Plugin '${p.name}' was already registered");
          }

          t.cancel();
          var wrapper = new List(3);
          _plugins[p.name] = wrapper;

          wrapper[0] = p;
          wrapper[1] = ss;
          wrapper[2] = (String p, Request r) {};
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
  Future loadAll(Directory directory, {List<String> args}) {
    List<Future> futures = [];
    directory.listSync(followLinks: false).forEach((fse) {
      if (!(fse is Directory))
        return;
      var loader = new PluginLoader(fse);
      futures.add(load(loader, args: args));
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
   * Plugin name determined from the pubspec.yaml.
   */
  String get name => pubspec['name'];

  /**
   * The parsed pubspec.yaml file.
   */
  final pubspec;

  /**
   * Port for sending data to the plugin.
   */
  final SendPort sp;

  /**
   * Port for receiving data from the plugin.
   */
  final ReceivePort rp;

  Plugin(this.isolate, this.pubspec, this.sp, this.rp);

  @override
  String toString() {
    return name;
  }
}
