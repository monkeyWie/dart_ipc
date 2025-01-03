import 'dart:async';
import 'dart:io';

import 'dart_ipc_platform_interface.dart';

class Win32NamedPipeServerSocket implements ServerSocket {
  final String _path;
  final StreamController<Socket> _controller;
  final List<int> _pipeHandlePtrArr = [];
  bool _isClosed = false;

  factory Win32NamedPipeServerSocket(
      String path, StreamController<Socket> controller) {
    return Win32NamedPipeServerSocket._(path, controller);
  }

  Win32NamedPipeServerSocket._(this._path, this._controller);

  String get path => _path;

  bool get isClosed => _isClosed;

  @override
  InternetAddress get address =>
      InternetAddress("127.0.0.1", type: InternetAddressType.unix);

  @override
  Future<bool> any(bool Function(Socket element) test) {
    return _controller.stream.any(test);
  }

  @override
  Stream<Socket> asBroadcastStream(
      {void Function(StreamSubscription<Socket> subscription)? onListen,
      void Function(StreamSubscription<Socket> subscription)? onCancel}) {
    return _controller.stream
        .asBroadcastStream(onListen: onListen, onCancel: onCancel);
  }

  @override
  Stream<E> asyncExpand<E>(Stream<E>? Function(Socket event) convert) {
    return _controller.stream.asyncExpand(convert);
  }

  @override
  Stream<E> asyncMap<E>(FutureOr<E> Function(Socket event) convert) {
    return _controller.stream.asyncMap(convert);
  }

  @override
  Stream<R> cast<R>() {
    return _controller.stream.cast<R>();
  }

  @override
  Future<ServerSocket> close() async {
    _isClosed = true;
    await _controller.close();
    for (var pipeHandlePtr in _pipeHandlePtrArr) {
      await DartIpcPlatform.instance.close(pipeHandlePtr);
    }
    return this;
  }

  @override
  Future<bool> contains(Object? needle) {
    return _controller.stream.contains(needle);
  }

  @override
  Stream<Socket> distinct(
      [bool Function(Socket previous, Socket next)? equals]) {
    return _controller.stream.distinct(equals);
  }

  @override
  Future<E> drain<E>([E? futureValue]) {
    return _controller.stream.drain(futureValue);
  }

  @override
  Future<Socket> elementAt(int index) {
    return _controller.stream.elementAt(index);
  }

  @override
  Future<bool> every(bool Function(Socket element) test) {
    return _controller.stream.every(test);
  }

  @override
  Stream<S> expand<S>(Iterable<S> Function(Socket element) convert) {
    return _controller.stream.expand(convert);
  }

  @override
  Future<Socket> get first => _controller.stream.first;

  @override
  Future<Socket> firstWhere(bool Function(Socket element) test,
      {Socket Function()? orElse}) {
    return _controller.stream.firstWhere(test, orElse: orElse);
  }

  @override
  Future<S> fold<S>(
      S initialValue, S Function(S previous, Socket element) combine) {
    return _controller.stream.fold(initialValue, combine);
  }

  @override
  Future<void> forEach(void Function(Socket element) action) {
    return _controller.stream.forEach(action);
  }

  @override
  Stream<Socket> handleError(Function onError,
      {bool Function(dynamic error)? test}) {
    return _controller.stream.handleError(onError, test: test);
  }

  @override
  bool get isBroadcast => _controller.stream.isBroadcast;

  @override
  Future<bool> get isEmpty => _controller.stream.isEmpty;

  @override
  Future<String> join([String separator = ""]) {
    return _controller.stream.join(separator);
  }

  @override
  Future<Socket> get last => _controller.stream.last;

  @override
  Future<Socket> lastWhere(bool Function(Socket element) test,
      {Socket Function()? orElse}) {
    return _controller.stream.lastWhere(test, orElse: orElse);
  }

  @override
  Future<int> get length => _controller.stream.length;

  @override
  StreamSubscription<Socket> listen(void Function(Socket event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _controller.stream.listen((event) {
      _pipeHandlePtrArr.add(event.port);
      onData?.call(event);
    }, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  Stream<S> map<S>(S Function(Socket event) convert) {
    return _controller.stream.map(convert);
  }

  @override
  Future pipe(StreamConsumer<Socket> streamConsumer) {
    return _controller.stream.pipe(streamConsumer);
  }

  @override
  int get port => 0;

  @override
  Future<Socket> reduce(
      Socket Function(Socket previous, Socket element) combine) {
    return _controller.stream.reduce(combine);
  }

  @override
  Future<Socket> get single => _controller.stream.single;

  @override
  Future<Socket> singleWhere(bool Function(Socket element) test,
      {Socket Function()? orElse}) {
    return _controller.stream.singleWhere(test, orElse: orElse);
  }

  @override
  Stream<Socket> skip(int count) {
    return _controller.stream.skip(count);
  }

  @override
  Stream<Socket> skipWhile(bool Function(Socket element) test) {
    return _controller.stream.skipWhile(test);
  }

  @override
  Stream<Socket> take(int count) {
    return _controller.stream.take(count);
  }

  @override
  Stream<Socket> takeWhile(bool Function(Socket element) test) {
    return _controller.stream.takeWhile(test);
  }

  @override
  Stream<Socket> timeout(Duration timeLimit,
      {void Function(EventSink<Socket> sink)? onTimeout}) {
    return _controller.stream.timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Future<List<Socket>> toList() {
    return _controller.stream.toList();
  }

  @override
  Future<Set<Socket>> toSet() {
    return _controller.stream.toSet();
  }

  @override
  Stream<S> transform<S>(StreamTransformer<Socket, S> streamTransformer) {
    return _controller.stream.transform(streamTransformer);
  }

  @override
  Stream<Socket> where(bool Function(Socket event) test) {
    return _controller.stream.where(test);
  }
}
