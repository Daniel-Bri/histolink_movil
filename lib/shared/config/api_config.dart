import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

/// Configuración centralizada de la URL del backend.
///
/// Prioridad:
///   1. --dart-define=API_HOST=https://mi-backend.railway.app  (build personalizado)
///   2. En desarrollo móvil: backend local (IP LAN)
///   3. En release: URL de Railway
class ApiConfig {
  ApiConfig._();

  // URL de producción en Railway
  static const String _railwayUrl = 'https://histolinkbackend-production.up.railway.app';
  static const String _localLanHost = '192.168.0.108:8000';

  // Override opcional vía --dart-define=API_HOST=...
  static const String _customHost = String.fromEnvironment('API_HOST', defaultValue: '');

  static String get baseUrl {
    if (_customHost.isNotEmpty) {
      if (_customHost.startsWith('http')) return _customHost;
      return 'http://$_customHost';
    }
    if (!kIsWeb && !kReleaseMode) {
      return 'http://$_localLanHost';
    }
    return _railwayUrl;
  }

  /// Ruta para renovar el access token con el refresh.
  static const String tokenRefreshPath = '/api/auth/token/refresh/';

  static Uri uri(String path, [Map<String, String>? queryParameters]) {
    final base = Uri.parse('$baseUrl$path');
    if (queryParameters == null || queryParameters.isEmpty) return base;
    return base.replace(queryParameters: queryParameters);
  }
}
