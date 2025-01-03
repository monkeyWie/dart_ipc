import 'dart:io';
import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'dart_ipc_method_channel.dart';

abstract class DartIpcPlatform extends PlatformInterface {
  /// Constructs a DartIpcPlatform.
  DartIpcPlatform() : super(token: _token);

  static final Object _token = Object();

  static DartIpcPlatform _instance = MethodChannelDartIpc();

  /// The default instance of [DartIpcPlatform] to use.
  ///
  /// Defaults to [MethodChannelDartIpc].
  static DartIpcPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DartIpcPlatform] when
  /// they register themselves.
  static set instance(DartIpcPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<ServerSocket> bind(String path) {
    throw UnimplementedError('bind() has not been implemented.');
  }

  Future<Socket> connect(String path) {
    throw UnimplementedError('connect() has not been implemented.');
  }

  Future<int> accept(String path) {
    throw UnimplementedError('accept() has not been implemented.');
  }

  Future<Uint8List> read(int pipeHandlePtr) {
    throw UnimplementedError('writeFile() has not been implemented.');
  }

  Future<int> write(int pipeHandlePtr, Uint8List data) {
    throw UnimplementedError('write() has not been implemented.');
  }

  Future<void> close(int pipeHandlePtr) {
    throw UnimplementedError('closeClient() has not been implemented.');
  }
}
