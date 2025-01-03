import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'dart_ipc_platform_interface.dart';

class Win32NamedPipeStreamConsumer implements StreamConsumer<List<int>> {
  final int _pipeHandlePtr;

  Win32NamedPipeStreamConsumer(this._pipeHandlePtr);

  @override
  Future addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      await DartIpcPlatform.instance
          .write(_pipeHandlePtr, Uint8List.fromList(data));
    }
    return Future.value();
  }

  @override
  Future close() {
    return DartIpcPlatform.instance.close(_pipeHandlePtr);
  }
}

class Win32NamedPipeSocket implements Socket {
  final String _path;
  final int _pipeHandlePtr;
  final Stream<Uint8List> _stream;
  final IOSink _sink;

  factory Win32NamedPipeSocket(String path, int pipeHandlePtr) {
    final streamController = StreamController<Uint8List>();
    () async {
      while (true) {
        try {
          final data = await DartIpcPlatform.instance.read(pipeHandlePtr);
          if (data.isEmpty) {
            break;
          }
          streamController.add(data);
        } catch (e) {
          // Pipe is closed
          if (e is PlatformException && ["109"].contains(e.code)) {
            break;
          }
          rethrow;
        }
      }
      streamController.close();
    }();

    return Win32NamedPipeSocket._(path, pipeHandlePtr, streamController.stream,
        IOSink(Win32NamedPipeStreamConsumer(pipeHandlePtr)));
  }

  Win32NamedPipeSocket._(
      this._path, this._pipeHandlePtr, this._stream, this._sink);

  String get path => _path;

  @override
  Encoding encoding = utf8;

  @override
  void add(List<int> data) {
    _sink.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _sink.addError(error, stackTrace);
  }

  @override
  Future addStream(Stream<List<int>> stream) {
    return _sink.addStream(stream);
  }

  @override
  InternetAddress get address =>
      InternetAddress("127.0.0.1", type: InternetAddressType.unix);

  @override
  Future<bool> any(bool Function(Uint8List element) test) {
    return _stream.any(test);
  }

  @override
  Stream<Uint8List> asBroadcastStream(
      {void Function(StreamSubscription<Uint8List> subscription)? onListen,
      void Function(StreamSubscription<Uint8List> subscription)? onCancel}) {
    return _stream.asBroadcastStream(onListen: onListen, onCancel: onCancel);
  }

  @override
  Stream<E> asyncExpand<E>(Stream<E>? Function(Uint8List event) convert) {
    return _stream.asyncExpand(convert);
  }

  @override
  Stream<E> asyncMap<E>(FutureOr<E> Function(Uint8List event) convert) {
    return _stream.asyncMap(convert);
  }

  @override
  Stream<R> cast<R>() => _stream.cast<R>();

  @override
  Future close() async {
    await _sink.close();
    return Future.value();
  }

  @override
  Future<bool> contains(Object? needle) {
    return _stream.contains(needle);
  }

  @override
  void destroy() {
    close();
  }

  @override
  Stream<Uint8List> distinct(
      [bool Function(Uint8List previous, Uint8List next)? equals]) {
    return _stream.distinct(equals);
  }

  @override
  Future get done => _sink.done;

  @override
  Future<E> drain<E>([E? futureValue]) {
    return _stream.drain(futureValue);
  }

  @override
  Future<Uint8List> elementAt(int index) {
    return _stream.elementAt(index);
  }

  @override
  Future<bool> every(bool Function(Uint8List element) test) {
    return _stream.every(test);
  }

  @override
  Stream<S> expand<S>(Iterable<S> Function(Uint8List element) convert) {
    return _stream.expand(convert);
  }

  @override
  Future<Uint8List> get first => _stream.first;

  @override
  Future<Uint8List> firstWhere(bool Function(Uint8List element) test,
      {Uint8List Function()? orElse}) {
    return _stream.firstWhere(test, orElse: orElse);
  }

  @override
  Future flush() async {
    return _sink.flush();
  }

  @override
  Future<S> fold<S>(
      S initialValue, S Function(S previous, Uint8List element) combine) {
    return _stream.fold(initialValue, combine);
  }

  @override
  Future<void> forEach(void Function(Uint8List element) action) {
    return _stream.forEach(action);
  }

  @override
  Uint8List getRawOption(RawSocketOption option) {
    // 命名管道不支持 socket 选项
    throw UnsupportedError('Named pipes do not support socket options');
  }

  @override
  Stream<Uint8List> handleError(Function onError,
      {bool Function(dynamic error)? test}) {
    return _stream.handleError(onError, test: test);
  }

  @override
  bool get isBroadcast => _stream.isBroadcast;

  @override
  Future<bool> get isEmpty => _stream.isEmpty;

  @override
  Future<String> join([String separator = ""]) {
    return _stream.map((data) => String.fromCharCodes(data)).join(separator);
  }

  @override
  Future<Uint8List> get last => _stream.last;

  @override
  Future<Uint8List> lastWhere(bool Function(Uint8List element) test,
      {Uint8List Function()? orElse}) {
    return _stream.lastWhere(test, orElse: orElse);
  }

  @override
  Future<int> get length => _stream.length;

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Stream<S> map<S>(S Function(Uint8List event) convert) {
    return _stream.map(convert);
  }

  @override
  Future pipe(StreamConsumer<Uint8List> streamConsumer) {
    return _stream.pipe(streamConsumer);
  }

  @override
  int get port => _pipeHandlePtr; // 命名管道没有端口概念

  @override
  Future<Uint8List> reduce(
      Uint8List Function(Uint8List previous, Uint8List element) combine) {
    return _stream.reduce(combine);
  }

  @override
  InternetAddress get remoteAddress => address;

  @override
  int get remotePort => 0; // 命名管道没有端口概念

  @override
  bool setOption(SocketOption option, bool enabled) {
    // 命名管道不支持 socket 选项
    return false;
  }

  @override
  void setRawOption(RawSocketOption option) {
    // 命名管道不支持 socket 选项
  }

  @override
  Future<Uint8List> get single => _stream.single;

  @override
  Future<Uint8List> singleWhere(bool Function(Uint8List element) test,
      {Uint8List Function()? orElse}) {
    return _stream.singleWhere(test, orElse: orElse);
  }

  @override
  Stream<Uint8List> skip(int count) {
    return _stream.skip(count);
  }

  @override
  Stream<Uint8List> skipWhile(bool Function(Uint8List element) test) {
    return _stream.skipWhile(test);
  }

  @override
  Stream<Uint8List> take(int count) {
    return _stream.take(count);
  }

  @override
  Stream<Uint8List> takeWhile(bool Function(Uint8List element) test) {
    return _stream.takeWhile(test);
  }

  @override
  Stream<Uint8List> timeout(Duration timeLimit,
      {void Function(EventSink<Uint8List> sink)? onTimeout}) {
    return _stream.timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Future<List<Uint8List>> toList() {
    return _stream.toList();
  }

  @override
  Future<Set<Uint8List>> toSet() {
    return _stream.toSet();
  }

  @override
  Stream<S> transform<S>(StreamTransformer<Uint8List, S> streamTransformer) {
    return _stream.transform(streamTransformer);
  }

  @override
  Stream<Uint8List> where(bool Function(Uint8List event) test) {
    return _stream.where(test);
  }

  @override
  void write(Object? object) {
    _sink.write(object);
  }

  @override
  void writeAll(Iterable objects, [String separator = ""]) {
    _sink.writeAll(objects, separator);
  }

  @override
  void writeCharCode(int charCode) {
    _sink.writeCharCode(charCode);
  }

  @override
  void writeln([Object? object = ""]) {
    _sink.writeln(object);
  }
}
