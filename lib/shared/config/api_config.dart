import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

/// Configuración centralizada de la URL del backend.
///
/// En debug apunta siempre al backend local:
///   - Emulador Android : 10.0.2.2:8000
///   - Dispositivo físico: cambiar _localHost a la IP LAN del PC (ej. 192.168.0.108:8000)
///
/// Override manual: --dart-define=API_HOST=http://ip:8000
class ApiConfig {
  ApiConfig._();

  // Para emulador Android usa 10.0.2.2 (alias del localhost del PC).
  // Para dispositivo físico cambia a la IP LAN: '192.168.x.x:8000'
  static const String _localHost = '10.0.2.2:8000';

  // Override opcional vía --dart-define=API_HOST=...
  static const String _customHost = String.fromEnvironment('API_HOST', defaultValue: '');

  static String get baseUrl {
    if (_customHost.isNotEmpty) {
      if (_customHost.startsWith('http')) return _customHost;
      return 'http://$_customHost';
    }
    return 'http://$_localHost';
  }

  /// Ruta para renovar el access token con el refresh.
  static const String tokenRefreshPath = '/api/auth/token/refresh/';

  static Uri uri(String path, [Map<String, String>? queryParameters]) {
    final base = Uri.parse('$baseUrl$path');
    if (queryParameters == null || queryParameters.isEmpty) return base;
    return base.replace(queryParameters: queryParameters);
  }
}
