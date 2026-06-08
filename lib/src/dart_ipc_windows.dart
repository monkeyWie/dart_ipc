import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'dart_ipc_platform_interface.dart';
import 'named_pipe_server_socket.dart';
import 'named_pipe_socket.dart';

const _bufferSize = 4096;
const _pipeTimeoutMs = 5000;
const _connectRetryDelay = Duration(milliseconds: 20);
const _wtExecuteOnlyOnce = 0x00000008;

typedef _WaitOrTimerCallbackNative = Void Function(Pointer<Void>, Uint8);

final _kernel32 = DynamicLibrary.open('kernel32.dll');

final _waitCallback =
    NativeCallable<_WaitOrTimerCallbackNative>.listener(_onWaitComplete)
      ..keepIsolateAlive = false;

final _registerWaitForSingleObject = _kernel32.lookupFunction<
    Int32 Function(
      Pointer<Pointer<Void>>,
      Pointer<Void>,
      Pointer<NativeFunction<_WaitOrTimerCallbackNative>>,
      Pointer<Void>,
      Uint32,
      Uint32,
    ),
    int Function(
      Pointer<Pointer<Void>>,
      Pointer<Void>,
      Pointer<NativeFunction<_WaitOrTimerCallbackNative>>,
      Pointer<Void>,
      int,
      int,
    )>('RegisterWaitForSingleObject');

final _unregisterWaitEx = _kernel32.lookupFunction<
    Int32 Function(Pointer<Void>, Pointer<Void>),
    int Function(Pointer<Void>, Pointer<Void>)>('UnregisterWaitEx');

final _pendingOperations = <int, _PendingOperation>{};
int _nextOperationId = 1;
int _activeOperationCount = 0;

class Win32NamedPipeException implements IOException {
  final int code;
  final String operation;

  const Win32NamedPipeException(this.operation, this.code);

  @override
  String toString() => '$operation failed with Win32 error $code';
}

class DartIpcWindows extends DartIpcPlatform {
  final Map<String, Set<int>> _pendingAcceptHandles = {};

  @override
  Future<ServerSocket> bind(String path) async {
    final clientSocketController = StreamController<Socket>();
    final serverSocket =
        Win32NamedPipeServerSocket(path, clientSocketController);

    () async {
      while (!serverSocket.isClosed) {
        try {
          final pipeHandlePtr = await accept(path);
          if (serverSocket.isClosed) {
            await close(pipeHandlePtr);
            break;
          }
          clientSocketController.add(Win32NamedPipeSocket(path, pipeHandlePtr));
        } on Win32NamedPipeException catch (error, stackTrace) {
          if (serverSocket.isClosed ||
              error.code == ERROR_INVALID_HANDLE.code) {
            break;
          }
          clientSocketController.addError(error, stackTrace);
          break;
        } catch (error, stackTrace) {
          if (!serverSocket.isClosed) {
            clientSocketController.addError(error, stackTrace);
          }
          break;
        }
      }
      if (!clientSocketController.isClosed) {
        await clientSocketController.close();
      }
    }();

    return serverSocket;
  }

  @override
  Future<Socket> connect(String path) async {
    final deadline = DateTime.now().add(Duration(milliseconds: _pipeTimeoutMs));

    while (true) {
      try {
        final pipeHandlePtr = _connectPipe(path);
        return Win32NamedPipeSocket(path, pipeHandlePtr);
      } on Win32NamedPipeException catch (error) {
        if (error.code != ERROR_PIPE_BUSY.code ||
            DateTime.now().isAfter(deadline)) {
          rethrow;
        }
        await Future<void>.delayed(_connectRetryDelay);
      }
    }
  }

  @override
  Future<int> accept(String path) async {
    while (true) {
      final pipeHandlePtr = _createServerPipe(path);
      (_pendingAcceptHandles[path] ??= <int>{}).add(pipeHandlePtr);

      try {
        await _connectServerPipe(pipeHandlePtr);
        return pipeHandlePtr;
      } on Win32NamedPipeException catch (error) {
        await close(pipeHandlePtr);
        if (error.code == ERROR_NO_DATA.code) {
          continue;
        }
        rethrow;
      } catch (_) {
        await close(pipeHandlePtr);
        rethrow;
      } finally {
        final handles = _pendingAcceptHandles[path];
        handles?.remove(pipeHandlePtr);
        if (handles != null && handles.isEmpty) {
          _pendingAcceptHandles.remove(path);
        }
      }
    }
  }

  @override
  Future<Uint8List> read(int pipeHandlePtr) {
    return Future.sync(() => _readPipe(pipeHandlePtr));
  }

  @override
  Future<int> write(int pipeHandlePtr, Uint8List data) {
    return Future.sync(() => _writePipe(pipeHandlePtr, data));
  }

  @override
  Future<void> close(int pipeHandlePtr) {
    return Future.sync(() => _closePipe(pipeHandlePtr));
  }

  @override
  Future<void> closeServer(String path) async {
    final handles = _pendingAcceptHandles.remove(path);
    if (handles == null) return;

    await Future.wait(handles.map(close));
  }
}

int _createServerPipe(String path) {
  return using((arena) {
    final pipeName = path.toPcwstr(allocator: arena);
    final handle = CreateNamedPipe(
      pipeName,
      FILE_FLAGS_AND_ATTRIBUTES(PIPE_ACCESS_DUPLEX | FILE_FLAG_OVERLAPPED),
      NAMED_PIPE_MODE(PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT),
      PIPE_UNLIMITED_INSTANCES,
      _bufferSize,
      _bufferSize,
      _pipeTimeoutMs,
      null,
    );

    if (!handle.isValid) {
      throw Win32NamedPipeException('CreateNamedPipe', GetLastError().code);
    }

    return handle.address;
  });
}

Future<void> _connectServerPipe(int pipeHandlePtr) {
  final handle = HANDLE(Pointer.fromAddress(pipeHandlePtr));
  final operation = _PendingOperation(pipeHandlePtr, closedErrorsAreEof: false);
  final result = ConnectNamedPipe(handle, operation.overlapped);

  if (result.value || result.error == ERROR_PIPE_CONNECTED) {
    operation.complete(0);
  } else if (result.error == ERROR_IO_PENDING) {
    operation.register();
  } else {
    final error = result.error.code;
    operation.dispose();
    throw Win32NamedPipeException('ConnectNamedPipe', error);
  }

  return operation.completer.future.then((_) {
    operation.dispose();
  });
}

int _connectPipe(String path) {
  return using((arena) {
    final pipeName = path.toPcwstr(allocator: arena);
    final result = CreateFile(
      pipeName,
      GENERIC_READ | GENERIC_WRITE,
      FILE_SHARE_MODE(0),
      null,
      OPEN_EXISTING,
      FILE_FLAGS_AND_ATTRIBUTES(
        FILE_FLAG_OVERLAPPED | SECURITY_SQOS_PRESENT | SECURITY_ANONYMOUS,
      ),
      null,
    );

    if (!result.value.isValid) {
      throw Win32NamedPipeException('CreateFile', result.error.code);
    }

    return result.value.address;
  });
}

Future<Uint8List> _readPipe(int pipeHandlePtr) {
  final handle = HANDLE(Pointer.fromAddress(pipeHandlePtr));
  final operation = _PendingOperation(pipeHandlePtr, bufferSize: _bufferSize);

  final result = ReadFile(
    handle,
    operation.buffer,
    _bufferSize,
    operation.bytesTransferred,
    operation.overlapped,
  );

  if (result.value) {
    return Future.value(operation.completeRead(operation.bytesTransferred.value));
  }

  if (result.error == ERROR_IO_PENDING) {
    operation.register();
    return operation.completer.future.then((bytesTransferred) {
      return operation.completeRead(bytesTransferred);
    });
  }

  final error = result.error.code;
  operation.dispose();
  if (_isPipeClosedError(error)) {
    return Future.value(Uint8List(0));
  }
  throw Win32NamedPipeException('ReadFile', error);
}

Future<int> _writePipe(int pipeHandlePtr, Uint8List data) {
  if (data.isEmpty) return Future.value(0);

  final handle = HANDLE(Pointer.fromAddress(pipeHandlePtr));
  final operation = _PendingOperation(pipeHandlePtr, bufferSize: data.length);
  operation.buffer!.asTypedList(data.length).setAll(0, data);

  final result = WriteFile(
    handle,
    operation.buffer,
    data.length,
    operation.bytesTransferred,
    operation.overlapped,
  );

  if (result.value) {
    return Future.value(operation.completeWrite(operation.bytesTransferred.value));
  }

  if (result.error == ERROR_IO_PENDING) {
    operation.register();
    return operation.completer.future.then(operation.completeWrite);
  }

  final error = result.error.code;
  operation.dispose();
  throw Win32NamedPipeException('WriteFile', error);
}

void _closePipe(int pipeHandlePtr) {
  if (pipeHandlePtr == 0) return;

  final handle = HANDLE(Pointer.fromAddress(pipeHandlePtr));
  if (!handle.isValid) return;

  CancelIoEx(handle, null);
  DisconnectNamedPipe(handle);
  final result = CloseHandle(handle);
  if (!result.value && result.error != ERROR_INVALID_HANDLE) {
    throw Win32NamedPipeException('CloseHandle', result.error.code);
  }
}

bool _isPipeClosedError(int code) {
  return code == ERROR_BROKEN_PIPE.code ||
      code == ERROR_NO_DATA.code ||
      code == ERROR_INVALID_HANDLE.code;
}

void _onWaitComplete(Pointer<Void> context, int timerOrWaitFired) {
  final operation = _pendingOperations.remove(context.address);
  operation?._onWaitComplete();
}

class _PendingOperation {
  _PendingOperation(
    this.pipeHandlePtr, {
    int? bufferSize,
    this.closedErrorsAreEof = true,
  })
      : id = _nextOperationId++,
        overlapped = calloc<OVERLAPPED>(),
        bytesTransferred = calloc<Uint32>(),
        buffer = bufferSize == null ? null : calloc<Uint8>(bufferSize) {
    _activeOperationCount++;
    _waitCallback.keepIsolateAlive = true;
    final eventResult = CreateEvent(null, true, false, null);
    if (!eventResult.value.isValid) {
      dispose();
      throw Win32NamedPipeException('CreateEvent', eventResult.error.code);
    }
    eventHandle = eventResult.value;
    overlapped.ref.hEvent = eventHandle;
  }

  final int id;
  final int pipeHandlePtr;
  final Completer<int> completer = Completer<int>();
  final Pointer<OVERLAPPED> overlapped;
  final Pointer<Uint32> bytesTransferred;
  final Pointer<Uint8>? buffer;
  final bool closedErrorsAreEof;
  HANDLE? eventHandle;
  Pointer<Pointer<Void>>? waitHandle;
  bool _disposed = false;

  void register() {
    waitHandle = calloc<Pointer<Void>>();
    _pendingOperations[id] = this;

    final registered = _registerWaitForSingleObject(
      waitHandle!,
      eventHandle!.cast<Void>(),
      _waitCallback.nativeFunction,
      Pointer<Void>.fromAddress(id),
      INFINITE,
      _wtExecuteOnlyOnce,
    );

    if (registered == FALSE) {
      _pendingOperations.remove(id);
      final error = GetLastError().code;
      CancelIoEx(HANDLE(Pointer.fromAddress(pipeHandlePtr)), overlapped);
      dispose();
      throw Win32NamedPipeException('RegisterWaitForSingleObject', error);
    }
  }

  void _onWaitComplete() {
    if (_disposed) return;

    final result = GetOverlappedResult(
      HANDLE(Pointer.fromAddress(pipeHandlePtr)),
      overlapped,
      bytesTransferred,
      false,
    );

    if (result.value) {
      if (!completer.isCompleted) {
        completer.complete(bytesTransferred.value);
      }
      return;
    }

    final error = result.error.code;
    if (!completer.isCompleted) {
      if (_isPipeClosedError(error) || error == ERROR_OPERATION_ABORTED.code) {
        if (closedErrorsAreEof) {
          completer.complete(0);
        } else {
          dispose();
          completer.completeError(
            Win32NamedPipeException('GetOverlappedResult', error),
          );
        }
      } else {
        dispose();
        completer.completeError(
          Win32NamedPipeException('GetOverlappedResult', error),
        );
      }
    }
  }

  void complete(int bytes) {
    dispose();
    if (!completer.isCompleted) {
      completer.complete(bytes);
    }
  }

  Uint8List completeRead(int bytes) {
    final data = Uint8List.fromList(buffer!.asTypedList(bytes));
    dispose();
    return data;
  }

  int completeWrite(int bytes) {
    dispose();
    return bytes;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;

    final registeredWaitHandle = waitHandle;
    if (registeredWaitHandle != null) {
      final handle = registeredWaitHandle.value;
      if (handle.address != 0) {
        _unregisterWaitEx(handle, nullptr);
      }
      calloc.free(registeredWaitHandle);
      waitHandle = null;
    }

    final event = eventHandle;
    if (event != null && event.isValid) {
      CloseHandle(event);
      eventHandle = null;
    }
    calloc.free(bytesTransferred);
    final nativeBuffer = buffer;
    if (nativeBuffer != null) {
      calloc.free(nativeBuffer);
    }
    calloc.free(overlapped);

    _activeOperationCount--;
    if (_activeOperationCount == 0) {
      _waitCallback.keepIsolateAlive = false;
    }
  }
}
