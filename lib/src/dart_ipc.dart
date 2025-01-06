import 'dart:async';
import 'dart:io';

import 'dart_ipc_platform_interface.dart';

/// Binds to a server socket at the specified [path],
/// In windows, [path] should be in the format of `\\.\pipe\dart_ipc`,
/// In unix, [path] should be a file path e.g. `/tmp/dart_ipc.unix`.
///
/// Returns a [Future] that completes with a [ServerSocket] that is bound to the specified [path].
Future<ServerSocket> bind(String path) {
  return DartIpcPlatform.instance.bind(path);
}

/// Connects to a server socket at the specified [path],
/// In windows, [path] should be in the format of `\\.\pipe\dart_ipc`,
/// In unix, [path] should be a file path e.g. `/tmp/dart_ipc.unix`.
///
/// Returns a [Future] that completes with a [Socket] that is connected to the specified [path].
Future<Socket> connect(String path) {
  return DartIpcPlatform.instance.connect(path);
}
