## 2.0.2

* Isolate native IPC implementations from web compilation.
* Provide unsupported-operation stubs when the package is imported on web.

## 2.0.1

* Fix Windows named pipe handle ownership and idempotent socket/server shutdown.
* Wait for registered overlapped-I/O callbacks to finish before releasing native resources.
* Release sockets after EOF or errors and retry transient pipe startup races.

## 2.0.0

* Replace the Windows Flutter method-channel plugin with an overlapped-I/O Dart FFI named pipe implementation using `win32` 6.3.0.
* Add iOS platform support using Unix domain sockets.
* Raise the minimum Dart SDK constraint to 3.10.0.

## 1.0.1

* Update documentation and example.

## 1.0.0

* First release.
