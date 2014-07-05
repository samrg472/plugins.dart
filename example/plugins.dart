import 'package:plugins/loader.dart';
import 'dart:io';

void main() {
  PluginManager pm = new PluginManager();
  Directory path = new Directory("example" + Platform.pathSeparator + "plugins");
  pm.loadAll(path).then((_) {
    pm.listen("Test", (data) {
      print("Received data in loader: ${data[0]}");
      pm.killAll();
    });
    Map m = new Map();
    m[0] = "Hello from loader!";
    pm.sendAll(m);
  });

}
