import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_ipc/dart_ipc.dart' as ipc;
import 'package:test/test.dart';

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
  });
}

const _timeout = Duration(seconds: 10);
var _pathCounter = 0;

String _testPath() {
  final id = '${DateTime.now().microsecondsSinceEpoch}_${pid}_${_pathCounter++}';

  if (Platform.isWindows) {
    return r'\\.\pipe\dart_ipc_test_' + id;
  }

  return '/tmp/dipc_$id.sock';
}
