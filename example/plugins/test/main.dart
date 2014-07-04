import 'package:plugins/plugin.dart';
import 'dart:isolate';

void main(List<String> args, SendPort port) {
  Receiver rec = new Receiver(port);
  rec.listen((Map<dynamic, dynamic> data) {
    print("Received data in plugin: ${data[0]}");

    Map info = new Map();
    info[0] = "Hello from plugin!";
    rec.send(info);
  });
}
