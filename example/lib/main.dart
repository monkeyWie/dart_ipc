import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'dart:async';

import 'package:dart_ipc/dart_ipc.dart';
import 'package:json_rpc_2/json_rpc_2.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late String _path;

  @override
  void initState() {
    super.initState();

    if (Platform.isWindows) {
      _path = r"\\.\pipe\dart_ipc";
    } else {
      (() async {
        _path =
            path.join((await getTemporaryDirectory()).path, "dart_ipc.unix");
      })();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Row(
            children: [
              TextButton(
                  onPressed: () async {
                    final serverSocket = await bind(_path);

                    await for (final socket in serverSocket) {
                      print(socket);
                      socket.listen((data) {
                        print(utf8.decode(data));
                        socket.add('Hello from Server'.codeUnits);
                      }, onDone: () {
                        print("Server Done");
                      }, onError: (e) {
                        print("Server Error: $e");
                      });
                    }
                  },
                  child: Text("Server")),
              TextButton(
                  onPressed: () async {
                    final socket = await connect(_path);

                    socket.listen((data) {
                      print(utf8.decode(data));
                    }, onDone: () {
                      print("Client Done");
                    }, onError: (e) {
                      print("Client Error: $e");
                    });

                    for (var i = 0; i < 10; i++) {
                      socket.add(utf8.encode("Hello from client1 $i"));
                      await Future.delayed(Duration(seconds: 1));
                    }
                    await socket.close();
                  },
                  child: Text("Client1")),
              TextButton(
                  onPressed: () async {
                    final socket = await connect(_path);

                    socket.listen((data) {
                      print(utf8.decode(data));
                    }, onDone: () {
                      print("Client Done");
                    }, onError: (e) {
                      print("Client Error: $e");
                    });

                    for (var i = 0; i < 10; i++) {
                      socket.add(utf8.encode("Hello from client2 $i"));
                      await Future.delayed(Duration(seconds: 1));
                    }
                    await socket.close();
                  },
                  child: Text("Client2")),
              TextButton(
                  onPressed: () async {
                    final serverSocket = await bind(_path);
                    final httpServer = HttpServer.listenOn(serverSocket);
                    final connectedChannels = httpServer
                        .transform(WebSocketTransformer())
                        .map(IOWebSocketChannel.new);
                    connectedChannels.listen(handleClient);
                  },
                  child: Text("JsonRpcServer")),
              TextButton(
                  onPressed: () async {
                    final httpClient = HttpClient()
                      ..connectionFactory =
                          (Uri uri, String? proxyHost, int? proxyPort) {
                        final socket = connect(_path);
                        return Future.value(
                            ConnectionTask.fromSocket(socket, () {}));
                      };

                    // final webSocket = webSocketConnect();
                    final socket = IOWebSocketChannel.connect("ws://localhost",
                        customClient: httpClient);
                    var client = Client(socket.cast<String>());

                    // The client won't subscribe to the input stream until you call `listen`.
                    // The returned Future won't complete until the connection is closed.
                    unawaited(client.listen());

                    // This calls the "count" method on the server. A Future is returned that
                    // will complete to the value contained in the server's response.
                    var count = await client.sendRequest('count');
                    print('Count is $count');

                    // // Parameters are passed as a simple Map or, for positional parameters, an
                    // // Iterable. Make sure they're JSON-serializable!
                    var echo =
                        await client.sendRequest('echo', {'message': 'hello'});
                    print('Echo says "$echo"!');

                    // // A notification is a way to call a method that tells the server that no
                    // // result is expected. Its return type is `void`; even if it causes an
                    // // error, you won't hear back.
                    client.sendNotification('count');

                    // If the server sends an error response, the returned Future will complete
                    // with an RpcException. You can catch this error and inspect its error
                    // code, message, and any data that the server sent along with it.
                    try {
                      await client
                          .sendRequest('divide', {'dividend': 2, 'divisor': 0});
                    } on RpcException catch (error) {
                      print('RPC error ${error.code}: ${error.message}');
                    }
                  },
                  child: Text("JsonRpcClient")),
            ],
          ),
        ),
      ),
    );
  }

  void handleClient(WebSocketChannel socket) {
    // The socket is a `StreamChannel<dynamic>` because it might emit binary
    // `List<int>`, but JSON RPC 2 only works with Strings so we assert it only
    // emits those by casting it.
    var server = Server(socket.cast<String>());

    // Any string may be used as a method name. JSON-RPC 2.0 methods are
    // case-sensitive.
    var i = 0;
    server.registerMethod('count', () {
      // Just return the value to be sent as a response to the client. This can
      // be anything JSON-serializable, or a Future that completes to something
      // JSON-serializable.
      return i++;
    });

    // Methods can take parameters. They're presented as a `Parameters` object
    // which makes it easy to validate that the expected parameters exist.
    server.registerMethod('echo', (Parameters params) {
      // If the request doesn't have a "message" parameter this will
      // automatically send a response notifying the client that the request
      // was invalid.
      return params['message'].value;
    });

    // `Parameters` has methods for verifying argument types.
    server.registerMethod('subtract', (Parameters params) {
      // If "minuend" or "subtrahend" aren't numbers, this will reject the
      // request.
      return params['minuend'].asNum - params['subtrahend'].asNum;
    });

    // [Parameters] also supports optional arguments.
    server.registerMethod('sort', (Parameters params) {
      var list = params['list'].asList;
      list.sort();
      if (params['descendint'].asBoolOr(false)) {
        return list.reversed;
      } else {
        return list;
      }
    });

    // A method can send an error response by throwing a `RpcException`.
    // Any positive number may be used as an application- defined error code.
    const divideByZero = 1;
    server.registerMethod('divide', (Parameters params) {
      var divisor = params['divisor'].asNum;
      if (divisor == 0) {
        throw RpcException(divideByZero, 'Cannot divide by zero.');
      }

      return params['dividend'].asNum / divisor;
    });

    // To give you time to register all your methods, the server won't start
    // listening for requests until you call `listen`. Messages are buffered until
    // listen is called. The returned Future won't complete until the connection
    // is closed.
    server.listen();
  }
}
