/// Configuración centralizada de la URL del backend.
///
/// Por defecto apunta a Railway (producción).
/// Para desarrollo local en emulador:
///   flutter run --dart-define=API_HOST=http://10.0.2.2:8000
/// Para desarrollo local en dispositivo físico:
///   flutter run --dart-define=API_HOST=http://192.168.x.x:8000
class ApiConfig {
  ApiConfig._();

  static const String _productionUrl =
      'https://histolinkbackend-production.up.railway.app';

  // Override opcional vía --dart-define=API_HOST=...
  static const String _customHost =
      String.fromEnvironment('API_HOST', defaultValue: '');

  static String get baseUrl {
    if (_customHost.isNotEmpty) {
      if (_customHost.startsWith('http')) return _customHost;
      return 'http://$_customHost';
    }
    return _productionUrl;
  }

  /// Ruta para renovar el access token con el refresh.
  static const String tokenRefreshPath = '/api/auth/token/refresh/';

  static Uri uri(String path, [Map<String, String>? queryParameters]) {
    final base = Uri.parse('$baseUrl$path');
    if (queryParameters == null || queryParameters.isEmpty) return base;
    return base.replace(queryParameters: queryParameters);
  }
}
