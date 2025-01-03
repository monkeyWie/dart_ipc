import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:dart_ipc/src/dart_ipc_platform_interface.dart';
import 'package:dart_ipc/src/dart_ipc_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDartIpcPlatform
    with MockPlatformInterfaceMixin
    implements DartIpcPlatform {
  @override
  Future<int> accept(String path) {
    // TODO: implement accept
    throw UnimplementedError();
  }

  @override
  Future<ServerSocket> bind(String path) {
    // TODO: implement bind
    throw UnimplementedError();
  }

  @override
  Future<void> close(int pipeHandlePtr) {
    // TODO: implement close
    throw UnimplementedError();
  }

  @override
  Future<Socket> connect(String path) {
    // TODO: implement connect
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> read(int pipeHandlePtr) {
    // TODO: implement read
    throw UnimplementedError();
  }

  @override
  Future<int> write(int pipeHandlePtr, Uint8List data) {
    // TODO: implement write
    throw UnimplementedError();
  }

}

void main() {
  final DartIpcPlatform initialPlatform = DartIpcPlatform.instance;

}
