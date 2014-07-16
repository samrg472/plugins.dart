import 'package:plugins/loader.dart';
import 'dart:io';

void main() {
  PluginManager pm = new PluginManager();
  Directory path = new Directory("example" + Platform.pathSeparator + "plugins");

  pm.loadAll(path).then((List<Plugin> plugins) {
    print("Plugins registered: ${plugins}");

    pm.listenAllRequest((String plugin, Request req) {
      print("Received request from '$plugin' for command '${req.command}'");
      req.reply({0: 'Isn\'t this just awesome?'});
    });

    pm.listenAll((name, data) {
      print("Received data from plugin '$name': ${data[0]}");
      if (data[0] == "KILL") {
        print("Killing $name");
        pm.kill(name);
      }
    });
    Map m = new Map();
    m[0] = "Hello from loader!";
    pm.sendAll(m);
  });
}
