import 'dart:io';

Future<ServerSocket> bind(String path) async {
  throw UnsupportedError('dart_ipc is unavailable on the web');
}

Future<Socket> connect(String path) async {
  throw UnsupportedError('dart_ipc is unavailable on the web');
}
