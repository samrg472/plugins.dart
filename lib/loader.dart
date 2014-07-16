/**
 * Handles the loading of plugins.
 */
library plugins.loader;

import 'dart:isolate';
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import 'common.dart';
export 'common.dart';

part 'src/loader/manager.dart';
part 'src/loader/loader.dart';
