/**
 * Recommended plugin system when being loaded by
 * the [plugins.loader](#plugins/plugins-loader) library.
 */
library plugins.plugin;

import 'dart:async';
import 'dart:isolate';

import 'common.dart';
export 'common.dart';

part 'src/plugin/receiver.dart';
