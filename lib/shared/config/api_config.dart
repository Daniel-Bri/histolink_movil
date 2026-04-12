import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

/// Host y rutas base de la API.
class ApiConfig {
  ApiConfig._();

  /// URL de producción en Railway.
  static const String _productionBase = 'https://histolinkbackend-production.up.railway.app';

  /// URL local para emulador Android / web dev.
  static String get _devBase =>
      kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';

  /// Base URL activa según el modo de build.
  static String get baseUrl => kReleaseMode ? _productionBase : _devBase;

  /// Ruta POST para renovar access token.
  static const String tokenRefreshPath = '/api/auth/token/refresh/';

  static Uri uri(String path, [Map<String, String>? queryParameters]) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$p').replace(queryParameters: queryParameters);
  }
}
