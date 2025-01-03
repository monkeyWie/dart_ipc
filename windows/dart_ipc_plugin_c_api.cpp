#include "include/dart_ipc/dart_ipc_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "dart_ipc_plugin.h"

void DartIpcPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  dart_ipc::DartIpcPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
