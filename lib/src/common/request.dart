part of plugins.common;

class RequestManager {

  Map<int, Completer> _requests = {};
  final Random _rand = new Random();

  void complete(int uid, String command, Map<dynamic, dynamic> data) {
    var com = _requests[uid];
    if (com == null)
      throw new Exception("Attempt to complete an invalid request");
    com.complete(data);
  }

  int queue(Completer completer) {
    int uid = _rand.nextInt(10000);
    while (_requests.containsKey(uid))
      uid = _rand.nextInt(10000);
    _requests[uid] = completer;
    return uid;
  }
}

/**
 * Handles data for requests. Replies are expected to ensure the request
 * is completed.
 */
class Request {

  final SendPort _sp;

  /**
   * THe name of the command.
   */
  final String command;

  /**
   * Identifier for the request that will be expected by the requester.
   */
  final int uid;

  /**
   * The received [data] from the plugin or the loader.
   */
  final Map<dynamic, dynamic> data;

  Request(this._sp, this.uid, this.command, this.data);

  /**
   * Replies are expected to ensure data is sent back.
   */
  void reply(Map<dynamic, dynamic> info) {
    var wrapped = <String, dynamic>{
      'type': SendType.NORMAL,
      'uid': uid,
      'command': command,
      'data': info
    };
    _sp.send(wrapped);
  }
}
