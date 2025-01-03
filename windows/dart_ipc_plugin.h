#ifndef FLUTTER_PLUGIN_DART_IPC_PLUGIN_H_
#define FLUTTER_PLUGIN_DART_IPC_PLUGIN_H_

#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <unordered_map>

namespace dart_ipc {

#define PIPE_TIMEOUT 5000
#define BUFSIZE 4096

class DartIpcPlugin : public flutter::Plugin {
   public:
    static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

    DartIpcPlugin();

    virtual ~DartIpcPlugin();

    // Disallow copy and assign.
    DartIpcPlugin(const DartIpcPlugin &) = delete;
    DartIpcPlugin &operator=(const DartIpcPlugin &) = delete;

    void HandleAccept(
        const flutter::MethodCall<flutter::EncodableValue> &method_call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
    void HandleConnect(
        const flutter::MethodCall<flutter::EncodableValue> &method_call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
    void HandleRead(
        const flutter::MethodCall<flutter::EncodableValue> &method_call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
    void HandleWrite(
        const flutter::MethodCall<flutter::EncodableValue> &method_call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
    void HandleClose(
        const flutter::MethodCall<flutter::EncodableValue> &method_call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    // Called when a method is called on this plugin's channel from Dart.
    void HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue> &method_call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace dart_ipc

#endif  // FLUTTER_PLUGIN_DART_IPC_PLUGIN_H_
