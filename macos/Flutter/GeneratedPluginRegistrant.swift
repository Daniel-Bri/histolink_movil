//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import file_picker
import flutter_secure_storage_macos
<<<<<<< HEAD
import url_launcher_macos
=======
import share_plus
import shared_preferences_foundation
import speech_to_text
>>>>>>> 9cf1fbf (T042 Pantalla reportes movil: filtros simplificados + texto libre + boton de voz con speech_to_text +exportar (CSV, Excel, PDF))

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  FilePickerPlugin.register(with: registry.registrar(forPlugin: "FilePickerPlugin"))
  FlutterSecureStoragePlugin.register(with: registry.registrar(forPlugin: "FlutterSecureStoragePlugin"))
<<<<<<< HEAD
  UrlLauncherPlugin.register(with: registry.registrar(forPlugin: "UrlLauncherPlugin"))
=======
  SharePlusMacosPlugin.register(with: registry.registrar(forPlugin: "SharePlusMacosPlugin"))
  SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
  SpeechToTextPlugin.register(with: registry.registrar(forPlugin: "SpeechToTextPlugin"))
>>>>>>> 9cf1fbf (T042 Pantalla reportes movil: filtros simplificados + texto libre + boton de voz con speech_to_text +exportar (CSV, Excel, PDF))
}
