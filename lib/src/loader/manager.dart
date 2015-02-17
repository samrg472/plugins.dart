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
    return new List.from(_plugins.keys);
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
      switch (_data['type']) {
        case SendType.GET:
          int uid = _data['uid'];
          String command = _data['command'];
          Map<dynamic, dynamic> unwrapped = _data['data'];
          Request req = new Request(p[0].sp, uid, command, unwrapped);
          if (command == "plugins") {
            req.reply({ 'plugins': plugins });
          } else {
            p[2](p[0].name, req);
          }
          break;
        case SendType.INTERCOM:
          String target = _data['plugin'];
          var recv = _data['data'];
          if (!_plugins.containsKey(target)) {
            throw new Exception("Attempting to communicate to an unloaded plugin: $target");
          }
          var wrapped = _commonWrapped(SendType.INTERCOM, recv);
          wrapped['from'] = plugin;
          _sendUnwrapped(target, wrapped);
          break;
        case SendType.NORMAL:
          // Check if this is a request
          if ((_data['uid'] != null) && (_data['command'] != null)) {
            _requests.complete(_data['uid'], _data['command'], _data['data']);
          } else {
            onData(p[0].name, _data['data']);
          }
          break;
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
    var wrapped = _commonWrapped(type, data);
    _sendUnwrapped(plugin, wrapped);
  }

  /**
   * Sends a message to all plugins. The [data] is what all plugins will
   * receive. [type] can be specified to do anything specific.
   */
  void sendAll(Map<dynamic, dynamic> data, [int type = SendType.NORMAL]) {
    var wrapped = _commonWrapped(type, data);
    for (String p in _plugins.keys) {
      _sendUnwrapped(p, wrapped);
    }
  }

  /**
   * Get data from the plugin.
   */
  ConditionalFuture<Map> get(String plugin, String command, Map data) {
    ConditionalCompleter<Map> com = new ConditionalCompleter<Map>();

    var wrapped = _commonWrapped(SendType.GET, data);
    wrapped['uid'] = _requests.queue(com);
    wrapped['command'] = command;
    _sendUnwrapped(plugin, wrapped);

    return com.future;
  }

  /**
   * The [PluginManager] will stop handling the [plugin]. The [PluginManager]
   * will send a stop signal to the [plugin] signifying it should halt.
   * Messages will no longer be sent to the plugin and all listeners will be
   * canceled.
   */
  void kill(String plugin) {
    var temp = { "type": SendType.QUIT };
    _plugins[plugin][0].sp.send(temp);
    _plugins[plugin][0].rp.close();
    _plugins[plugin][1].cancel();
    _plugins.remove(plugin);
  }

  /**
   * The [PluginManager] will stop handling all loaded plugins in the system.
   * A stop signal will be sent to all plugins signifying it should stop. All
   * ports will then be closed and all listeners will be canceled.
   */
  void killAll() {
    var temp = { "type": SendType.QUIT };
    var plugins = new List.from(_plugins.values);
    _plugins.clear();
    for (List p in plugins) {
      p[0].sp.send(temp);
      p[0].rp.close();
      p[1].cancel();
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
    else if (!loader.packages)
      throw new Exception("Plugin is missing packages: ${loader.directory.path}");

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
          t.cancel();
          Plugin p = new Plugin(iso, loader.pubspec, data, port);
          if (_plugins.containsKey(p.name)) {
            throw new Exception("Plugin '${p.name}' was already registered");
          }

          var wrapper = new List(3);
          wrapper[0] = p;
          wrapper[1] = ss;
          wrapper[2] = (String p, Request r) {};
          ss.onData((data) {});

          _plugins[p.name] = wrapper;
          completer.complete(p);
        }
      });
    });
    return completer.future;
  }

  Future loadFromCache(String name, {List<String> args,
                                      String host: "pub.dartlang.org"}) {
    var path;
    var home = Platform.environment['PUB_CACHE'];
    if (home != null) {
      path = Path.join(home, "hosted", host, name);
    } else if (Platform.isWindows) {
      home = Platform.environment['APPDATA'];
      path = Path.join(home, "Pub", "Cache", "hosted", host, name);
    } else {
      home = Platform.environment['HOME'];
      path = Path.join(home, ".pub-cache", "hosted", host, name);
    }
    return load(new PluginLoader(new Directory(path)), args: args);
  }
  
  /**
   * [directory] is the location of all the plugins. [args] can be provided to
   * all the spawned plugins. If individual arguments are sent to each plugin
   * see [load] for sending different arguments to each [PluginLoader]. The
   * loader can follow symbolic links if [followLinks] is true.
   * Returns a [Future] with a [List] of [Future]'s as obtained from [load].
   */
  Future loadAll(Directory directory, {List<String> args,
                                        bool followLinks: true}) {
    List<Future> futures = [];
    directory.listSync(followLinks: followLinks).forEach((fse) {
      if (fse is! Directory) {
        return;
      }
      var dir = fse as Directory;
      if (dir.listSync().every((entity) => entity is Link)) {
        return;
      }
      var loader = new PluginLoader(dir);
      futures.add(load(loader, args: args));
    });
    return Future.wait(futures);
  }

  Map<String, dynamic> _commonWrapped(int type, Map data) {
    return { "type": type, "data": data };
  }

  void _sendUnwrapped(String plugin, Map wrapped) {
    _plugins[plugin][0].sp.send(wrapped);
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
