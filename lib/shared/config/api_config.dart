
/// Configuración centralizada de la URL del backend.
///
/// - Producción (Railway) : histolinkbackend-production.up.railway.app
/// - Override manual      : --dart-define=API_HOST=http://ip:8000
class ApiConfig {
  ApiConfig._();

  static const String _railwayHost =
      'histolinkbackend-production.up.railway.app';

  // Override opcional vía --dart-define=API_HOST=...
  static const String _customHost =
      String.fromEnvironment('API_HOST', defaultValue: '');

  static String get baseUrl {
    if (_customHost.isNotEmpty) {
      if (_customHost.startsWith('http')) return _customHost;
      return 'https://$_customHost';
    }
    return 'https://$_railwayHost';
  }

  /// Ruta para renovar el access token con el refresh.
  static const String tokenRefreshPath = '/api/auth/token/refresh/';

  static Uri uri(String path, [Map<String, String>? queryParameters]) {
    final base = Uri.parse('$baseUrl$path');
    if (queryParameters == null || queryParameters.isEmpty) return base;
    return base.replace(queryParameters: queryParameters);
  }
}
