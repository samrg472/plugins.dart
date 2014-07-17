part of plugins.plugin;

/**
 * Callback for listening to requests.
 */
typedef void RequestCallback(Request req);

/**
 * Wrapper around plugin receiving events from the loader.
 */
class Receiver {

  final SendPort _sp;
  final ReceivePort _rp;
  final RequestManager _requests = new RequestManager();

  StreamSubscription _ss;
  RequestCallback _requestCallback = (Request req) {};

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

  Future<Map<dynamic, dynamic>> get(String command, Map<dynamic, dynamic> data) {
    Completer<Map<dynamic, dynamic>> com = new Completer<Map>();
    Map<String, dynamic> wrapped = {
      'type': SendType.GET,
      'uid': _requests.queue(com),
      'command': command,
      'data': data
    };
    _sp.send(wrapped);
    return com.future;
  }

  void send(Map<dynamic, dynamic> data) {
    Map<String, dynamic> wrapped = {
      'type': SendType.NORMAL,
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
      default:
        throw new Exception("Invalid type received");
    }
  }
}
