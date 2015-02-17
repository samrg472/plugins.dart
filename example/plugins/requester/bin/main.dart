import 'package:plugins/plugin.dart';
import 'dart:isolate';

void main(List<String> args, SendPort port) {
  Receiver rec = new Receiver(port);

  rec.listenIntercom((String plugin, Map data) {
    print("[Requester] Received intercom data from $plugin and its message is: ${data[0]}");
    rec.send({0: 'KILL'});
  });

  rec.listenRequest((Request req) {
    print("[Requester] Received command '${req.command}' from the loader");
    req.reply({0: 'This is a reply from the Requester plugin'});

    rec.get("sample", {}).then((Map data) {
      print("[Requester] Value of sample: ${data[0]}");
      rec.get("plugins", {}).then((Map _data) {
        print("[Requester] Retrieved loaded plugins: " + _data['plugins'].join(", "));
        rec.intercom("Test", {0: "Hello test!"});
      });
    });
  });
}
