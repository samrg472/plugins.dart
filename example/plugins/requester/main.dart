import 'package:plugins/plugin.dart';
import 'dart:isolate';

void main(List<String> args, SendPort port) {
  Receiver rec = new Receiver(port);
  rec.listen((Map<dynamic, dynamic> data) {
    rec.get("sample", {}).then((Map<dynamic, dynamic> data) {
      print("Value of sample: ${data[0]}");
      rec.send({0: 'KILL'});
    });
  });
}
