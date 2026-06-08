import 'dart:io';
import 'dart:typed_data';

import 'dart_ipc_unix.dart';
import 'dart_ipc_windows.dart';

abstract class DartIpcPlatform {
  static DartIpcPlatform? _instance;

  static DartIpcPlatform get instance {
    return _instance ??= Platform.isWindows ? DartIpcWindows() : DartIpcUnix();
  }

  static set instance(DartIpcPlatform instance) {
    _instance = instance;
  }

  Future<ServerSocket> bind(String path);

  Future<Socket> connect(String path);

  Future<int> accept(String path) {
    throw UnimplementedError('accept() has not been implemented.');
  }

  Future<Uint8List> read(int pipeHandlePtr) {
    throw UnimplementedError('read() has not been implemented.');
  }

  Future<int> write(int pipeHandlePtr, Uint8List data) {
    throw UnimplementedError('write() has not been implemented.');
  }

  Future<void> close(int pipeHandlePtr) {
    throw UnimplementedError('close() has not been implemented.');
  }

  Future<void> closeServer(String path) async {}
}
