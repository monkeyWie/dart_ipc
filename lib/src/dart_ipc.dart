import 'dart:async';
import 'dart:io';

import 'dart_ipc_platform_interface.dart';

Future<ServerSocket> bind(String path) {
  return DartIpcPlatform.instance.bind(path);
}

Future<Socket> connect(String path) {
  return DartIpcPlatform.instance.connect(path);
}
