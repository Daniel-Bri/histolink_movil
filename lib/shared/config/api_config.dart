import 'package:flutter/foundation.dart' show kIsWeb;

/// Configuración centralizada de la URL del backend.
///
/// - Web (navegador)      : localhost:8000
/// - Emulador Android     : 10.0.2.2:8000
/// - Dispositivo físico   : cambiar _mobileHost a la IP LAN del PC
///
/// Override manual: --dart-define=API_HOST=http://ip:8000
class ApiConfig {
  ApiConfig._();

  // Web: el navegador accede al backend como localhost
  static const String _webHost = 'localhost:8000';

  // Emulador Android: 10.0.2.2 es el alias del localhost del PC.
  // Para dispositivo físico cambiar a la IP LAN: '192.168.x.x:8000'
   // Celular físico por USB con adb reverse
  static const String _mobileHost = '127.0.0.1:8000';

  static const String _customHost =
      String.fromEnvironment('API_HOST', defaultValue: '');

  static String get baseUrl {
    if (_customHost.isNotEmpty) {
      if (_customHost.startsWith('http')) return _customHost;
      return 'http://$_customHost';
    }
    return kIsWeb ? 'http://$_webHost' : 'http://$_mobileHost';
  }

  /// Ruta para renovar el access token con el refresh.
  static const String tokenRefreshPath = '/api/auth/token/refresh/';

  static Uri uri(String path, [Map<String, String>? queryParameters]) {
    final base = Uri.parse('$baseUrl$path');
    if (queryParameters == null || queryParameters.isEmpty) return base;
    return base.replace(queryParameters: queryParameters);
  }
}
