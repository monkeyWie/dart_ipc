#include "dart_ipc_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <tchar.h>

#include <cstring>
#include <memory>
#include <string>

namespace dart_ipc {

// static
void DartIpcPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
    auto channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), "pub.dev/dart_ipc",
            &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<DartIpcPlugin>();

    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto &call, auto result) {
            plugin_pointer->HandleMethodCall(call, std::move(result));
        });


    registrar->AddPlugin(std::move(plugin));
}

DartIpcPlugin::DartIpcPlugin() {
}

DartIpcPlugin::~DartIpcPlugin() {
}

void DartIpcPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    auto method_name = method_call.method_name();
    if (method_name.compare("accept") == 0) {
        HandleAccept(method_call, std::move(result));
    } else if (method_name.compare("connect") == 0) {
        HandleConnect(method_call, std::move(result));
    } else if (method_name.compare("read") == 0) {
        HandleRead(method_call, std::move(result));
    } else if (method_name.compare("write") == 0) {
        HandleWrite(method_call, std::move(result));
    } else if (method_name.compare("close") == 0) {
        HandleClose(method_call, std::move(result));
    } else {
        result->NotImplemented();
    }
}

enum class EventType {
    Accept,
    Read,
    Write
};

struct Context {
    EventType eventType;
    HANDLE pipeHandle;
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result;
    OVERLAPPED *overlapped;
    BYTE *buffer;
};

void CALLBACK HandlePipeEvent(PVOID lpParameter, BOOLEAN TimerOrWaitFired) {
    auto *context          = static_cast<Context *>(lpParameter);
    HANDLE pipeHandle      = context->pipeHandle;
    auto result            = std::move(context->result);
    OVERLAPPED *overlapped = context->overlapped;
    EventType eventType    = context->eventType;

    DWORD bytesTransferred;
    if (GetOverlappedResult(pipeHandle, overlapped, &bytesTransferred, FALSE)) {
        switch (eventType) {
            case EventType::Accept: {
                auto pipeHandlePtr = reinterpret_cast<intptr_t>(pipeHandle);
                result->Success(flutter::EncodableValue(pipeHandlePtr));
                break;
            }
            case EventType::Read: {
                std::vector<uint8_t> vec(context->buffer, context->buffer + bytesTransferred);
                result->Success(flutter::EncodableValue(vec));
                delete[] context->buffer;
                break;
            }
            case EventType::Write: {
                result->Success(static_cast<int>(bytesTransferred));
                break;
            }
        }
    } else {
        result->Error(std::to_string(GetLastError()), "Operation failed");
    }

    CloseHandle(overlapped->hEvent);
    delete overlapped;
    delete context;
}

void DartIpcPlugin::HandleAccept(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const flutter::EncodableMap &args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    auto path = std::get<std::string>(args.at(flutter::EncodableValue("path")));
    std::wstring wpath(path.begin(), path.end());

    auto pipeHandle = CreateNamedPipe(
        wpath.c_str(),
        PIPE_ACCESS_DUPLEX | FILE_FLAG_OVERLAPPED,
        PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT,
        PIPE_UNLIMITED_INSTANCES,
        BUFSIZE * sizeof(TCHAR),  // output buffer size
        BUFSIZE * sizeof(TCHAR),  // input buffer size
        PIPE_TIMEOUT,             // client time-out
        NULL);

    if (pipeHandle == INVALID_HANDLE_VALUE) {
        result->Error(std::to_string(GetLastError()), "CreateNamedPipe failed");
        return;
    }

    auto *overlapped   = new OVERLAPPED{0};
    overlapped->hEvent = CreateEvent(NULL, TRUE, FALSE, NULL);
    if (!ConnectNamedPipe(pipeHandle, overlapped)) {
        if (GetLastError() == ERROR_IO_PENDING) {
            auto *context = new Context{EventType::Accept, pipeHandle, std::move(result), overlapped, nullptr};
            RegisterWaitForSingleObject(&overlapped->hEvent, overlapped->hEvent, HandlePipeEvent, context, INFINITE, WT_EXECUTEONLYONCE);
            return;
        } else {
            CloseHandle(overlapped->hEvent);
            delete overlapped;
            result->Error(std::to_string(GetLastError()), "ConnectNamedPipe failed");
            return;
        }
    } else {
        auto pipeHandlePtr = reinterpret_cast<intptr_t>(pipeHandle);
        result->Success(flutter::EncodableValue(pipeHandlePtr));
        CloseHandle(overlapped->hEvent);
        delete overlapped;
    }
}

void DartIpcPlugin::HandleConnect(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const flutter::EncodableMap &args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    auto path = std::get<std::string>(args.at(flutter::EncodableValue("path")));
    std::wstring wpath(path.begin(), path.end());

    auto pipeHandle = CreateFile(
        wpath.c_str(),
        GENERIC_READ | GENERIC_WRITE,
        0,
        NULL,
        OPEN_EXISTING,
        FILE_FLAG_OVERLAPPED,
        NULL);

    if (pipeHandle == INVALID_HANDLE_VALUE) {
        result->Error(std::to_string(GetLastError()), "CreateFile failed");
        return;
    }

    auto pipeHandlePtr = reinterpret_cast<intptr_t>(pipeHandle);
    result->Success(flutter::EncodableValue(pipeHandlePtr));
}

void DartIpcPlugin::HandleRead(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const flutter::EncodableMap &args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    auto pipeHandlePtr = static_cast<intptr_t>(std::get<int>(args.at(flutter::EncodableValue("pipeHandlePtr"))));
    auto pipeHandle    = reinterpret_cast<HANDLE>(pipeHandlePtr);

    if (pipeHandle == INVALID_HANDLE_VALUE || pipeHandle == NULL) {
        result->Error(std::to_string(ERROR_INVALID_HANDLE), "Invalid pipe handle");
        return;
    }

    auto *overlapped   = new OVERLAPPED{0};
    overlapped->hEvent = CreateEvent(NULL, TRUE, FALSE, NULL);
    BYTE *buffer       = new BYTE[BUFSIZE];
    DWORD bytesRead;
    if (!ReadFile(pipeHandle, buffer, BUFSIZE, &bytesRead, overlapped)) {
        if (GetLastError() == ERROR_IO_PENDING) {
            auto *context = new Context{EventType::Read, pipeHandle, std::move(result), overlapped, buffer};
            RegisterWaitForSingleObject(&overlapped->hEvent, overlapped->hEvent, HandlePipeEvent, context, INFINITE, WT_EXECUTEONLYONCE);
            return;
        } else {
            DWORD error = GetLastError();
            CloseHandle(overlapped->hEvent);
            delete[] buffer;
            delete overlapped;
            result->Error(std::to_string(error), "ReadFile failed");
            return;
        }
    } else {
        std::vector<uint8_t> vec(buffer, buffer + bytesRead);
        result->Success(flutter::EncodableValue(vec));
        delete[] buffer;
        CloseHandle(overlapped->hEvent);
        delete overlapped;
    }
}

void DartIpcPlugin::HandleWrite(const flutter::MethodCall<flutter::EncodableValue> &method_call,
                                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const flutter::EncodableMap &args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    auto pipeHandlePtr = static_cast<intptr_t>(std::get<int>(args.at(flutter::EncodableValue("pipeHandlePtr"))));
    auto pipeHandle    = reinterpret_cast<HANDLE>(pipeHandlePtr);
    auto data          = std::get<std::vector<uint8_t>>(args.at(flutter::EncodableValue("data")));

    if (pipeHandle == INVALID_HANDLE_VALUE || pipeHandle == NULL) {
        result->Error(std::to_string(ERROR_INVALID_HANDLE), "Invalid pipe handle");
        return;
    }

    auto *overlapped   = new OVERLAPPED{0};
    overlapped->hEvent = CreateEvent(NULL, TRUE, FALSE, NULL);
    if (overlapped->hEvent == NULL) {
        delete overlapped;
        result->Error(std::to_string(GetLastError()), "CreateEvent failed");
        return;
    }

    DWORD bytesWritten;
    if (!WriteFile(pipeHandle, data.data(), static_cast<DWORD>(data.size()), &bytesWritten, overlapped)) {
        if (GetLastError() == ERROR_IO_PENDING) {
            auto *context = new Context{EventType::Write, pipeHandle, std::move(result), overlapped, nullptr};
            RegisterWaitForSingleObject(&overlapped->hEvent, overlapped->hEvent, HandlePipeEvent, context, INFINITE, WT_EXECUTEONLYONCE);
            return;
        } else {
            DWORD error = GetLastError();
            CloseHandle(overlapped->hEvent);
            delete overlapped;
            result->Error(std::to_string(error), "WriteFile failed");
            return;
        }
    } else {
        result->Success(static_cast<int>(bytesWritten));
        CloseHandle(overlapped->hEvent);
        delete overlapped;
    }
}

void DartIpcPlugin::HandleClose(const flutter::MethodCall<flutter::EncodableValue> &method_call,
                                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const flutter::EncodableMap &args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    auto pipeHandlePtr = static_cast<intptr_t>(std::get<int>(args.at(flutter::EncodableValue("pipeHandlePtr"))));
    auto pipeHandle    = reinterpret_cast<HANDLE>(pipeHandlePtr);

    auto success = CloseHandle(pipeHandle);
    if (!success) {
        result->Error(std::to_string(GetLastError()), "CloseHandle failed");
        return;
    }

    result->Success();
}

}  // namespace dart_ipc
