import 'dart:io';

import 'dart_ipc_platform_interface.dart';

class DartIpcUnix extends DartIpcPlatform {
  static void registerWith() {
    DartIpcPlatform.instance = DartIpcUnix();
  }

  @override
  Future<ServerSocket> bind(String path) {
    return ServerSocket.bind(
        InternetAddress(path, type: InternetAddressType.unix), 0);
  }

  @override
  Future<Socket> connect(String path) {
    return Socket.connect(
        InternetAddress(path, type: InternetAddressType.unix), 0);
  }
}
