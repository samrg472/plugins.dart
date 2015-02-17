import 'package:plugins/plugin.dart';
import 'dart:isolate';

void main(List<String> args, SendPort port) {
  Receiver rec = new Receiver(port);

  rec.listenIntercom((String plugin, Map data) {
    print("[Test] Received intercom data from $plugin and its message is: ${data[0]}");
    rec.send({0: 'KILL'});
  });

  rec.listen((Map<dynamic, dynamic> data) {
    print("[Test] Received data: ${data[0]}");
    rec.get("test", {}).callIf((Map data) => data['should']).then((Map data) {
      rec.intercom("Requester", {0: "Hello requester!"});
      rec.send({0: "Hello from plugin!"});
    });

    rec.get("test-nocall", {}).callIf((Map data) => data['should']).then((Map data) {
      print("[Test] This is never called");
    });
  });
}
