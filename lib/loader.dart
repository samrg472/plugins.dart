/**
 * Handles the loading of plugins.
 */
library plugins.loader;

import 'dart:isolate';
import 'dart:async';
import 'dart:io';

import 'package:pub_semver/pub_semver.dart';
import 'package:path/path.dart' as Path;
import 'package:yaml/yaml.dart';

import 'common.dart';
export 'common.dart';

part 'src/loader/manager.dart';
part 'src/loader/loader.dart';
part 'src/loader/pub.dart';
