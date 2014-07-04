part of plugins.plugin;

/**
 * Wrapper around plugin receiving events from the loader.
 */
class Receiver {

  /**
   * Send data back to the loader.
   */
  final SendPort sp;

  /**
   * Receive data from the loader.
   */
  ReceivePort get rp => _rp;
  ReceivePort _rp;

  /**
   * Whether the plugin should stop handling everything and quit. This variable
   * is automatically set to true when the loader wants the plugin to quit.
   */
  bool get shouldQuit => _shouldQuit;
  bool _shouldQuit = false;

  Receiver(this.sp) {
    _rp = new ReceivePort();
    sp.send(_rp.sendPort);
  }

  void send(Map<dynamic, dynamic> data) {
    sp.send(data);
  }

  /**
   * [callback] is called everytime data is received. By default the listener
   * [callback] is wrapped around the [handle] to ensure only the data needed
   * is received in the plugin.
   * Returns [StreamSubscription] for finer handling if needed. The
   * [StreamSubscription] will automatically be canceled when [shouldQuit] is
   * triggered to be true.
   */
  StreamSubscription listen(void callback(Map<dynamic, dynamic> data)) {
    var ss = _rp.listen(null);
    ss.onData((Map<String, dynamic> rec) {
      var handled = handle(rec);
      if (handled != null)
        callback(handled);
    });
    return ss;
  }

  /**
   * Handles receiving data from the plugin loader.
   * Returns the data from the received information and processing
   * any types.
   */
  Map<dynamic, dynamic> handle(Map<String, dynamic> data) {
    switch (data['type']) {
      case 0: // quit
        _shouldQuit = true;
        return null;
      case 1: // normal
        return data['data'];
      default:
        throw new Exception("Invalid type received");
    }
  }
}
