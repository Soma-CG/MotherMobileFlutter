//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <rive_native/rive_native_plugin.h>
#include <screen_brightness_windows/screen_brightness_windows_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  RiveNativePluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("RiveNativePlugin"));
  ScreenBrightnessWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("ScreenBrightnessWindowsPlugin"));
}
