part of plugins.plugin;

/**
 * Callback for listening to requests.
 */
typedef void RequestCallback(Request req);

/**
 * Callback for listening to intercommunications from other plugins.
 */
typedef void IntercomCallback(String plugin, Map<dynamic, dynamic> data);

/**
 * Wrapper around plugin receiving events from the loader.
 */
class Receiver {

  final SendPort _sp;
  final ReceivePort _rp;
  final RequestManager _requests = new RequestManager();

  StreamSubscription _ss;
  RequestCallback _requestCallback = (Request req) {};
  IntercomCallback _interCallback = (String plugin, Map data) {};

  /**
   * Whether the plugin should stop handling everything and quit. This variable
   * is automatically set to true when the loader wants the plugin to quit.
   */
  bool get shouldQuit => _shouldQuit;
  bool _shouldQuit = false;

  Receiver(this._sp) : _rp = new ReceivePort() {
    _sp.send(_rp.sendPort);
    _ss = _rp.listen(null);
    _ss.onData((Map<String, dynamic> rec) {
      handle(rec);
    });
  }

  /**
   * [command] is the data to get. [data] is the parameters of the [command].
   * Returns a [Future] with the received data.
   */
  ConditionalFuture<Map> get(String command, Map data) {
    ConditionalCompleter<Map> com = new ConditionalCompleter<Map>();
    Map<String, dynamic> wrapped = {
      'type': SendType.GET,
      'uid': _requests.queue(com),
      'command': command,
      'data': data
    };
    _sp.send(wrapped);
    return com.future;
  }

  /**
   * Sends [data] back to the loader.
   */
  void send(Map<dynamic, dynamic> data) {
    Map<String, dynamic> wrapped = {
      'type': SendType.NORMAL,
      'data': data
    };
    _sp.send(wrapped);
  }

  /**
   * Sends [data] to the [plugin]. The [plugin] must be loaded otherwise an
   * exception will be thrown on the loader side.
   */
  void intercom(String plugin, Map<dynamic, dynamic> data) {
    Map<String, dynamic> wrapped = {
      'type': SendType.INTERCOM,
      'plugin': plugin,
      'data': data
    };
    _sp.send(wrapped);
  }

  /**
   * [callback] is called everytime data is received. By default the listener
   * [callback] is wrapped around the [handle] to ensure only the data needed
   * is received in the plugin. The
   * [callback] will automatically be canceled when [shouldQuit] is
   * triggered to be true.
   */
  StreamSubscription listen(void callback(Map<dynamic, dynamic> data)) {
    _ss.onData((Map<String, dynamic> rec) {
      var handled = handle(rec);
      if (handled != null)
        callback(handled);
    });
    return _ss;
  }

  /**
   * Listens to requests made by the plugin loader.
   */
  void listenRequest(void callback(Request req)) {
    _requestCallback = callback;
  }

  /**
   * Listens to incoming messages from other plugins.
   */
  void listenIntercom(void callback(String plugin, Map data)) {
    _interCallback = callback;
  }

  /**
   * Handles receiving data from the plugin loader.
   * Returns the data from the received information and processing
   * any types.
   */
  Map<dynamic, dynamic> handle(Map<String, dynamic> data) {
    switch (data['type']) {
      case SendType.QUIT:
        _shouldQuit = true;
        _ss.cancel();
        return null;
      case SendType.NORMAL:
        if ((data['uid'] != null) && (data['command'] != null)) {
          _requests.complete(data['uid'], data['command'], data['data']);
          return null;
        }
        return data['data'];
      case SendType.GET:
        int uid = data['uid'];
        String command = data['command'];
        Map<dynamic, dynamic> unwrapped = data['data'];
        _requestCallback(new Request(_sp, uid, command, unwrapped));
        return null;
      case SendType.INTERCOM:
        _interCallback(data['from'], data['data']);
        return null;
      default:
        throw new Exception("Invalid type received");
    }
  }
}
