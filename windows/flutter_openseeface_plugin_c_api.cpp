#include "include/flutter_openseeface_plugin/flutter_openseeface_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_openseeface_plugin.h"

void FlutterOpenseefacePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_openseeface_plugin::FlutterOpenseefacePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
