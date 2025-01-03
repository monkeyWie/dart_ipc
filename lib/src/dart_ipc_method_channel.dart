import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dart_ipc_platform_interface.dart';
import 'named_pipe_server_socket.dart';
import 'named_pipe_socket.dart';

/// An implementation of [DartIpcPlatform] that uses method channels.
class MethodChannelDartIpc extends DartIpcPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('pub.dev/dart_ipc');

  /// The event channel used to receive events from the native platform.
  @visibleForTesting
  final eventChannel = const EventChannel('com.gopeed/dart_ipc_event');

  @override
  Future<ServerSocket> bind(String path) async {
    final clientSocketController = StreamController<Socket>();
    final serverSocket =
        Win32NamedPipeServerSocket(path, clientSocketController);

    (() async {
      while (!serverSocket.isClosed) {
        final pipeHandlePtr = await DartIpcPlatform.instance.accept(path);
        clientSocketController.add(Win32NamedPipeSocket(path, pipeHandlePtr));
      }
    })();

    return serverSocket;
  }

  @override
  Future<Socket> connect(String path) async {
    final result = await methodChannel.invokeMethod<int>('connect', {
      'path': path,
    });
    return Win32NamedPipeSocket(path, result!);
  }

  @override
  Future<int> accept(String path) async {
    final result = await methodChannel.invokeMethod<int>('accept', {
      'path': path,
    });
    return result!;
  }

  String uint8ListToHexString(Uint8List data) {
    return data.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(" ");
  }

  @override
  Future<Uint8List> read(int pipeHandlePtr) async {
    final result = await methodChannel.invokeMethod<Uint8List>('read', {
      'pipeHandlePtr': pipeHandlePtr,
    });
    // Convert to modifiable list, lib\_http\websocket_impl.dart:247 _unmask will modify the list, if it's not modifiable, we get an error
    return Uint8List.fromList(result!);
  }

  @override
  Future<int> write(int pipeHandlePtr, Uint8List data) async {
    final size = await methodChannel.invokeMethod<int>('write', {
      'pipeHandlePtr': pipeHandlePtr,
      'data': data,
    });
    return size!;
  }

  @override
  Future<void> close(int pipeHandlePtr) {
    return methodChannel.invokeMethod('close', {
      'pipeHandlePtr': pipeHandlePtr,
    });
  }
}
