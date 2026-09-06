import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:dart_ipc/dart_ipc.dart' as ipc;
import 'package:ffi/ffi.dart';
import 'package:test/test.dart';
import 'package:win32/win32.dart';

void main() {
  group('IPC socket', () {
    late String path;

    setUp(() async {
      path = _testPath();
      if (!Platform.isWindows) {
        final socketFile = File(path);
        if (socketFile.existsSync()) {
          await socketFile.delete();
        }
      }
    });

    tearDown(() async {
      if (!Platform.isWindows) {
        final socketFile = File(path);
        if (socketFile.existsSync()) {
          await socketFile.delete();
        }
      }
    });

    test('exchanges bytes between a client and server', () async {
      final server = await ipc.bind(path);
      var serverClosed = false;
      addTearDown(() async {
        if (!serverClosed) {
          await server.close();
        }
      });

      final subscription = server.listen((socket) {
        socket.listen((data) {
          unawaited(() async {
            socket.add(utf8.encode('pong:${utf8.decode(data)}'));
            await socket.flush();
            await socket.close();
          }());
        });
      });
      addTearDown(subscription.cancel);

      final client = await ipc.connect(path).timeout(_timeout);
      client.add(utf8.encode('ping'));
      await client.flush();

      final response = await client.first.timeout(_timeout);
      expect(utf8.decode(response), 'pong:ping');

      await client.close();
      await subscription.cancel();
      await server.close();
      serverClosed = true;
    }, timeout: Timeout(_timeout));

    test('accepts multiple clients sequentially', () async {
      final server = await ipc.bind(path);
      var serverClosed = false;
      addTearDown(() async {
        if (!serverClosed) {
          await server.close();
        }
      });
      var clientIndex = 0;

      final subscription = server.listen((socket) {
        final acceptedIndex = clientIndex++;
        socket.listen((data) {
          unawaited(() async {
            socket.add(utf8.encode('ack-$acceptedIndex:${utf8.decode(data)}'));
            await socket.flush();
            await socket.close();
          }());
        });
      });
      addTearDown(subscription.cancel);

      for (var i = 0; i < 3; i++) {
        final client = await ipc.connect(path).timeout(_timeout);
        client.add(utf8.encode('message-$i'));
        await client.flush();

        final response = await client.first.timeout(_timeout);
        expect(utf8.decode(response), 'ack-$i:message-$i');
        await client.close();
      }

      await subscription.cancel();
      await server.close();
      serverClosed = true;
    }, timeout: Timeout(_timeout));

    test('close is idempotent for sockets and servers', () async {
      final server = await ipc.bind(path);
      final accepted = server.first;
      final client = await ipc.connect(path).timeout(_timeout);
      final peer = await accepted.timeout(_timeout);

      await client.close();
      await client.close();
      await peer.close();
      await peer.close();
      await server.close();
      await server.close();
    }, timeout: Timeout(_timeout));

    test('closing a server cancels a pending accept', () async {
      final server = await ipc.bind(path);
      final subscription = server.listen(null);

      await server.close().timeout(_timeout);
      await server.close().timeout(_timeout);
      await subscription.cancel();
    }, timeout: Timeout(_timeout));

    test(
      'releases Windows handles after client churn',
      () async {
        final handlesBefore = _windowsHandleCount();
        final server = await ipc.bind(path);
        final subscription = server.listen((socket) {
          socket.listen((data) {
            socket.add(data);
            unawaited(socket.flush());
          });
        });

        for (var i = 0; i < 100; i++) {
          final client = await ipc.connect(path).timeout(_timeout);
          client.add(const [1, 2, 3, 4]);
          await client.flush();
          expect(await client.first.timeout(_timeout), const [1, 2, 3, 4]);
          await client.close();
        }

        await subscription.cancel();
        await server.close();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final leakedHandles = _windowsHandleCount() - handlesBefore;
        expect(leakedHandles, lessThan(32));
      },
      skip: !Platform.isWindows,
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}

const _timeout = Duration(seconds: 10);
var _pathCounter = 0;

String _testPath() {
  final id =
      '${DateTime.now().microsecondsSinceEpoch}_${pid}_${_pathCounter++}';

  if (Platform.isWindows) {
    return r'\\.\pipe\dart_ipc_test_' + id;
  }

  return '/tmp/dipc_$id.sock';
}

int _windowsHandleCount() {
  final count = calloc<Uint32>();
  try {
    final process = Pointer<Void>.fromAddress(GetCurrentProcess().address);
    final result = _getProcessHandleCount(process, count);
    if (result == 0) {
      throw StateError('GetProcessHandleCount failed: ${GetLastError().code}');
    }
    return count.value;
  } finally {
    calloc.free(count);
  }
}

typedef _GetProcessHandleCountNative =
    Int32 Function(Pointer<Void> process, Pointer<Uint32> handleCount);
typedef _GetProcessHandleCountDart =
    int Function(Pointer<Void> process, Pointer<Uint32> handleCount);

final _getProcessHandleCount = DynamicLibrary.open('kernel32.dll')
    .lookupFunction<_GetProcessHandleCountNative, _GetProcessHandleCountDart>(
      'GetProcessHandleCount',
    );
