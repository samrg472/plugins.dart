import 'package:plugins/plugin.dart';
import 'dart:isolate';

void main(List<String> args, SendPort port) {
  Receiver rec = new Receiver(port);
  rec.listenRequest((Request req) {
    print("Requester received command '${req.command}' from the loader");
    req.reply({0: 'Reply from the Requester plugin'});

    rec.get("sample", {}).then((Map<dynamic, dynamic> data) {
      print("Value of sample: ${data[0]}");
      rec.send({0: 'KILL'});
    });
  });
}
