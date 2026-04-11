/// Configuración centralizada de la URL del backend.
///
/// Prioridad:
///   1. --dart-define=API_HOST=https://mi-backend.railway.app  (build personalizado)
///   2. URL de Railway en producción (defecto para APK release)
///   3. 10.0.2.2:8000 solo si se fuerza con --dart-define=API_HOST=10.0.2.2:8000
class ApiConfig {
  ApiConfig._();

  // URL de producción en Railway
  static const String _railwayUrl = 'https://histolinkbackend-production.up.railway.app';

  // Override opcional vía --dart-define=API_HOST=...
  static const String _customHost = String.fromEnvironment('API_HOST', defaultValue: '');

  static String get baseUrl {
    if (_customHost.isNotEmpty) {
      // Si ya incluye esquema (http/https) lo usamos directo
      if (_customHost.startsWith('http')) return _customHost;
      // Si es solo host:puerto asumimos http (desarrollo local)
      return 'http://$_customHost';
    }
    return _railwayUrl;
  }

  static Uri uri(String path) => Uri.parse('$baseUrl$path');
}
